//
//  TranslationCacheTests.swift
//  EnglishHelper — Tests
//
//  The history-style translation cache: the SAME text (+ tone + languages) reuses the earlier result
//  instead of calling the model again; tone/language differences miss; regenerate always hits the model.
//

import Testing
import Foundation
import Domain
import Adapters

@Suite struct TranslationCacheTests {

    /// Counts run() calls, delegating to the Mock for valid canned output per template.
    private final class CountingLLM: LLMClient, @unchecked Sendable {
        nonisolated(unsafe) private(set) var calls = 0
        private let backing = MockLLMClient()
        func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
            calls += 1
            return try await backing.run(template, input: input)
        }
    }

    @Test func understandReusesCachedTranslationForSameInput() async throws {
        let llm = CountingLLM()
        let interactor = UnderstandInteractor(llm: llm, history: MockHistoryRepository(),
                                              cache: MockTranslationCache(), tier: { .fast })
        let first = try await interactor("bank", studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(llm.calls == 1)
        let second = try await interactor("bank", studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(llm.calls == 1)            // cache hit — model NOT called again
        #expect(second == first)           // and the FULL result (all variants + context) is restored
        #expect(second.variants.count >= 2)
    }

    @Test func understandMissesWhenLanguageDiffers() async throws {
        let llm = CountingLLM()
        let interactor = UnderstandInteractor(llm: llm, history: MockHistoryRepository(),
                                              cache: MockTranslationCache(), tier: { .fast })
        _ = try await interactor("bank", studiedLanguage: "English", nativeLanguage: "Russian")
        _ = try await interactor("bank", studiedLanguage: "English", nativeLanguage: "German")
        #expect(llm.calls == 2)            // a different native language is a different translation
    }

    @Test func howToSayCacheIsKeyedByTone() async throws {
        let llm = CountingLLM()
        let interactor = HowToSayInteractor(llm: llm, history: MockHistoryRepository(),
                                            cache: MockTranslationCache(), tier: { .standard })
        _ = try await interactor("привет", tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(llm.calls == 1)
        _ = try await interactor("привет", tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(llm.calls == 1)            // same tone → hit
        _ = try await interactor("привет", tone: .formal, studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(llm.calls == 2)            // different tone → different result, miss
    }

    @Test func whatToSayCachesInitialButRegenerateAlwaysHitsModel() async throws {
        let llm = CountingLLM()
        let interactor = WhatToSayInteractor(llm: llm, history: MockHistoryRepository(),
                                             cache: MockTranslationCache(), tier: { .standard })
        _ = try await interactor("ordering coffee", tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian", regenerate: false)
        #expect(llm.calls == 1)
        _ = try await interactor("ordering coffee", tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian", regenerate: false)
        #expect(llm.calls == 1)            // initial repeat → cache hit
        _ = try await interactor("ordering coffee", tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian", regenerate: true)
        #expect(llm.calls == 2)            // regenerate explicitly wants a fresh set → model called
    }

    @Test func noCacheInjectedAlwaysHitsModel() async throws {
        let llm = CountingLLM()
        let interactor = UnderstandInteractor(llm: llm, history: MockHistoryRepository(), tier: { .fast })  // cache nil
        _ = try await interactor("bank", studiedLanguage: "English", nativeLanguage: "Russian")
        _ = try await interactor("bank", studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(llm.calls == 2)            // caching disabled → no reuse
    }
}
