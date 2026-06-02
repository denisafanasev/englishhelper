//
//  PhotoTranslateViewModelTests.swift
//  EnglishHelperTests
//
//  "Фото-перевод" view-model: happy path (OCR+boxes→RU), no-text error mapping, save toggle.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite @MainActor struct PhotoTranslateViewModelTests {

    private func makeVM(
        ocr: any TextRecognizing = MockTextRecognizing(),
        llm: any LLMClient = MockLLMClient()
    ) -> PhotoTranslateViewModel {
        let repo = MockExpressionRepository(seed: [])
        return PhotoTranslateViewModel(
            photoTranslate: PhotoTranslateInteractor(ocr: ocr, llm: llm, history: MockHistoryRepository()),
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

    @Test func producesTranslationWithBoxes() async throws {
        let vm = makeVM()
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        let result = try #require(vm.result)
        #expect(vm.phase == .result)
        #expect(result.ru.isEmpty == false)
        #expect(vm.blocks.isEmpty == false)
    }

    @Test func noTextFoundMapsToFriendlyError() async throws {
        let vm = makeVM(ocr: StubTextRecognizing(behavior: .failure(.noTextFound), latency: .milliseconds(1)))
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline == false)
        #expect(vm.errorMessage?.isEmpty == false)
    }

    @Test func toggleSaveMarksSaved() async throws {
        let vm = makeVM()
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        vm.toggleSave()
        try await waitUntil { vm.isSaved }
        #expect(vm.isSaved)
    }
}
