//
//  VoiceViewModelTests.swift
//  EnglishHelperTests
//
//  "Как сказать" view-model behavior: happy path, error→offline mapping, save marking.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite(.serialized) @MainActor struct VoiceViewModelTests {

    /// The mode is persisted (like tone) so the screen reopens as last used; each test starts from
    /// the default, not whatever a previous test (or app run on this simulator) left behind.
    init() { UserDefaults.standard.removeObject(forKey: "sayItMode") }

    private func makeVM(llm: any LLMClient = MockLLMClient(), isConfigured: Bool = true) -> VoiceViewModel {
        let history = MockHistoryRepository()
        let repo = MockExpressionRepository(seed: [])
        return VoiceViewModel(
            howToSay: HowToSayInteractor(llm: llm, history: history),
            regenerateHowToSay: RegenerateHowToSayInteractor(llm: llm, history: history),
            whatToSay: WhatToSayInteractor(llm: llm, history: history),
            voiceCapture: VoiceCaptureInteractor(recognizer: MockSpeechRecognizing()),
            pronounce: PlayPronunciationInteractor(synthesizer: MockSpeechSynthesizing()),
            saveExpression: SaveExpressionInteractor(
                enrich: EnrichExpressionInteractor(llm: llm), repository: repo
            ),
            studyList: StudyListInteractor(repository: repo),
            isConfigured: isConfigured
        )
    }

    private func waitUntil(_ condition: () -> Bool, timeout: Duration = .seconds(2)) async throws {
        let clock = ContinuousClock()
        let start = clock.now
        while !condition() {
            if clock.now - start > timeout { return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func submitProducesThreeVariants() async throws {
        let vm = makeVM()
        vm.intent = "как сказать спасибо"
        vm.submit()
        try await waitUntil { vm.phase == .results }
        #expect(vm.phase == .results)
        #expect(vm.variants.count == 3)
    }

    @Test func whatToSayModeProducesSituationPhrases() async throws {
        let vm = makeVM()
        vm.selectMode(.whatToSay)
        #expect(vm.mode == .whatToSay)
        vm.intent = "приём у врача"
        vm.submit()
        try await waitUntil { vm.phase == .results }
        #expect(vm.phase == .results)
        // "What to say" returns a relevance-driven set (3–10), not a fixed three.
        #expect(vm.variants.count >= 3)
        #expect(vm.variants.count <= 10)
    }

    @Test func failureMapsToOfflineWhenNotConfigured() async throws {
        let vm = makeVM(llm: StubLLMClient(behavior: .failure(.notConfigured), latency: .milliseconds(1)))
        vm.intent = "привет"
        vm.submit()
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline)
    }

    @Test func switchingModeMidFlightWithoutInputDropsRequest() async throws {
        // A slow request keeps us in `.processing` so we can switch modes mid-flight.
        let vm = makeVM(llm: StubLLMClient(behavior: .success, latency: .milliseconds(200)))
        vm.intent = "как сказать спасибо"
        vm.submit()
        #expect(vm.phase == .processing)

        // Clear the input, then switch mode: nothing to re-run with → the in-flight request is
        // dropped and the screen returns to idle WITHOUT surfacing a cancellation error.
        vm.intent = ""
        vm.selectMode(.whatToSay)
        #expect(vm.phase == .idle)
        #expect(vm.variants.isEmpty)

        // The superseded request must not resurface results or an error after it unwinds.
        try await Task.sleep(for: .milliseconds(300))
        #expect(vm.phase == .idle)
        #expect(vm.variants.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test func toggleSaveMarksVariantSaved() async throws {
        let vm = makeVM()
        vm.intent = "как сказать спасибо"
        vm.submit()
        try await waitUntil { vm.phase == .results }
        let variant = try #require(vm.variants.first)

        vm.toggleSave(variant)
        try await waitUntil { vm.isSaved(variant) }
        #expect(vm.isSaved(variant))
    }

    // MARK: State preservation (leave / return)

    /// Leaving the screen with results on screen drops an edit the user never submitted, so on
    /// return the input matches the visible variants. The results themselves are untouched — the
    /// only way to generate for the new text is to actually press the button.
    @Test func leavingScreenRevertsUnsubmittedEdit() async throws {
        let vm = makeVM()
        vm.intent = "как сказать спасибо"
        vm.submit()
        try await waitUntil { vm.phase == .results }
        let shown = vm.variants.map(\.en)

        vm.intent = "совсем другой текст"      // edited, never submitted
        vm.screenDisappeared()                  // ← tab switched away

        #expect(vm.intent == "как сказать спасибо")
        #expect(vm.phase == .results)
        #expect(vm.variants.map(\.en) == shown)
    }

    /// With nothing generated there is nothing to mismatch — a draft survives leaving the screen.
    @Test func leavingScreenKeepsDraftWhenNothingGenerated() {
        let vm = makeVM()
        vm.intent = "черновик"
        vm.screenDisappeared()
        #expect(vm.intent == "черновик")
        #expect(vm.phase == .idle)
    }

    /// The chosen mode is persisted: a fresh view model (next launch) starts in the last-used mode.
    @Test func modePersistsAcrossInstances() {
        let vm = makeVM()
        vm.selectMode(.whatToSay)
        #expect(makeVM().mode == .whatToSay)
    }

    /// The Say-it Lock Screen widget calls beginVoiceInput on open; it must START the mic (not toggle)
    /// and survive iOS 26's double-delivered deep link — a second call must NOT turn the mic back off.
    @Test func beginVoiceInputStartsMicAndIsIdempotent() {
        UserDefaults.standard.set(true, forKey: "didPrimeMic")   // primed → starts directly, no priming sheet
        let vm = makeVM()
        vm.beginVoiceInput()
        #expect(vm.isListening)                                   // mic on
        vm.beginVoiceInput()                                      // second (double-fire) must be a no-op
        #expect(vm.isListening)
    }
}
