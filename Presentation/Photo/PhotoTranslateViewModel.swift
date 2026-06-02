//
//  PhotoTranslateViewModel.swift
//  EnglishHelper — Presentation
//
//  "Фото-перевод" (EN→RU). Camera or library image → OCR (+ boxes) → Russian translation → save.
//

import Foundation
import Domain

@MainActor
@Observable
public final class PhotoTranslateViewModel {
    public enum Phase: Equatable { case idle, processing, result, failed }

    public private(set) var phase: Phase = .idle
    public private(set) var imageData: Data?
    public private(set) var result: PhotoTranslation?
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false
    public private(set) var isPlaying = false
    private var savedExpressionID: UUID?

    public var showCameraPriming = false
    public var presentCamera = false

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

    public private(set) var isSaved = false   // optimistic (instant UI)
    public var needsAPIKey: Bool { !isConfigured }
    public var blocks: [RecognizedTextBlock] { result?.blocks ?? [] }

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
        result = nil
        savedExpressionID = nil
        isSaved = false
        errorMessage = nil
        isOffline = false
        phase = .processing
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let translation = try await self.photoTranslate(RecognizableImage(data: data))
                self.result = translation
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
                errorMessage = "Не нашёл текст на фото. Попробуйте другое изображение."
            case .unsupportedImage:
                errorMessage = "Не удалось обработать изображение."
            case .cancelled:
                errorMessage = "Отменено."
            case .underlying:
                errorMessage = "Ошибка распознавания текста."
            }
            isOffline = false
        } else {
            let presented = presentableError(error)
            errorMessage = presented.message
            isOffline = presented.isOffline
        }
    }

    // MARK: Actions

    public func playSource() {
        guard let text = result?.recognizedText, !text.isEmpty else { return }
        playTask?.cancel()
        isPlaying = true
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(text) where state == .finished { break }
            } catch {}
            self.isPlaying = false
        }
    }

    public func toggleSave() {
        guard let result, phase == .result else { return }
        if isSaved {
            isSaved = false                              // instant UI
            let storedID = savedExpressionID
            savedExpressionID = nil
            if let storedID {
                Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
            }
        } else {
            isSaved = true                               // instant UI; enrich+store in background
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(
                        en: result.recognizedText, knownRU: result.ru, context: ""
                    )
                    if self.isSaved { self.savedExpressionID = stored.id }
                    else { try? await self.studyList.delete(id: stored.id) }
                } catch {
                    self.isSaved = false                 // revert
                    self.errorMessage = "Не удалось сохранить в изучаемое."
                }
            }
        }
    }

    public func reset() {
        requestTask?.cancel(); playTask?.cancel()
        phase = .idle
        imageData = nil
        result = nil
        errorMessage = nil
        isOffline = false
        isPlaying = false
        savedExpressionID = nil
        isSaved = false
    }
}
