//
//  AdapterStubTests.swift
//  EnglishHelperTests
//
//  Exercises each engine port against its Stub* (latency + failure) — so cloud-like behavior is
//  covered before any cloud adapter exists.
//

import Testing
import Foundation
import Domain
import Adapters

@Suite struct AdapterStubTests {

    // MARK: Speech recognition

    @Test func asrStubStreamsToFinal() async throws {
        var transcripts: [SpeechTranscript] = []
        for try await t in StubSpeechRecognizing(latency: .milliseconds(1)).transcribe() {
            transcripts.append(t)
        }
        #expect(transcripts.count >= 2)
        #expect(transcripts.last?.isFinal == true)
    }

    @Test func asrStubSurfacesFailure() async {
        await #expect(throws: SpeechRecognitionError.self) {
            for try await _ in StubSpeechRecognizing(behavior: .failure(.permissionDenied),
                                                     latency: .milliseconds(1)).transcribe() {}
        }
    }

    // MARK: Speech synthesis

    @Test func ttsStubReachesFinished() async throws {
        var states: [SpeechPlaybackState] = []
        for try await s in StubSpeechSynthesizing(latency: .milliseconds(1)).speak("hi") {
            states.append(s)
        }
        #expect(states.first == .preparing)
        #expect(states.last == .finished)
    }

    @Test func ttsStubSurfacesFailure() async {
        await #expect(throws: SpeechSynthesisError.self) {
            for try await _ in StubSpeechSynthesizing(behavior: .failure(.unavailable),
                                                      latency: .milliseconds(1)).speak("hi") {}
        }
    }

    // MARK: OCR

    @Test func ocrStubReturnsTextWithBox() async throws {
        let result = try await StubTextRecognizing(latency: .milliseconds(1))
            .recognizeText(in: RecognizableImage(data: Data()))
        #expect(!result.fullText.isEmpty)
        #expect(result.blocks.count == 1)
    }

    @Test func ocrStubSurfacesFailure() async {
        await #expect(throws: TextRecognitionError.self) {
            _ = try await StubTextRecognizing(behavior: .failure(.noTextFound), latency: .milliseconds(1))
                .recognizeText(in: RecognizableImage(data: Data()))
        }
    }
}
