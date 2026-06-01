//
//  MockLLMClient.swift
//  EnglishHelper — Data (mock adapter)
//
//  Boots the app without the network. Returns canned JSON per template and decodes it through
//  the template's OWN decoder, so mocks exercise the real schema/contract path.
//

import Foundation
import Domain

public final class MockLLMClient: LLMClient {
    public init() {}

    public func run<Template: PromptTemplate>(
        _ template: Template,
        input: Template.Input
    ) async throws -> Template.Output {
        try template.decode(Self.cannedJSON(for: template.id))
    }

    static func cannedJSON(for templateID: String) -> String {
        switch templateID {
        case "howToSay":
            return """
            {"variants":[
              {"en":"Could you help me with this?","register":"formal","context_ru":"Вежливо — для коллег и незнакомых."},
              {"en":"Can you give me a hand?","register":"casual","context_ru":"Нейтрально — для друзей и быта."},
              {"en":"Gimme a hand, will ya?","register":"slang","context_ru":"Сленг, очень неформально."}
            ]}
            """
        case "translateText", "photoTranslate":
            return #"{"ru":"Это тестовый перевод."}"#
        case "enrichCard":
            return """
            {"ru":"я ценю это","example":"Thanks for covering my shift — I really appreciate it.",
             "synonyms":["I'm grateful","thank you"]}
            """
        default:
            return "{}"
        }
    }
}
