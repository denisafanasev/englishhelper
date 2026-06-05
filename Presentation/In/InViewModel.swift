//
//  InViewModel.swift
//  EnglishHelper — Presentation
//
//  "Get it": voice OR typed text in ANY language. Translate mode renders it in the STUDIED language
//  (card headline + TTS) plus a NATIVE translation; Explain mode renders the studied form plus an
//  explanation written in the native language. Faithful translation only (no compose/tone).
//  Consumes USE CASES only.
//

import Foundation
import Domain

@MainActor
@Observable
public final class InViewModel {
    public enum Phase: Equatable { case idle, listening, processing, result, failed }

    /// What pressing the action button does: explain the input's nuance, or translate it. Order here
    /// drives the on-screen segment order (Explain first); Explain is the default.
    public enum Mode: String, CaseIterable, Sendable {
        case explain, translate
        public var title: String {
            switch self {
            case .translate: Loc.t("Перевод", "Translate")
            case .explain: Loc.t("Объяснение", "Explain")
            }
        }
    }

    // UI state
    public private(set) var phase: Phase = .idle
    public var mode: Mode = .explain
    public var source: String = ""                       // editable transcript / typed input
    public private(set) var studied: String?             // input rendered in the studied language (headline + TTS)
    public private(set) var translation: String?         // Translate mode: native rendering (the line below)
    public private(set) var explanation: ExpressionExplanation?   // Explain mode result (native)
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false
    public private(set) var isPlaying = false
    public private(set) var isSaved = false
    public var showMicPriming = false

    private var savedExpressionID: UUID?
    private var explainImage: Data?          // photo context for an Explain routed from See it
    private var explainImageText: String?    // the source text that photo context belongs to

    // Dependencies (use cases)
    private let understand: any UnderstandUseCase        // faithful translate → studied + native
    private let explain: any ExplainExpressionUseCase
    private let voiceCapture: any VoiceCaptureUseCase    // studied-language ASR
    private let pronounce: any PlayPronunciationUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let isConfigured: Bool

    private var captureTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?

    private let primingDefaultsKey = "didPrimeMic"        // shared with Out — one mic grant

    public init(
        understand: any UnderstandUseCase,
        explain: any ExplainExpressionUseCase,
        voiceCapture: any VoiceCaptureUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.understand = understand
        self.explain = explain
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

    /// The studied-language rendering — the card headline, the TTS source, and the study card's
    /// front. We study the language being LEARNED, never the user's own language.
    public var sourceText: String { studied ?? "" }

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
        studied = nil
        translation = nil
        explanation = nil
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
                                 "Couldn't recognize speech: \(detail). You can type the text instead.",
                                 "Impossible de reconnaître la parole : \(detail). Vous pouvez saisir le texte à la place.",
                                 "No se pudo reconocer el habla: \(detail). Puedes escribir el texto.")
        default:
            errorMessage = Loc.t("Не удалось распознать речь. Введите текст вручную.",
                                 "Couldn't recognize speech. Type the text instead.")
        }
    }

    // MARK: Translate / Explain

    /// One button: act on fresh input, or re-run when a result is already shown. The current `mode`
    /// decides whether the LLM TRANSLATES the input into the native language or EXPLAINS its nuance.
    public func submit() {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let studiedLang = StudiedLanguage.current.promptName
        let nativeLang = TargetLanguage.current.promptName
        let mode = self.mode
        // Use the routed photo context only while the input still matches what it was captured for.
        let explainImg = (mode == .explain && explainImageText == text) ? explainImage : nil
        requestTask?.cancel()
        phase = .processing
        errorMessage = nil
        isOffline = false
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                switch mode {
                case .translate:
                    let result = try await self.understand(text, studiedLanguage: studiedLang, nativeLanguage: nativeLang)
                    self.studied = result.studied         // headline + TTS
                    self.translation = result.native      // understanding line
                    self.explanation = nil
                case .explain:
                    let result = try await self.explain(text, studiedLanguage: studiedLang, nativeLanguage: nativeLang, image: explainImg)
                    self.studied = result.studied
                    self.explanation = result
                    self.translation = nil
                }
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

    /// Open this screen in Explain mode for an externally-supplied phrase (routed from See it /
    /// History), optionally with a photo as visual context, and run it immediately.
    public func startExplain(text: String, image: Data?) {
        mode = .explain
        source = text
        explainImage = image
        explainImageText = image == nil ? nil : text
        submit()
    }

    /// Switch the Translate/Explain mode. With a result already shown (or in flight), re-run the
    /// same input in the new mode so you see it both ways; otherwise just remember the choice.
    public func selectMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        if canSubmit, phase == .result || phase == .processing {
            submit()
        } else {
            studied = nil
            translation = nil
            explanation = nil
            if phase == .result { phase = .idle }
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
        guard let studied, !studied.isEmpty else { return }
        if isSaved {
            isSaved = false                                  // instant UI
            let storedID = savedExpressionID
            savedExpressionID = nil
            if let storedID {
                Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
            }
        } else {
            isSaved = true                                   // instant UI; enrich+store in background
            // We study the STUDIED-language rendering (the headline), with the native translation as
            // its gloss. In Explain mode there's no direct gloss, so enrich derives it.
            let en = studied
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
        studied = nil
        translation = nil
        explanation = nil
        source = ""
        errorMessage = nil
        isPlaying = false
        isSaved = false
        savedExpressionID = nil
        explainImage = nil
        explainImageText = nil
    }
}
