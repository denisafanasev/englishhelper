//
//  PhotoTranslateViewModel.swift
//  EnglishHelper — Presentation
//
//  "See it". Two modes over a photo, mirroring Get-it: EXPLAIN (default) — explain WHAT the photo
//  shows + its local/cultural context; TRANSLATE — recognize the text and translate it into blocks
//  (each a card with play + save). The mode selector sits at the top, like Get-it.
//

import Foundation
import Domain

@MainActor
@Observable
public final class PhotoTranslateViewModel {
    public enum Phase: Equatable { case idle, processing, result, failed }

    /// What pressing through a photo does: EXPLAIN its scene/context, or TRANSLATE its text. Order
    /// drives the on-screen segment order (Explain first); Explain is the default.
    public enum Mode: String, CaseIterable, Sendable {
        case explain, translate
        public var title: String {
            switch self {
            case .explain: Loc.t("Объяснение", "Explain")
            case .translate: Loc.t("Перевод", "Translate")
            }
        }
    }

    public private(set) var phase: Phase = .idle
    /// Mutated only via `selectMode` so the re-run logic isn't bypassed.
    public private(set) var mode: Mode = .explain
    public private(set) var imageData: Data?
    public private(set) var blocks: [TranslatedBlock] = []          // Translate mode result
    public private(set) var explanation: SceneExplanation?          // Explain mode result
    public private(set) var errorMessage: String?
    /// A SAVE failure shown independently of `phase` (the result stays on screen); `errorMessage`
    /// only renders in `.failed`.
    public private(set) var saveError: String?
    public private(set) var isOffline = false

    public var showCameraPriming = false
    public var presentCamera = false

    private var savedBlockIDs: Set<UUID> = []          // optimistic "saved" flag (instant UI)
    private var savedExpressionIDs: [UUID: UUID] = [:]  // block.id → stored Expression.id
    /// Bumped on every new photo result so an in-flight save can tell "user un-saved" from "a new
    /// photo replaced the result" and not silently delete a just-bookmarked expression.
    private var resultsGeneration = 0
    private var playingBlockID: UUID?
    /// True when the last failure could plausibly succeed on a re-run of the SAME photo (network /
    /// transient / server), so a "Retry" affordance is offered. False for content errors (no text,
    /// no key, too long) where re-running can't help.
    private var lastErrorRetryable = false

    private let photoTranslate: any PhotoTranslateUseCase
    private let photoExplain: any PhotoExplainUseCase
    private let pronounce: any PlayPronunciationUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let isConfigured: Bool

    private var requestTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?
    private let primingDefaultsKey = "didPrimeCamera"

    public init(
        photoTranslate: any PhotoTranslateUseCase,
        photoExplain: any PhotoExplainUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.photoTranslate = photoTranslate
        self.photoExplain = photoExplain
        self.pronounce = pronounce
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.isConfigured = isConfigured
    }

    /// Switch Explain/Translate. If a photo is already loaded, re-run it in the new mode; otherwise
    /// just remember the choice for the next photo. Mirrors Get-it's mode switch.
    public func selectMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        if let data = imageData, phase == .result || phase == .processing {
            process(data)
        }
    }

    public var needsAPIKey: Bool { !isConfigured }
    public func isSaved(_ block: TranslatedBlock) -> Bool { savedBlockIDs.contains(block.id) }
    public func isPlaying(_ block: TranslatedBlock) -> Bool { playingBlockID == block.id }

    // MARK: Camera priming

    public func cameraTapped() {
        if UserDefaults.standard.bool(forKey: primingDefaultsKey) {
            presentCamera = true
        } else {
            showCameraPriming = true
        }
    }

    public func confirmCameraPriming() {
        UserDefaults.standard.set(true, forKey: primingDefaultsKey)
        showCameraPriming = false
        presentCamera = true
    }

    public func cancelCameraPriming() { showCameraPriming = false }
    public func cameraCancelled() { presentCamera = false }

    public func didCapture(_ data: Data) {
        presentCamera = false
        process(data)
    }

    public func didPickFromLibrary(_ data: Data) {
        process(data)
    }

    /// Auto-retry after the network returns (RootView calls this on reconnect): re-run OCR+translate on
    /// the last image, but ONLY when we're showing an offline failure (other errors would just repeat).
    public func retryOnReconnect() {
        guard phase == .failed, isOffline, let data = imageData else { return }
        process(data)
    }

    /// Whether the failed photo can be retried — we still hold the image and the error was transient.
    public var canRetry: Bool { imageData != nil && lastErrorRetryable }

    /// Manually re-run the LAST photo after a failure (the image is never lost on an error).
    public func retry() {
        guard let data = imageData else { return }
        process(data)
    }

    /// The picked library photo couldn't be loaded/decoded — surface it instead of silently doing nothing.
    public func imageLoadFailed() {
        requestTask?.cancel()
        isOffline = false
        errorMessage = Loc.t("Не удалось загрузить изображение. Попробуйте другое фото.",
                             "Couldn't load the image. Try another photo.",
                             "Impossible de charger l'image. Essayez une autre photo.",
                             "No se pudo cargar la imagen. Prueba con otra foto.",
                             "Bild konnte nicht geladen werden. Versuche ein anderes Foto.",
                             "Impossibile caricare l'immagine. Prova un'altra foto.")
        phase = .failed
    }

    // MARK: Pipeline

    private func process(_ data: Data) {
        requestTask?.cancel()
        imageData = data
        blocks = []
        explanation = nil
        savedBlockIDs = []
        savedExpressionIDs = [:]
        errorMessage = nil
        isOffline = false
        lastErrorRetryable = false
        phase = .processing
        let studied = StudiedLanguage.current.promptName   // the studied-language place/country context
        let native = TargetLanguage.current.promptName     // explanation / translation rendered in native
        let mode = self.mode
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = RecognizableImage(data: data)
                switch mode {
                case .translate:
                    self.blocks = try await self.photoTranslate(image, studiedLanguage: studied, nativeLanguage: native)
                case .explain:
                    self.explanation = try await self.photoExplain(image, studiedLanguage: studied, nativeLanguage: native)
                }
                self.resultsGeneration += 1
                self.phase = .result
            } catch is CancellationError {
                // superseded
            } catch LLMError.cancelled {
                // superseded by a newer photo / a mode switch — the adapter maps task cancellation to
                // LLMError.cancelled, so this (not CancellationError) is what surfaces. Never show it.
            } catch {
                self.handle(error)
            }
        }
    }

    private func handle(_ error: Error) {
        phase = .failed
        if let ocr = error as? TextRecognitionError {
            switch ocr {
            case .noTextFound:
                errorMessage = Loc.t("Не нашёл английский текст на фото. Попробуйте другое изображение.",
                                     "No English text found in the photo. Try another image.")
            case .unsupportedImage:
                errorMessage = Loc.t("Не удалось обработать изображение.", "Couldn't process the image.")
            case .cancelled:
                errorMessage = Loc.t("Отменено.", "Cancelled.")
            case .underlying:
                errorMessage = Loc.t("Ошибка распознавания текста.", "Text recognition error.")
            }
            isOffline = false
            lastErrorRetryable = false   // a recognition/content error won't change on a re-run
        } else {
            let presented = presentableError(error)
            errorMessage = presented.message
            isOffline = presented.isOffline
            // Offer to retry the SAME photo for network / transient / server failures (the photo is
            // kept). Not for "no key" or "too long", where re-running the same request can't help.
            if let llm = error as? LLMError {
                switch llm {
                case .offline, .timedOut, .overloaded, .requestFailed, .invalidOutput:
                    lastErrorRetryable = true
                case .notConfigured, .responseTooLong, .cancelled:
                    lastErrorRetryable = false
                }
            } else {
                lastErrorRetryable = true
            }
        }
    }

    // MARK: Per-block actions

    public func play(_ block: TranslatedBlock) {
        if playingBlockID == block.id { stopPlayback(); return }   // tap again = stop
        playTask?.cancel()
        playingBlockID = block.id
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(block.en) where state == .finished { break }
            } catch {}
            if !Task.isCancelled, self.playingBlockID == block.id { self.playingBlockID = nil }
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playingBlockID = nil
    }

    public func toggleSave(_ block: TranslatedBlock) {
        let id = block.id
        if savedBlockIDs.contains(id) {
            savedBlockIDs.remove(id)                       // instant UI
            let storedID = savedExpressionIDs[id]
            savedExpressionIDs[id] = nil
            if let storedID {
                Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
            }
        } else {
            savedBlockIDs.insert(id)                        // instant UI; enrich+store in background
            let generation = resultsGeneration
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: block.en, knownRU: block.ru, context: "")
                    if self.resultsGeneration != generation {
                        // A new photo replaced the result while saving — keep it persisted; drop the mapping.
                    } else if self.savedBlockIDs.contains(id) {
                        self.savedExpressionIDs[id] = stored.id
                    } else {
                        try? await self.studyList.delete(id: stored.id)   // user un-saved while saving
                    }
                } catch {
                    self.savedBlockIDs.remove(id)           // revert
                    self.saveError = Loc.t("Не удалось сохранить в изучаемое.",
                                           "Couldn't save to your study list.")
                }
            }
        }
    }

    public func clearSaveError() { saveError = nil }

    public func reset() {
        requestTask?.cancel(); playTask?.cancel()
        phase = .idle
        imageData = nil
        blocks = []
        explanation = nil
        savedBlockIDs = []
        savedExpressionIDs = [:]
        playingBlockID = nil
        errorMessage = nil
        isOffline = false
    }
}
