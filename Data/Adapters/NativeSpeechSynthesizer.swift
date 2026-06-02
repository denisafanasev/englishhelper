//
//  NativeSpeechSynthesizer.swift
//  EnglishHelper — Data (adapter for SpeechSynthesizing)
//
//  AVSpeechSynthesizer, English. Reports playback state and supports stop via stream cancellation.
//  The port assumes nothing on-device: a streamed-chunk cloud TTS can satisfy it unchanged.
//

import Foundation
import AVFoundation
import Domain

public final class NativeSpeechSynthesizer: SpeechSynthesizing, @unchecked Sendable {
    private let voiceLanguage: String
    public init(voiceLanguage: String = "en-US") { self.voiceLanguage = voiceLanguage }

    public func speak(_ text: String) -> AsyncThrowingStream<SpeechPlaybackState, Error> {
        let language = voiceLanguage
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()   // AVSpeechSynthesizer isn't Sendable
            let delegate = SynthesisDelegate(
                continuation: continuation, totalLength: text.utf16.count
            )
            synthesizer.delegate = delegate   // delegate is weak; retained via onTermination below

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true)
            } catch {
                continuation.finish(throwing: SpeechSynthesisError.underlying(error.localizedDescription))
                return
            }

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
                ?? AVSpeechSynthesisVoice(language: "en-US")

            continuation.yield(.preparing)
            continuation.onTermination = { @Sendable _ in
                synthesizer.stopSpeaking(at: .immediate)
                _ = delegate   // keep synthesizer + delegate alive until the stream ends
            }
            synthesizer.speak(utterance)
        }
    }
}

private final class SynthesisDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<SpeechPlaybackState, Error>.Continuation
    private let totalLength: Int

    init(continuation: AsyncThrowingStream<SpeechPlaybackState, Error>.Continuation, totalLength: Int) {
        self.continuation = continuation
        self.totalLength = totalLength
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        continuation.yield(.speaking(progress: 0))
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        guard totalLength > 0 else { return }
        let spoken = Double(characterRange.location + characterRange.length) / Double(totalLength)
        continuation.yield(.speaking(progress: min(1, max(0, spoken))))
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        continuation.yield(.finished)
        continuation.finish()
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        continuation.finish()
    }
}
