//
//  SaveAndRegenerateTests.swift
//  EnglishHelperTests
//
//  Voice-flow Domain use cases: save = enrich-then-store; regenerate appends history.
//

import Testing
import Foundation
import Domain
import Adapters

@Suite struct SaveAndRegenerateTests {

    @Test func saveEnrichesThenStores() async throws {
        let repo = MockExpressionRepository(seed: [])
        let save = SaveExpressionInteractor(
            enrich: EnrichExpressionInteractor(llm: MockLLMClient()),
            repository: repo
        )
        let stored = try await save(en: "I appreciate it", knownRU: nil, context: "тепло благодарю")

        #expect(!stored.ru.isEmpty)        // enriched
        #expect(!stored.example.isEmpty)
        #expect(stored.context == "тепло благодарю")

        let all = try await repo.all()
        #expect(all.contains { $0.id == stored.id })
    }

    @Test func regenerateProducesThreeAndAppendsHistory() async throws {
        let history = MockHistoryRepository()
        let regenerate = RegenerateHowToSayInteractor(
            llm: StubLLMClient(behavior: .success, latency: .milliseconds(1)),
            history: history
        )
        let variants = try await regenerate("как сказать привет")
        #expect(variants.count == 3)

        let entries = try await history.recent(limit: 10)
        #expect(entries.count == 1)
        #expect(entries.first?.inputText == "как сказать привет")   // original intent, not the nudge
    }
}
