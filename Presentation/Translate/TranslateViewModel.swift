//
//  TranslateViewModel.swift
//  EnglishHelper — Presentation
//
//  "Перевод" (EN→RU). Typed English → single Russian translation, with play-source + save.
//

import Foundation
import Domain

@MainActor
@Observable
public final class TranslateViewModel {
    public enum Phase: Equatable { case idle, processing, result, failed }

    public var sourceText: String = ""               // editable EN input
    public private(set) var phase: Phase = .idle
    public private(set) var translation: String = ""  // RU
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false
    public private(set) var isPlaying = false
    private var savedExpressionID: UUID?

    private let translate: any TranslateTextUseCase
    private let pronounce: any PlayPronunciationUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let isConfigured: Bool

    private var requestTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?

    public init(
        translate: any TranslateTextUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.translate = translate
        self.pronounce = pronounce
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.isConfigured = isConfigured
    }

    public var canSubmit: Bool { !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var isSaved: Bool { savedExpressionID != nil }
    public var needsAPIKey: Bool { !isConfigured }

    public func submit() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        requestTask?.cancel()
        phase = .processing
        errorMessage = nil
        isOffline = false
        savedExpressionID = nil
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let ru = try await self.translate(text)
                self.translation = ru
                self.phase = .result
            } catch is CancellationError {
                // superseded
            } catch {
                let presented = presentableError(error)
                self.errorMessage = presented.message
                self.isOffline = presented.isOffline
                self.phase = .failed
            }
        }
    }

    public func playSource() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        playTask?.cancel()
        isPlaying = true
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(text) where state == .finished { break }
            } catch {
                // non-fatal
            }
            self.isPlaying = false
        }
    }

    public func toggleSave() {
        guard phase == .result else { return }
        if let storedID = savedExpressionID {
            savedExpressionID = nil
            Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
        } else {
            let en = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            let ru = translation
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: en, knownRU: ru, context: "")
                    self.savedExpressionID = stored.id
                } catch {
                    self.errorMessage = "Не удалось сохранить в изучаемое."
                }
            }
        }
    }

    public func clear() {
        requestTask?.cancel(); playTask?.cancel()
        sourceText = ""
        translation = ""
        phase = .idle
        errorMessage = nil
        isOffline = false
        isPlaying = false
        savedExpressionID = nil
    }
}
