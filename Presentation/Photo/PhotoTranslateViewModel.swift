//
//  PhotoTranslateViewModel.swift
//  EnglishHelper — Presentation
//
//  "Фото-перевод". The LLM recognizes English text in the photo and translates it into blocks
//  (it decides how many). Each block is shown as its own card with play + save.
//

import Foundation
import Domain

@MainActor
@Observable
public final class PhotoTranslateViewModel {
    public enum Phase: Equatable { case idle, processing, result, failed }

    public private(set) var phase: Phase = .idle
    public private(set) var imageData: Data?
    public private(set) var blocks: [TranslatedBlock] = []
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false

    public var showCameraPriming = false
    public var presentCamera = false

    private var savedBlockIDs: Set<UUID> = []          // optimistic "saved" flag (instant UI)
    private var savedExpressionIDs: [UUID: UUID] = [:]  // block.id → stored Expression.id
    private var playingBlockID: UUID?

    private let photoTranslate: any PhotoTranslateUseCase
    private let pronounce: any PlayPronunciationUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let isConfigured: Bool

    private var requestTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?
    private let primingDefaultsKey = "didPrimeCamera"

    public init(
        photoTranslate: any PhotoTranslateUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.photoTranslate = photoTranslate
        self.pronounce = pronounce
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.isConfigured = isConfigured
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

    // MARK: Pipeline

    private func process(_ data: Data) {
        requestTask?.cancel()
        imageData = data
        blocks = []
        savedBlockIDs = []
        savedExpressionIDs = [:]
        errorMessage = nil
        isOffline = false
        phase = .processing
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.photoTranslate(RecognizableImage(data: data))
                self.blocks = result
                self.phase = .result
            } catch is CancellationError {
                // superseded
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
        } else {
            let presented = presentableError(error)
            errorMessage = presented.message
            isOffline = presented.isOffline
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
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: block.en, knownRU: block.ru, context: "")
                    if self.savedBlockIDs.contains(id) { self.savedExpressionIDs[id] = stored.id }
                    else { try? await self.studyList.delete(id: stored.id) }
                } catch {
                    self.savedBlockIDs.remove(id)           // revert
                    self.errorMessage = Loc.t("Не удалось сохранить в изучаемое.",
                                              "Couldn't save to your study list.")
                }
            }
        }
    }

    public func reset() {
        requestTask?.cancel(); playTask?.cancel()
        phase = .idle
        imageData = nil
        blocks = []
        savedBlockIDs = []
        savedExpressionIDs = [:]
        playingBlockID = nil
        errorMessage = nil
        isOffline = false
    }
}
