//
//  NativeSpeechRecognizer.swift
//  EnglishHelper — Data (adapter for SpeechRecognizing)
//
//  iOS 26 SpeechAnalyzer / SpeechTranscriber, Russian, on-device. Emits (text, isFinal) via the
//  port's AsyncThrowingStream — so a streaming cloud ASR fits the SAME protocol later. The
//  consuming Task's cancellation stops capture and releases the mic.
//

import Foundation
import Speech
import AVFoundation
import Domain

public final class NativeSpeechRecognizer: SpeechRecognizing, @unchecked Sendable {
    private let locale: Locale
    public init(locale: Locale = Locale(identifier: "ru-RU")) { self.locale = locale }

    public func transcribe() -> AsyncThrowingStream<SpeechTranscript, Error> {
        let locale = self.locale
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.runSession(locale: locale, output: continuation)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private static func runSession(
        locale: Locale,
        output: AsyncThrowingStream<SpeechTranscript, Error>.Continuation
    ) async throws {
        guard await requestMicPermission(), await requestSpeechPermission() else {
            throw SpeechRecognitionError.permissionDenied
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        // Ensure the on-device model for this locale is installed.
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechRecognitionError.unavailable
        }

        let (inputStream, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        nonisolated(unsafe) let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converted = Self.convert(buffer, using: converter) else { return }
            inputContinuation.yield(AnalyzerInput(buffer: converted))
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw SpeechRecognitionError.underlying("audio engine: \(error.localizedDescription)")
        }

        defer {
            inputNode.removeTap(onBus: 0)
            engine.stop()
            inputContinuation.finish()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }

        try await analyzer.start(inputSequence: inputStream)

        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                output.yield(SpeechTranscript(text: text, isFinal: result.isFinal))
            }
            output.finish()
        } catch is CancellationError {
            output.finish()
        } catch {
            throw SpeechRecognitionError.underlying(error.localizedDescription)
        }
    }

    /// Convert a mic buffer into the analyzer's format. Passthrough if formats already match.
    private static func convert(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter?) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let outFormat = converter.outputFormat
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }

    private static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in continuation.resume(returning: granted) }
        }
    }

    private static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
