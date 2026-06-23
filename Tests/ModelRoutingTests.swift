//
//  ModelRoutingTests.swift
//  EnglishHelper — Tests
//
//  Per-scenario model routing: the user-facing choice → tier mapping, the defaults (Haiku translate /
//  Sonnet explain), templates honoring their tier, and the interactor passing the live tier through.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite struct ModelRoutingTests {

    @Test func modelChoiceMapsToTier() {
        #expect(LLMModelChoice.haiku.tier == .fast)
        #expect(LLMModelChoice.sonnet.tier == .standard)
    }

    @Test func defaultsAreHaikuTranslateSonnetExplainAndSayIt() {
        UserDefaults.standard.removeObject(forKey: "translateModel")
        UserDefaults.standard.removeObject(forKey: "explainModel")
        UserDefaults.standard.removeObject(forKey: "sayItModel")
        #expect(LLMModelChoice.currentTranslate == .haiku)
        #expect(LLMModelChoice.currentExplain == .sonnet)
        #expect(LLMModelChoice.currentSayIt == .sonnet)
    }

    @Test func templatesRouteToTheirTier() {
        #expect(UnderstandTemplate(tier: .standard).modelTier == .standard)
        #expect(UnderstandTemplate(tier: .fast).modelTier == .fast)
        #expect(ExplainExpressionTemplate(tier: .fast).modelTier == .fast)
        #expect(ExplainExpressionTemplate(tier: .standard).modelTier == .standard)
        #expect(HowToSayTemplate(tier: .fast).modelTier == .fast)
        #expect(HowToSayTemplate(tier: .standard).modelTier == .standard)
        #expect(WhatToSayTemplate(tier: .standard).modelTier == .standard)
    }

    @Test func interactorPassesProviderTierToTemplate() async throws {
        let spy = TierSpyLLMClient(cannedJSON: #"{"studied":"x","natives":["y"]}"#)
        let interactor = UnderstandInteractor(llm: spy, history: MockHistoryRepository(), tier: { .standard })
        _ = try await interactor("hi", studiedLanguage: "English", nativeLanguage: "Russian")
        #expect(spy.captured == .standard)   // the provider's tier reached the template (→ the client)
    }
}

/// Records the model tier the interactor asks for, then returns a canned, schema-valid response.
private final class TierSpyLLMClient: LLMClient, @unchecked Sendable {
    let cannedJSON: String
    private(set) var captured: ModelTier?
    init(cannedJSON: String) { self.cannedJSON = cannedJSON }
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        captured = template.modelTier
        return try template.decode(cannedJSON)
    }
}
