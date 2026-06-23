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
    /// Mutated only via `selectMode`/`startExplain` so the re-run/reset logic isn't bypassed.
    public private(set) var mode: Mode = .explain
    public var source: String = ""                       // editable transcript / typed input
    public private(set) var studied: String?             // input rendered in the studied language (headline + TTS)
    public private(set) var translations: [TranslationVariant] = []  // Translate mode: 1–5 translations + context
    public private(set) var explanation: ExpressionExplanation?   // Explain mode result (native)
    public private(set) var errorMessage: String?
    /// A SAVE failure shown independently of `phase` (the result stays on screen); `errorMessage`
    /// only renders in `.failed`.
    public private(set) var saveError: String?
    public private(set) var isOffline = false
    public private(set) var isPlaying = false
    public private(set) var isSaved = false
    public var showMicPriming = false

    private var savedExpressionID: UUID?
    /// Bumped on every new result so an in-flight save can tell "user un-saved" from "result was
    /// regenerated" and not silently delete a just-bookmarked expression.
    private var resultsGeneration = 0
    private var explainImage: Data?          // photo context for an Explain routed from See it
    private var explainImageText: String?    // the source text that photo context belongs to
    private var explainAlternatives: [String] = []   // sibling variants to contrast (Say it "why this?")
    private var explainAlternativesText: String?     // the source text those alternatives belong to

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
        translations = []
        explanation = nil
        source = ""
        phase = .listening
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await transcript in self.voiceCapture() {
                    guard self.phase == .listening else { break }   // a late value mustn't overwrite after stop
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
                                 "No se pudo reconocer el habla: \(detail). Puedes escribir el texto.",
                                 "Sprache konnte nicht erkannt werden: \(detail). Du kannst den Text eingeben.",
                                 "Impossibile riconoscere il parlato: \(detail). Puoi digitare il testo.")
        default:
            errorMessage = Loc.t("Не удалось распознать речь. Введите текст вручную.",
                                 "Couldn't recognize speech. Type the text instead.")
        }
    }

    // MARK: Translate / Explain

    /// Auto-retry after the network returns (RootView calls this on reconnect): replay the last
    /// request, but ONLY when we're showing an offline failure — re-running any other error would just
    /// fail the same way. The source/mode are still set, so `submit()` faithfully replays it.
    public func retryOnReconnect() {
        guard phase == .failed, isOffline, canSubmit else { return }
        submit()
    }

    /// One button: act on fresh input, or re-run when a result is already shown. The current `mode`
    /// decides whether the LLM TRANSLATES the input into the native language or EXPLAINS its nuance.
    public func submit() {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let studiedLang = StudiedLanguage.current.promptName
        let nativeLang = TargetLanguage.current.promptName
        let mode = self.mode
        // Use the routed photo context / sibling-variant context only while the input still matches
        // what each was captured for (a user edit of `source` invalidates them).
        let explainImg = (mode == .explain && explainImageText == text) ? explainImage : nil
        let explainAlts = (mode == .explain && explainAlternativesText == text) ? explainAlternatives : []
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
                    self.translations = result.variants   // 1–5 translations (+ context per variant)
                    self.explanation = nil
                case .explain:
                    let result = try await self.explain(text, studiedLanguage: studiedLang, nativeLanguage: nativeLang, image: explainImg, alternatives: explainAlts)
                    self.studied = result.studied
                    self.explanation = result
                    self.translations = []
                }
                self.isSaved = false
                self.savedExpressionID = nil
                self.resultsGeneration += 1
                self.phase = .result
            } catch is CancellationError {
                // superseded
            } catch LLMError.cancelled {
                // Superseded by a newer request — e.g. toggling Translate/Explain mid-generation cancels
                // this one. The adapter maps the in-flight URLSession cancel to LLMError.cancelled, so it
                // arrives HERE (not as CancellationError). Swallow it: never surface a self-inflicted
                // cancel as a failure (that left the screen stuck in `.failed`).
            } catch {
                self.handleRequestError(error)
            }
        }
    }

    /// Open this screen in Explain mode for an externally-supplied phrase (routed from See it /
    /// History), optionally with a photo as visual context, and run it immediately.
    public func startExplain(text: String, image: Data?, alternatives: [String] = []) {
        mode = .explain
        source = text
        explainImage = image
        explainImageText = image == nil ? nil : text
        explainAlternatives = alternatives
        explainAlternativesText = alternatives.isEmpty ? nil : text
        submit()
    }

    /// Switch the Translate/Explain mode. With a result already shown (or in flight), re-run the
    /// same input in the new mode so you see it both ways; otherwise just remember the choice.
    public func selectMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        // Re-run the SAME input in the new mode — including after a FAILURE (e.g. the model was
        // unavailable in the previous mode), so switching mode retries instead of staying stuck.
        if canSubmit, phase == .result || phase == .processing || phase == .failed {
            submit()
        } else {
            studied = nil
            translations = []
            explanation = nil
            // Nothing to re-run (no input): drop any stale result/error back to idle.
            if phase == .result || phase == .failed {
                phase = .idle
                errorMessage = nil
                isOffline = false
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
        case .offline:
            isOffline = true
            errorMessage = Loc.t("Нет соединения. Проверьте интернет и попробуйте снова.",
                                 "No connection. Check the internet and try again.")
        case .timedOut:
            errorMessage = Loc.t("Сервис не ответил вовремя. Попробуйте ещё раз.",
                                 "The service didn't respond in time. Try again.")
        case .responseTooLong:
            errorMessage = Loc.t("Слишком много текста для одного запроса. Попробуйте часть поменьше.",
                                 "Too much text to handle at once. Try a smaller part.")
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
            let knownRU = translations.first?.text
            let generation = resultsGeneration
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: en, knownRU: knownRU, context: "")
                    if self.resultsGeneration != generation {
                        // Regenerated while saving — keep it persisted; drop the optimistic mapping only.
                    } else if self.isSaved {
                        self.savedExpressionID = stored.id
                    } else {
                        try? await self.studyList.delete(id: stored.id)   // user un-saved while saving
                    }
                } catch {
                    self.isSaved = false                     // revert on failure
                    self.saveError = Loc.t("Не удалось сохранить в изучаемое.",
                                           "Couldn't save to your study list.")
                }
            }
        }
    }

    public func clearSaveError() { saveError = nil }

    public func reset() {
        captureTask?.cancel(); requestTask?.cancel(); playTask?.cancel()
        phase = .idle
        studied = nil
        translations = []
        explanation = nil
        source = ""
        errorMessage = nil
        isPlaying = false
        isSaved = false
        savedExpressionID = nil
        explainImage = nil
        explainImageText = nil
        explainAlternatives = []
        explainAlternativesText = nil
    }
}
