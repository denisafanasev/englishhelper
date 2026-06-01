//
//  MockSpeech.swift
//  EnglishHelper — Data (mock adapters)
//

import Foundation
import Domain

/// Emits a couple of partial transcripts then a final one.
public final class MockSpeechRecognizing: SpeechRecognizing {
    private let phrases: [String]
    public init(phrases: [String] = ["как", "как сказать", "как сказать спасибо"]) {
        self.phrases = phrases
    }

    public func transcribe() -> AsyncThrowingStream<SpeechTranscript, Error> {
        let phrases = self.phrases
        return AsyncThrowingStream { continuation in
            for (i, text) in phrases.enumerated() {
                continuation.yield(SpeechTranscript(text: text, isFinal: i == phrases.count - 1))
            }
            continuation.finish()
        }
    }
}

/// Walks preparing → speaking → finished.
public final class MockSpeechSynthesizing: SpeechSynthesizing {
    public init() {}

    public func speak(_ text: String) -> AsyncThrowingStream<SpeechPlaybackState, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.preparing)
            continuation.yield(.speaking(progress: 0.5))
            continuation.yield(.speaking(progress: 1.0))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
