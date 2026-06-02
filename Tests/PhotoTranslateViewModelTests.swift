//
//  PhotoTranslateViewModelTests.swift
//  EnglishHelperTests
//
//  "Фото-перевод" (LLM vision): blocks of en+ru, no-text mapping, optimistic per-block save.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite @MainActor struct PhotoTranslateViewModelTests {

    private func makeVM(llm: any LLMClient = MockLLMClient()) -> PhotoTranslateViewModel {
        let repo = MockExpressionRepository(seed: [])
        return PhotoTranslateViewModel(
            photoTranslate: PhotoTranslateInteractor(llm: llm, history: MockHistoryRepository()),
            pronounce: PlayPronunciationInteractor(synthesizer: MockSpeechSynthesizing()),
            saveExpression: SaveExpressionInteractor(
                enrich: EnrichExpressionInteractor(llm: llm), repository: repo
            ),
            studyList: StudyListInteractor(repository: repo),
            isConfigured: true
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

    @Test func producesBlocks() async throws {
        let vm = makeVM()
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.blocks.isEmpty == false)
        #expect(vm.blocks.allSatisfy { !$0.en.isEmpty && !$0.ru.isEmpty })
    }

    @Test func noTextFoundMapsToFriendlyError() async throws {
        let vm = makeVM(llm: EmptyBlocksLLM())
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline == false)
        #expect(vm.errorMessage?.isEmpty == false)
    }

    @Test func toggleSaveMarksBlockSaved() async throws {
        let vm = makeVM()
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        let block = try #require(vm.blocks.first)
        vm.toggleSave(block)
        #expect(vm.isSaved(block))   // optimistic, immediate
    }
}

/// Returns an empty-blocks result regardless of input — used to exercise the no-text path.
private struct EmptyBlocksLLM: LLMClient {
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        try template.decode(#"{"blocks":[]}"#)
    }
}
