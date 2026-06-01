//
//  UseCaseContractTests.swift
//  EnglishHelperTests
//
//  Use-case behavior against a stub LLM (success / malformed / timeout), the history-append
//  contract, and the enrich plain-text contract.
//

import Testing
import Foundation
import Domain
import Adapters

@Suite struct UseCaseContractTests {

    // MARK: LLM request use cases vs a stub LLM

    @Test func howToSaySucceedsOnStub() async throws {
        let useCase = HowToSayInteractor(llm: StubLLMClient(behavior: .success, latency: .milliseconds(1)),
                                         history: MockHistoryRepository())
        let variants = try await useCase("как сказать спасибо")
        #expect(variants.count == 3)
    }

    @Test func translateThrowsOnMalformedJSON() async {
        let useCase = TranslateTextInteractor(llm: StubLLMClient(behavior: .malformedJSON, latency: .milliseconds(1)),
                                              history: MockHistoryRepository())
        await #expect(throws: LLMError.self) { _ = try await useCase("hello") }
    }

    @Test func translateThrowsOnTimeout() async {
        let useCase = TranslateTextInteractor(llm: StubLLMClient(behavior: .timeout, latency: .milliseconds(1)),
                                              history: MockHistoryRepository())
        await #expect(throws: LLMError.self) { _ = try await useCase("hello") }
    }

    // MARK: History-append contract — exactly one on success, zero on failure

    @Test func appendsExactlyOneHistoryEntryOnSuccess() async throws {
        let history = MockHistoryRepository()
        let useCase = HowToSayInteractor(llm: StubLLMClient(behavior: .success, latency: .milliseconds(1)),
                                         history: history)
        _ = try await useCase("привет")
        let entries = try await history.recent(limit: 10)
        #expect(entries.count == 1)
        #expect(entries.first?.kind == .howToSay)
    }

    @Test func appendsZeroHistoryEntriesOnFailure() async throws {
        let history = MockHistoryRepository()
        let useCase = HowToSayInteractor(llm: StubLLMClient(behavior: .malformedJSON, latency: .milliseconds(1)),
                                         history: history)
        await #expect(throws: LLMError.self) { _ = try await useCase("привет") }
        let entries = try await history.recent(limit: 10)
        #expect(entries.isEmpty)
    }

    // MARK: Enrich plain-text contract — no markdown/symbols, 0–3 synonyms

    @Test func enrichStripsMarkdownAndClampsSynonyms() throws {
        let dirty = #"""
        {"ru":"**жирный** текст","example":"He `really` said hi #now","synonyms":["one","*two*","three","four","five"]}
        """#
        let result = try EnrichCardTemplate().decode(dirty)

        #expect(!PlainText.hasDecoration(result.ru))
        #expect(!PlainText.hasDecoration(result.example))
        #expect(result.synonyms.count <= 3)
        #expect(result.synonyms.allSatisfy { !PlainText.hasDecoration($0) })
        #expect(result.synonyms.allSatisfy { !$0.isEmpty })
    }
}
