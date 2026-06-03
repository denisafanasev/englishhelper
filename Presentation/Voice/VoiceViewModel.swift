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

    // UI state
    public private(set) var phase: Phase = .idle
    public var intent: String = ""                       // editable transcript / typed input
    /// Tone/register for the generated phrases — chosen on-screen, persisted (shared with the
    /// "Понять" compose path via `ToneOfVoice.current`).
    public var tone: ToneOfVoice = ToneOfVoice.current {
        didSet { UserDefaults.standard.set(tone.rawValue, forKey: ToneOfVoice.storageKey) }
    }
    public private(set) var variants: [PhraseVariant] = []
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false
    public private(set) var playingVariantID: UUID?
    public var showMicPriming = false

    private var savedVariantIDs: Set<UUID> = []           // optimistic "saved" flag (instant UI)
    private var savedExpressionIDs: [UUID: UUID] = [:]    // variant.id → stored Expression.id

    // Dependencies (use cases)
    private let howToSay: any HowToSayUseCase
    private let regenerateHowToSay: any RegenerateHowToSayUseCase
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
        voiceCapture: any VoiceCaptureUseCase,
        pronounce: any PlayPronunciationUseCase,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        isConfigured: Bool
    ) {
        self.howToSay = howToSay
        self.regenerateHowToSay = regenerateHowToSay
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
                                 "Couldn't recognize speech: \(detail). You can type the text instead.")
        default:
            errorMessage = Loc.t("Не удалось распознать речь. Введите текст вручную.",
                                 "Couldn't recognize speech. Type the text instead.")
        }
    }

    // MARK: Generate

    public func submit() {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        run { try await self.howToSay(text, tone: self.tone.register) }
    }

    public func regenerate() {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        run { try await self.regenerateHowToSay(text, tone: self.tone.register) }
    }

    /// One button drives both: regenerate when results are shown, otherwise generate a fresh set.
    public func pick() {
        if phase == .results { regenerate() } else { submit() }
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
                self.phase = .results
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
            errorMessage = Loc.t("Нет ключа Claude API. Добавьте его, чтобы получать варианты.",
                                 "No Claude API key. Add one to get options.")
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
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(
                        en: variant.en, knownRU: nil, context: variant.contextRU
                    )
                    if self.savedVariantIDs.contains(id) {
                        self.savedExpressionIDs[id] = stored.id
                    } else {
                        try? await self.studyList.delete(id: stored.id)   // unsaved while saving
                    }
                } catch {
                    self.savedVariantIDs.remove(id)             // revert on failure
                    self.errorMessage = Loc.t("Не удалось сохранить в изучаемое.",
                                              "Couldn't save to your study list.")
                }
            }
        }
    }

    public func reset() {
        captureTask?.cancel(); requestTask?.cancel(); playTask?.cancel()
        phase = .idle
        variants = []
        intent = ""
        errorMessage = nil
        playingVariantID = nil
    }
}
