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
    public private(set) var variants: [PhraseVariant] = []
    public private(set) var errorMessage: String?
    public private(set) var isOffline = false
    public private(set) var playingVariantID: UUID?
    public var showMicPriming = false

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
    public func isSaved(_ variant: PhraseVariant) -> Bool { savedExpressionIDs[variant.id] != nil }
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
            errorMessage = "Нет доступа к микрофону. Включите его в Настройках, либо введите текст вручную."
        case SpeechRecognitionError.unavailable:
            errorMessage = "Распознавание речи недоступно. Введите текст вручную."
        case SpeechRecognitionError.noSpeechDetected:
            errorMessage = "Не расслышал. Попробуйте ещё раз."
        default:
            errorMessage = "Не удалось распознать речь. Введите текст вручную."
        }
    }

    // MARK: Generate

    public func submit() {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        run { try await self.howToSay(text) }
    }

    public func regenerate() {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        run { try await self.regenerateHowToSay(text) }
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
            errorMessage = "Что-то пошло не так. Попробуйте ещё раз."
            return
        }
        switch llm {
        case .notConfigured:
            isOffline = true
            errorMessage = "Нет ключа Claude API. Добавьте его, чтобы получать варианты."
        case .requestFailed(let info) where info.contains("offline"):
            isOffline = true
            errorMessage = "Нет соединения. Проверьте интернет и попробуйте снова."
        case .requestFailed(let info) where info.contains("timed out"):
            errorMessage = "Сервис не ответил вовремя. Попробуйте ещё раз."
        case .invalidOutput:
            errorMessage = "Не удалось разобрать ответ. Попробуйте ещё раз."
        case .cancelled:
            errorMessage = "Запрос отменён."
        case .requestFailed:
            errorMessage = "Сервис недоступен. Попробуйте позже."
        }
    }

    // MARK: Play

    public func play(_ variant: PhraseVariant) {
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
            if self.playingVariantID == variant.id { self.playingVariantID = nil }
        }
    }

    // MARK: Save / unsave (enrich-then-store)

    public func toggleSave(_ variant: PhraseVariant) {
        if let storedID = savedExpressionIDs[variant.id] {
            savedExpressionIDs[variant.id] = nil
            Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
        } else {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(
                        en: variant.en, knownRU: nil, context: variant.contextRU
                    )
                    self.savedExpressionIDs[variant.id] = stored.id
                } catch {
                    self.errorMessage = "Не удалось сохранить в изучаемое."
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
