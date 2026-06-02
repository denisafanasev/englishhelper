//
//  InViewModel.swift
//  EnglishHelper — Presentation
//
//  "In" (reverse): English voice OR typed text in any language → ONE translation into the
//  configured target language (Russian by default). Mirrors VoiceViewModel's lifecycle but yields
//  a single translation instead of three variants. Consumes USE CASES only.
//

import Foundation
import Domain

@MainActor
@Observable
public final class InViewModel {
    public enum Phase: Equatable { case idle, listening, processing, result, failed }

    // UI state
    public private(set) var phase: Phase = .idle
    public var source: String = ""                       // editable transcript / typed input
    public private(set) var translation: String?
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false
    public private(set) var isPlaying = false
    public private(set) var isSaved = false
    public var showMicPriming = false

    private var submittedSource = ""                     // source text that produced `translation`
    private var savedExpressionID: UUID?

    // Dependencies (use cases)
    private let translate: any TranslateToTargetUseCase
    private let voiceCapture: any VoiceCaptureUseCase    // English ASR
    private let pronounce: any PlayPronunciationUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let isConfigured: Bool

    private var captureTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?

    private let primingDefaultsKey = "didPrimeMic"        // shared with Out — one mic grant

    public init(
        translate: any TranslateToTargetUseCase,
        voiceCapture: any VoiceCaptureUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.translate = translate
        self.voiceCapture = voiceCapture
        self.pronounce = pronounce
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.isConfigured = isConfigured
    }

    // MARK: Derived

    public var isListening: Bool { phase == .listening }
    public var canSubmit: Bool { !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var needsAPIKey: Bool { !isConfigured }

    /// The phrase being translated (the source) — the study card's `en` and what we play back.
    /// We always study the source, never the translation into the user's own language.
    public var sourceText: String { submittedSource }

    public enum MicStatus { case idle, listening, processing }
    public var micStatus: MicStatus {
        switch phase {
        case .listening: .listening
        case .processing: .processing
        default: .idle
        }
    }

    // MARK: Mic / capture (English)

    public func micTapped() {
        switch phase {
        case .listening:
            stopListening()
        default:
            if UserDefaults.standard.bool(forKey: primingDefaultsKey) {
                startListening()
            } else {
                showMicPriming = true
            }
        }
    }

    public func confirmPriming() {
        UserDefaults.standard.set(true, forKey: primingDefaultsKey)
        showMicPriming = false
        startListening()
    }

    public func cancelPriming() { showMicPriming = false }

    private func startListening() {
        errorMessage = nil
        isOffline = false
        translation = nil
        source = ""
        phase = .listening
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await transcript in self.voiceCapture() {
                    self.source = transcript.text
                }
                self.captureEndedNaturally()
            } catch is CancellationError {
                // stopped by the user; handled in stopListening
            } catch {
                self.captureFailed(error)
            }
        }
    }

    private func stopListening() {
        captureTask?.cancel()
        captureTask = nil
        if canSubmit { submit() } else { phase = .idle }
    }

    private func captureEndedNaturally() {
        captureTask = nil
        guard phase == .listening else { return }
        if canSubmit { submit() } else { phase = .idle }
    }

    private func captureFailed(_ error: Error) {
        captureTask = nil
        phase = .failed
        switch error {
        case SpeechRecognitionError.permissionDenied:
            errorMessage = Loc.t(
                "Нет доступа к микрофону или распознаванию речи. Включите в Настройках, либо введите текст вручную.",
                "No access to the microphone or speech recognition. Enable it in Settings, or type the text instead.")
        case SpeechRecognitionError.unavailable:
            errorMessage = Loc.t("Распознавание речи недоступно. Введите текст вручную.",
                                 "Speech recognition is unavailable. Type the text instead.")
        case SpeechRecognitionError.noSpeechDetected:
            errorMessage = Loc.t("Не расслышал. Попробуйте ещё раз.", "Didn't catch that. Try again.")
        case SpeechRecognitionError.underlying(let detail):
            errorMessage = Loc.t("Не удалось распознать речь: \(detail). Можно ввести текст вручную.",
                                 "Couldn't recognize speech: \(detail). You can type the text instead.")
        default:
            errorMessage = Loc.t("Не удалось распознать речь. Введите текст вручную.",
                                 "Couldn't recognize speech. Type the text instead.")
        }
    }

    // MARK: Translate

    /// One button: translate fresh input, or re-translate when a result is already shown.
    public func submit() {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let target = TargetLanguage.current
        let tone = ToneOfVoice.current.register   // styles the composed phrase, if the model composes
        requestTask?.cancel()
        phase = .processing
        errorMessage = nil
        isOffline = false
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.translate(text, targetLanguage: target.promptName, tone: tone)
                self.submittedSource = text
                self.translation = result
                self.isSaved = false
                self.savedExpressionID = nil
                self.phase = .result
            } catch is CancellationError {
                // superseded
            } catch {
                self.handleRequestError(error)
            }
        }
    }

    private func handleRequestError(_ error: Error) {
        phase = .failed
        guard let llm = error as? LLMError else {
            errorMessage = Loc.t("Что-то пошло не так. Попробуйте ещё раз.", "Something went wrong. Try again.")
            return
        }
        switch llm {
        case .notConfigured:
            isOffline = true
            errorMessage = Loc.t("Нет ключа Claude API. Добавьте его, чтобы переводить.",
                                 "No Claude API key. Add one to translate.")
        case .overloaded:
            errorMessage = Loc.t("Сервис перегружен, попробуйте позже.", "Service is overloaded — try later.")
        case .requestFailed(let info) where info.contains("offline"):
            isOffline = true
            errorMessage = Loc.t("Нет соединения. Проверьте интернет и попробуйте снова.",
                                 "No connection. Check the internet and try again.")
        case .requestFailed(let info) where info.contains("timed out"):
            errorMessage = Loc.t("Сервис не ответил вовремя. Попробуйте ещё раз.",
                                 "The service didn't respond in time. Try again.")
        case .invalidOutput:
            errorMessage = Loc.t("Не удалось разобрать ответ. Попробуйте ещё раз.",
                                 "Couldn't parse the response. Try again.")
        case .cancelled:
            errorMessage = Loc.t("Запрос отменён.", "Request cancelled.")
        case .requestFailed:
            errorMessage = Loc.t("Сервис недоступен. Попробуйте позже.", "Service unavailable. Try later.")
        }
    }

    // MARK: Play (the English side)

    public func play() {
        if isPlaying { stopPlayback(); return }   // tap again while speaking = stop
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        playTask?.cancel()
        isPlaying = true
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(text) where state == .finished { break }
            } catch {
                // playback failure is non-fatal
            }
            if !Task.isCancelled { self.isPlaying = false }
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }

    // MARK: Save / unsave (enrich-then-store)

    public func toggleSave() {
        guard let translation, !submittedSource.isEmpty else { return }
        if isSaved {
            isSaved = false                                  // instant UI
            let storedID = savedExpressionID
            savedExpressionID = nil
            if let storedID {
                Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
            }
        } else {
            isSaved = true                                   // instant UI; enrich+store in background
            // We always study the SOURCE (what was translated), with the translation as its meaning —
            // never the variant in the user's own language.
            let en = submittedSource
            let knownRU = translation
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: en, knownRU: knownRU, context: "")
                    if self.isSaved {
                        self.savedExpressionID = stored.id
                    } else {
                        try? await self.studyList.delete(id: stored.id)   // unsaved while saving
                    }
                } catch {
                    self.isSaved = false                     // revert on failure
                    self.errorMessage = Loc.t("Не удалось сохранить в изучаемое.",
                                              "Couldn't save to your study list.")
                }
            }
        }
    }

    public func reset() {
        captureTask?.cancel(); requestTask?.cancel(); playTask?.cancel()
        phase = .idle
        translation = nil
        source = ""
        submittedSource = ""
        errorMessage = nil
        isPlaying = false
        isSaved = false
        savedExpressionID = nil
    }
}
