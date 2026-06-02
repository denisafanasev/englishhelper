//
//  DIBootTests.swift
//  EnglishHelperTests
//
//  Verifies the composition graph boots and runs end-to-end on mock adapters — the same wiring
//  AppContainer.bootMock() performs.
//

import Testing
import Foundation
import Domain
import Adapters

@Suite struct DIBootTests {

    @Test func howToSayReturnsThreeVariantsOnMocks() async throws {
        let useCase = HowToSayInteractor(llm: MockLLMClient(), history: MockHistoryRepository())
        let variants = try await useCase("как сказать спасибо")
        #expect(variants.count == 3)
        #expect(variants.map(\.register).contains(.formal))
    }

    @Test func studyListLoadsSeedOnMocks() async throws {
        let useCase = StudyListInteractor(repository: MockExpressionRepository())
        let items = try await useCase.list()
        #expect(items.count >= 1)
    }

    @Test func requestUseCaseAppendsHistory() async throws {
        let history = MockHistoryRepository()
        let translate = TranslateTextInteractor(llm: MockLLMClient(), history: history)
        _ = try await translate("I appreciate it")
        let recent = try await history.recent(limit: 10)
        #expect(recent.count == 1)
        #expect(recent.first?.kind == .translate)
    }

    @Test func photoTranslateReturnsBlocksOnMocks() async throws {
        let useCase = PhotoTranslateInteractor(llm: MockLLMClient(), history: MockHistoryRepository())
        let blocks = try await useCase(RecognizableImage(data: Data()))
        #expect(!blocks.isEmpty)
        #expect(blocks.allSatisfy { !$0.en.isEmpty && !$0.ru.isEmpty })
    }

    @Test func exportProducesNonEmptyDeck() async throws {
        let export = ExportDeckInteractor(repository: MockExpressionRepository(), exporter: MockDeckExporting())
        let deck = try await export()
        #expect(!deck.data.isEmpty)
        #expect(deck.filename.hasSuffix(".json"))
    }
}
