//
//  NativeSpeechRecognizer.swift
//  EnglishHelper — Data (adapter for SpeechRecognizing)
//
//  SFSpeechRecognizer (Russian). The iOS 26 SpeechAnalyzer/SpeechTranscriber on-device model is not
//  available for Russian on current devices (AssetInventory reports it `.unsupported`), so we use
//  the long-proven SFSpeechRecognizer — which supports Russian (server-backed when there's no
//  on-device model). Emits (text, isFinal) via the port's stream; a streaming cloud ASR fits the
//  SAME protocol later. Swapping the engine touches only this file.
//

import Foundation
import Speech
import AVFoundation
import OSLog
import Domain

private let speechLog = Logger(subsystem: "tech.10xt.englishhelper", category: "speech")

public final class NativeSpeechRecognizer: SpeechRecognizing, @unchecked Sendable {
    private let localeProvider: @Sendable () -> Locale

    /// Fixed-locale recognizer (e.g. en-US for the "get it" English input).
    public init(locale: Locale = Locale(identifier: "ru-RU")) {
        self.localeProvider = { locale }
    }

    /// Dynamic-locale recognizer: the locale is resolved at the START of each capture, so the
    /// "say it" microphone follows the user's currently-selected native language.
    public init(localeProvider: @escaping @Sendable () -> Locale) {
        self.localeProvider = localeProvider
    }

    public func transcribe() -> AsyncThrowingStream<SpeechTranscript, Error> {
        let session = RecognitionSession(locale: localeProvider())
        return AsyncThrowingStream { continuation in
            continuation.onTermination = { @Sendable _ in session.stop() }
            session.start(yielding: continuation)
        }
    }
}

/// Owns the audio engine + recognition task for one capture session and bridges the callback-based
/// SFSpeechRecognizer to the port's AsyncThrowingStream.
private final class RecognitionSession: @unchecked Sendable {
    private let locale: Locale
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Only deactivate the shared AVAudioSession if THIS session activated it, so a late teardown
    /// can't deactivate a session another capture/playback is currently using.
    private var didActivateSession = false

    init(locale: Locale) { self.locale = locale }

    func start(yielding continuation: AsyncThrowingStream<SpeechTranscript, Error>.Continuation) {
        Task { [weak self] in
            guard let self else { return }
            guard await requestMicPermission(), await requestSpeechPermission() else {
                continuation.finish(throwing: SpeechRecognitionError.permissionDenied)
                return
            }
            await MainActor.run {
                do {
                    try self.begin(yielding: continuation)
                } catch {
                    speechLog.error("recognition failed: \(String(describing: error), privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    @MainActor
    private func begin(yielding continuation: AsyncThrowingStream<SpeechTranscript, Error>.Continuation) throws {
        // Map to TYPED cases the Presentation layer localizes — never throw user-facing prose from an
        // adapter (it would leak verbatim into an otherwise-localized message). `.underlying` carries
        // only short technical detail for the rare genuinely-unknown failure.
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechRecognitionError.unavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false   // Russian uses the server model
        self.request = request

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            didActivateSession = true
        } catch {
            throw SpeechRecognitionError.underlying("audio session: \(error.localizedDescription)")
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            deactivateSessionIfNeeded()
            throw SpeechRecognitionError.unavailable
        }

        // @Sendable so the closure is NOT MainActor-isolated — AVAudioEngine calls it on the
        // realtime audio thread, and an inherited isolation check would crash (dispatch_assert_queue).
        nonisolated(unsafe) let pendingRequest = request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            pendingRequest.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            deactivateSessionIfNeeded()
            throw SpeechRecognitionError.underlying("audio engine: \(error.localizedDescription)")
        }

        task = recognizer.recognitionTask(with: request) { @Sendable result, error in
            if let result {
                continuation.yield(SpeechTranscript(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal
                ))
                if result.isFinal { continuation.finish() }
            }
            if let error {
                speechLog.error("task error: \(error.localizedDescription, privacy: .public)")
                // Map known SFSpeech outcomes to typed cases: a "no speech" result is its own UX, and a
                // cancellation (user stop / teardown) is a CLEAN finish, not a failure. (If a final
                // result already finished the stream, these are no-ops — first terminal event wins.)
                let ns = error as NSError
                if Self.isCancellation(ns) {
                    continuation.finish()
                } else if Self.isNoSpeech(ns) {
                    continuation.finish(throwing: SpeechRecognitionError.noSpeechDetected)
                } else {
                    continuation.finish(throwing: SpeechRecognitionError.underlying(error.localizedDescription))
                }
            }
        }
    }

    /// SFSpeech "no speech detected" (kAFAssistantErrorDomain 1110, and the speech-domain no-result code).
    private static func isNoSpeech(_ error: NSError) -> Bool {
        (error.domain == "kAFAssistantErrorDomain" && error.code == 1110)
    }

    /// SFSpeech cancellation / "recognition request was canceled" codes — treat as a clean stop.
    private static func isCancellation(_ error: NSError) -> Bool {
        error.domain == "kAFAssistantErrorDomain" && [203, 216, 301].contains(error.code)
    }

    func stop() {
        Task { @MainActor [self] in
            task?.cancel()
            task = nil
            request?.endAudio()
            request = nil
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
            deactivateSessionIfNeeded()
        }
    }

    @MainActor
    private func deactivateSessionIfNeeded() {
        guard didActivateSession else { return }
        didActivateSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private func requestMicPermission() async -> Bool {
    await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in continuation.resume(returning: granted) }
    }
}

private func requestSpeechPermission() async -> Bool {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status == .authorized)
        }
    }
}
