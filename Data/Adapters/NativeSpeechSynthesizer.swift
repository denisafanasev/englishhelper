//
//  NativeSpeechSynthesizer.swift
//  EnglishHelper — Data (adapter for SpeechSynthesizing)
//
//  AVSpeechSynthesizer. Speaks in the configured locale (the STUDIED language); reports playback
//  state and supports stop via stream cancellation. The port assumes nothing on-device: a
//  streamed-chunk cloud TTS can satisfy it unchanged.
//

import Foundation
import AVFoundation
import Domain

public final class NativeSpeechSynthesizer: SpeechSynthesizing, @unchecked Sendable {
    private let localeProvider: @Sendable () -> String

    /// Fixed-voice synthesizer (e.g. tests).
    public init(voiceLanguage: String = "en-US") { self.localeProvider = { voiceLanguage } }

    /// Dynamic-voice synthesizer: the voice locale is resolved per utterance, so TTS follows the
    /// user's currently-selected STUDIED language.
    public init(localeProvider: @escaping @Sendable () -> String) { self.localeProvider = localeProvider }

    public func speak(_ text: String) -> AsyncThrowingStream<SpeechPlaybackState, Error> {
        let language = localeProvider()
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()   // AVSpeechSynthesizer isn't Sendable
            let delegate = SynthesisDelegate(
                continuation: continuation, totalLength: text.utf16.count
            )
            synthesizer.delegate = delegate   // delegate is weak; retained via onTermination below

            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true)
            } catch {
                continuation.finish(throwing: SpeechSynthesisError.underlying(error.localizedDescription))
                return
            }

            // No installed voice for either the studied language or the en-US fallback: speak() could
            // silently do nothing and never fire a delegate callback, hanging the stream in .preparing
            // forever. Fail fast (and un-duck) instead.
            guard let voice = AVSpeechSynthesisVoice(language: language)
                ?? AVSpeechSynthesisVoice(language: "en-US") else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                continuation.finish(throwing: SpeechSynthesisError.unavailable)
                return
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice

            continuation.yield(.preparing)
            continuation.onTermination = { @Sendable _ in
                synthesizer.stopSpeaking(at: .immediate)
                // Deactivate the shared session on EVERY end (finish, cancel, error) so `.duckOthers`
                // doesn't keep background audio ducked after playback — single chokepoint for all paths.
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
