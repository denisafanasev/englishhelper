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

@Suite @MainActor struct VoiceViewModelTests {

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
}
