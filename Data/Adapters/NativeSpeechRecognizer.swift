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

private let speechLog = Logger(subsystem: "com.englishhelper.app", category: "speech")

public final class NativeSpeechRecognizer: SpeechRecognizing, @unchecked Sendable {
    private let locale: Locale
    public init(locale: Locale = Locale(identifier: "ru-RU")) { self.locale = locale }

    public func transcribe() -> AsyncThrowingStream<SpeechTranscript, Error> {
        let session = RecognitionSession(locale: locale)
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
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechRecognitionError.underlying("распознаватель для \(locale.identifier) не создан")
        }
        guard recognizer.isAvailable else {
            throw SpeechRecognitionError.underlying("распознавание сейчас недоступно — проверьте интернет")
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false   // Russian uses the server model
        self.request = request

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.underlying("аудиосессия: \(error.localizedDescription)")
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? session.setActive(false)
            throw SpeechRecognitionError.underlying("микрофон недоступен (формат \(format.sampleRate) Гц)")
        }

        nonisolated(unsafe) let pendingRequest = request   // appended from the realtime audio thread
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            pendingRequest.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            try? session.setActive(false)
            throw SpeechRecognitionError.underlying("аудиодвижок: \(error.localizedDescription)")
        }

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                continuation.yield(SpeechTranscript(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal
                ))
                if result.isFinal { continuation.finish() }
            }
            if let error {
                speechLog.error("task error: \(error.localizedDescription, privacy: .public)")
                continuation.finish(throwing: SpeechRecognitionError.underlying(error.localizedDescription))
            }
        }
    }

    func stop() {
        Task { @MainActor [self] in
            task?.cancel()
            task = nil
            request?.endAudio()
            request = nil
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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
