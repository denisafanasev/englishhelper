//
//  TranslateViewModelTests.swift
//  EnglishHelperTests
//
//  "Перевод" view-model behavior: happy path, offline mapping, save toggle.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite @MainActor struct TranslateViewModelTests {

    private func makeVM(llm: any LLMClient = MockLLMClient(), isConfigured: Bool = true) -> TranslateViewModel {
        let history = MockHistoryRepository()
        let repo = MockExpressionRepository(seed: [])
        return TranslateViewModel(
            translate: TranslateTextInteractor(llm: llm, history: history),
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

    @Test func translateProducesRussian() async throws {
        let vm = makeVM()
        vm.sourceText = "I appreciate it"
        vm.submit()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(!vm.translation.isEmpty)
    }

    @Test func failureMapsToOffline() async throws {
        let vm = makeVM(llm: StubLLMClient(behavior: .failure(.requestFailed("offline")), latency: .milliseconds(1)))
        vm.sourceText = "hello"
        vm.submit()
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline)
    }

    @Test func toggleSaveMarksSaved() async throws {
        let vm = makeVM()
        vm.sourceText = "I appreciate it"
        vm.submit()
        try await waitUntil { vm.phase == .result }
        vm.toggleSave()
        try await waitUntil { vm.isSaved }
        #expect(vm.isSaved)
    }
}
