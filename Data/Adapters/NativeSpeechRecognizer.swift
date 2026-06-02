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

        // A locale the on-device transcriber actually supports.
        guard let modelLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechRecognitionError.underlying(
                "локаль \(locale.identifier) не поддерживается распознаванием на этом устройстве"
            )
        }

        let transcriber = SpeechTranscriber(locale: modelLocale, preset: .progressiveTranscription)

        // Ensure the on-device model is installed (downloads on first use).
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .unsupported:
            throw SpeechRecognitionError.underlying("модель распознавания для \(modelLocale.identifier) недоступна")
        case .installed:
            break
        default:
            do {
                if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await installation.downloadAndInstall()
                }
            } catch {
                throw SpeechRecognitionError.underlying("не удалось загрузить модель: \(error.localizedDescription)")
            }
        }

        // Reserve the locale so the analyzer can use the model (best-effort).
        _ = try? await AssetInventory.reserve(locale: modelLocale)

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechRecognitionError.underlying("нет совместимого аудиоформата для распознавания")
        }

        // Configure + ACTIVATE the audio session BEFORE reading the input format — on a real device
        // the input node reports an invalid (0 Hz) format until the session is active.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.underlying("аудиосессия: \(error.localizedDescription)")
        }

        let (inputStream, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            try? session.setActive(false)
            throw SpeechRecognitionError.underlying("микрофон недоступен (формат \(inputFormat.sampleRate) Гц)")
        }
        let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converted = Self.convert(buffer, using: converter) else { return }
            inputContinuation.yield(AnalyzerInput(buffer: converted))
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            try? session.setActive(false)
            throw SpeechRecognitionError.underlying("аудиодвижок: \(error.localizedDescription)")
        }

        defer {
            inputNode.removeTap(onBus: 0)
            engine.stop()
            inputContinuation.finish()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }

        do {
            try await analyzer.start(inputSequence: inputStream)
        } catch {
            throw SpeechRecognitionError.underlying("запуск анализатора: \(error.localizedDescription)")
        }

        do {
            for try await result in transcriber.results {
                output.yield(SpeechTranscript(text: String(result.text.characters), isFinal: result.isFinal))
            }
            output.finish()
        } catch is CancellationError {
            output.finish()
        } catch {
            throw SpeechRecognitionError.underlying("распознавание: \(error.localizedDescription)")
        }
    }

    /// Convert a mic buffer into the analyzer's format. Passthrough if formats already match.
    private static func convert(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter?) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let outFormat = converter.outputFormat
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return nil }
        let feeder = BufferFeeder(buffer)
        var error: NSError?
        converter.convert(to: out, error: &error, withInputFrom: feeder.next)
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

/// Feeds a single captured buffer to `AVAudioConverter` exactly once. A reference type marked
/// `@unchecked Sendable` so the converter's `@Sendable` input block doesn't capture a mutable `var`
/// or a non-Sendable buffer directly (avoids Swift 6 concurrency warnings).
private final class BufferFeeder: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func next(_ packetCount: AVAudioPacketCount,
              _ outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioPCMBuffer? {
        if let buffer {
            self.buffer = nil
            outStatus.pointee = .haveData
            return buffer
        }
        outStatus.pointee = .noDataNow
        return nil
    }
}
