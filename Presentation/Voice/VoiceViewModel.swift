//
//  VoiceViewModel.swift
//  EnglishHelper — Presentation
//
//  "Как сказать" (RU→EN). Drives: idle / listening / processing / results / failed, plus offline
//  and mic permission priming. Consumes USE CASES only (no Speech/AVFoundation here).
//

import Foundation
import Domain

@MainActor
@Observable
public final class VoiceViewModel {
    public enum Phase: Equatable { case idle, listening, processing, results, failed }

    /// What the screen generates: phrasings of ONE thought ("how to say"), or the useful phrases for
    /// a described SITUATION ("what to say"). Both produce phrase cards in the chosen tone.
    public enum Mode: String, CaseIterable, Sendable {
        case howToSay, whatToSay
        public var title: String {
            switch self {
            case .howToSay: Loc.t("Как сказать", "How to say", "Comment dire", "Cómo decir", "Wie sagt man", "Come si dice")
            case .whatToSay: Loc.t("Что сказать", "What to say", "Quoi dire", "Qué decir", "Was sagen", "Cosa dire")
            }
        }
    }

    // UI state
    public private(set) var phase: Phase = .idle
    public private(set) var mode: Mode = .howToSay   // only selectMode mutates, preserving its re-run logic
    public var intent: String = ""                       // editable transcript / typed input
    /// Tone/register for the generated phrases — chosen on-screen, persisted (shared with the
    /// "Понять" compose path via `ToneOfVoice.current`).
    public var tone: ToneOfVoice = ToneOfVoice.current {
        didSet { UserDefaults.standard.set(tone.rawValue, forKey: ToneOfVoice.storageKey) }
    }
    public private(set) var variants: [PhraseVariant] = []
    public private(set) var errorMessage: String?
    /// A SAVE failure shown independently of `phase` (the results stay on screen); the request-level
    /// `errorMessage` only renders in `.failed`, so a background save error needs its own channel.
    public private(set) var saveError: String?
    public private(set) var isOffline = false
    public private(set) var playingVariantID: UUID?
    public var showMicPriming = false

    private var savedVariantIDs: Set<UUID> = []           // optimistic "saved" flag (instant UI)
    private var savedExpressionIDs: [UUID: UUID] = [:]    // variant.id → stored Expression.id
    /// Bumped on every new result set; lets an in-flight save tell "user un-saved" from "results
    /// were regenerated" so a regenerate can't silently delete a phrase the user just bookmarked.
    private var resultsGeneration = 0

    // Dependencies (use cases)
    private let howToSay: any HowToSayUseCase
    private let regenerateHowToSay: any RegenerateHowToSayUseCase
    private let whatToSay: any WhatToSayUseCase
    private let voiceCapture: any VoiceCaptureUseCase
    private let pronounce: any PlayPronunciationUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let isConfigured: Bool

    private var captureTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?

    private let primingDefaultsKey = "didPrimeMic"

    public init(
        howToSay: any HowToSayUseCase,
        regenerateHowToSay: any RegenerateHowToSayUseCase,
        whatToSay: any WhatToSayUseCase,
        voiceCapture: any VoiceCaptureUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.howToSay = howToSay
        self.regenerateHowToSay = regenerateHowToSay
        self.whatToSay = whatToSay
        self.voiceCapture = voiceCapture
        self.pronounce = pronounce
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.isConfigured = isConfigured
    }

    // MARK: Derived

    public var isListening: Bool { phase == .listening }
    public var canSubmit: Bool { !intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var needsAPIKey: Bool { !isConfigured }
    public func isSaved(_ variant: PhraseVariant) -> Bool { savedVariantIDs.contains(variant.id) }
    public func isPlaying(_ variant: PhraseVariant) -> Bool { playingVariantID == variant.id }

    public var micStatus: MicStatus {
        switch phase {
        case .listening: .listening
        case .processing: .processing
        default: .idle
        }
    }
    public enum MicStatus { case idle, listening, processing }

    // MARK: Mic / capture

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

    /// Start voice input WITHOUT toggling — used by the Lock Screen widget deep link so the mic comes on
    /// the moment the app opens. Idempotent (guards `.listening`) because iOS 26 can deliver the widget
    /// URL twice; the toggle `micTapped` would otherwise start-then-stop. Shows the priming sheet first
    /// if the mic hasn't been primed yet.
    public func beginVoiceInput() {
        guard phase != .listening else { return }
        if UserDefaults.standard.bool(forKey: primingDefaultsKey) { startListening() }
        else { showMicPriming = true }
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
        variants = []
        intent = ""
        phase = .listening
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await transcript in self.voiceCapture() {
                    guard self.phase == .listening else { break }   // a late value mustn't overwrite after stop
                    self.intent = transcript.text
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

    // MARK: Generate

    /// Auto-retry after the network returns (RootView calls this on reconnect): replay the last
    /// request, but ONLY when we're showing an offline failure — re-running any other error would just
    /// fail the same way. The intent/mode/tone are still set, so `submit()` faithfully replays it.
    public func retryOnReconnect() {
        guard phase == .failed, isOffline, canSubmit else { return }
        submit()
    }

    public func submit() {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let studied = StudiedLanguage.current.promptName   // phrases are produced in the studied language
        let native = TargetLanguage.current.promptName     // notes + input normalization in native
        let tone = self.tone.register
        switch mode {
        case .howToSay:
            run { try await self.howToSay(text, tone: tone, studiedLanguage: studied, nativeLanguage: native) }
        case .whatToSay:
            run { try await self.whatToSay(text, tone: tone, studiedLanguage: studied, nativeLanguage: native) }
        }
    }

    public func regenerate() {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let studied = StudiedLanguage.current.promptName
        let native = TargetLanguage.current.promptName
        let tone = self.tone.register
        switch mode {
        case .howToSay:
            run { try await self.regenerateHowToSay(text, tone: tone, studiedLanguage: studied, nativeLanguage: native) }
        case .whatToSay:
            run { try await self.whatToSay(text, tone: tone, studiedLanguage: studied, nativeLanguage: native, regenerate: true) }
        }
    }

    /// One button drives both: regenerate when results are shown, otherwise generate a fresh set.
    public func pick() {
        if phase == .results { regenerate() } else { submit() }
    }

    /// Switch between "how to say" (phrasings of one thought) and "what to say" (phrases for a
    /// situation). With results already shown (or in flight) and non-empty input, re-run in the new
    /// mode; otherwise just remember the choice (the prior results would be stale for the new mode).
    public func selectMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        if canSubmit, phase == .results || phase == .processing {
            submit()                          // re-run the same input in the new mode
        } else if phase == .results || phase == .processing || phase == .failed {
            requestTask?.cancel()             // no input to re-run with → drop stale/in-flight/errored results
            variants = []
            errorMessage = nil                // a stale error's Retry would otherwise re-run the NEW mode
            isOffline = false
            phase = .idle
        }
    }

    /// Pick a tone from the on-screen selector. With variants already shown (or in flight),
    /// immediately produce a fresh set in the new tone — "change the tone → get new variants".
    /// Otherwise just remember it for the next generation.
    public func selectTone(_ newTone: ToneOfVoice) {
        guard newTone != tone else { return }
        tone = newTone
        if canSubmit, phase == .results || phase == .processing { submit() }
    }

    private func run(_ operation: @escaping () async throws -> [PhraseVariant]) {
        requestTask?.cancel()
        phase = .processing
        errorMessage = nil
        isOffline = false
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await operation()
                self.variants = result
                self.savedVariantIDs = []
                self.savedExpressionIDs = [:]
                self.resultsGeneration += 1
                self.phase = .results
            } catch is CancellationError {
                // superseded
            } catch LLMError.cancelled {
                // superseded by a newer request, or dropped on a mode switch — adapters map task
                // cancellation to LLMError.cancelled, so this (not CancellationError) is what we get.
                // Cancellation is always self-inflicted; never surface it as a failure.
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
            errorMessage = Loc.t("Нет ключа Claude API. Добавьте его, чтобы получать варианты.",
                                 "No Claude API key. Add one to get options.")
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

    // MARK: Play

    public func play(_ variant: PhraseVariant) {
        if playingVariantID == variant.id { stopPlayback(); return }   // tap again = stop
        playTask?.cancel()
        playingVariantID = variant.id
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(variant.en) where state == .finished {
                    break
                }
            } catch {
                // playback failure is non-fatal
            }
            if !Task.isCancelled, self.playingVariantID == variant.id { self.playingVariantID = nil }
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playingVariantID = nil
    }

    // MARK: Save / unsave (enrich-then-store)

    public func toggleSave(_ variant: PhraseVariant) {
        let id = variant.id
        if savedVariantIDs.contains(id) {
            savedVariantIDs.remove(id)                          // instant UI
            let storedID = savedExpressionIDs[id]
            savedExpressionIDs[id] = nil
            if let storedID {
                Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
            }
        } else {
            savedVariantIDs.insert(id)                          // instant UI; enrich+store in background
            let generation = resultsGeneration
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(
                        en: variant.en, knownRU: nil, context: variant.contextRU
                    )
                    if self.resultsGeneration != generation {
                        // Results were regenerated while saving — keep the expression persisted (the
                        // user DID bookmark it); just drop the now-defunct optimistic mapping.
                    } else if self.savedVariantIDs.contains(id) {
                        self.savedExpressionIDs[id] = stored.id
                    } else {
                        try? await self.studyList.delete(id: stored.id)   // user un-saved while saving
                    }
                } catch {
                    self.savedVariantIDs.remove(id)             // revert on failure
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
        variants = []
        intent = ""
        errorMessage = nil
        playingVariantID = nil
    }
}
