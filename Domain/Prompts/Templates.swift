//
//  Templates.swift
//  EnglishHelper — Domain
//
//  v1 prompt templates. Each owns its system prompt, output schema, and typed decoder.
//  All string fields are plain text ONLY (no markdown / emoji / decorative symbols) — enforced
//  by the system prompts; verified by tests (Step 2).
//

import Foundation

// MARK: - Shared output payloads

/// `{ "ru": "..." }` — pure translation, shared by translate + photoTranslate.
public struct Translation: Codable, Sendable, Equatable {
    public let ru: String
}

/// `{ "variants": [ { en, register, context_ru } ] }`
public struct HowToSayResult: Codable, Sendable, Equatable {
    public let variants: [PhraseVariant]
}

/// `{ "ru", "example", "synonyms": [..] }`
public struct CardEnrichment: Codable, Sendable, Equatable {
    public let ru: String
    public let example: String
    public let synonyms: [String]
}

/// Input for `enrichCard`: an English expression, optionally with a known Russian gloss.
public struct EnrichInput: Sendable, Equatable {
    public let en: String
    public let ru: String?
    public init(en: String, ru: String? = nil) {
        self.en = en
        self.ru = ru
    }
}

// MARK: - Plain-text rule (shared)

private let plainTextRule = """
All string values must be PLAIN TEXT only: no markdown, bold, italic, emoji, quotes, \
or decorative symbols inside any field.
"""

// MARK: - howToSay

/// RU intent → exactly 3 English variants in the chosen tone/register.
public struct HowToSayTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = HowToSayResult

    public let id = "howToSay"
    public let tone: Register
    public init(tone: Register = .casual) { self.tone = tone }

    public var systemPrompt: String {
        """
        You help a Russian speaker say something naturally in English.
        Given a Russian intent, return EXACTLY THREE English variants, all in a \(toneHint) tone,
        each a DIFFERENT natural phrasing.
        Each variant has: "en" (the English phrasing), "register" (use "\(toneRegister)"),
        and "context_ru" (one short Russian note on when/why to use it).
        Do not output more or fewer than three. \(plainTextRule)
        """
    }

    private var toneHint: String {
        switch tone {
        case .formal: "formal and polite (work, strangers, writing)"
        case .neutral, .casual: "everyday conversational (friends, colleagues)"
        case .slang: "informal, slangy (close friends)"
        }
    }

    private var toneRegister: String {
        tone == .neutral ? "casual" : tone.rawValue   // the design styles 3 tiers
    }

    public var outputJSONSchema: String {
        """
        {"type":"object","properties":{"variants":{"type":"array","minItems":3,"maxItems":3,
        "items":{"type":"object","properties":{"en":{"type":"string"},
        "register":{"enum":["formal","neutral","casual","slang"]},
        "context_ru":{"type":"string"}},"required":["en","register","context_ru"]}}},
        "required":["variants"]}
        """
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> HowToSayResult {
        let result = try decodeJSON(HowToSayResult.self, from: rawJSON)
        guard result.variants.count == 3 else {
            throw LLMError.invalidOutput("howToSay expects exactly 3 variants, got \(result.variants.count)")
        }
        return result
    }
}

// MARK: - translateText

/// EN text → pure Russian translation (no commentary).
public struct TranslateTextTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = Translation

    public let id = "translateText"
    public init() {}

    public var systemPrompt: String {
        """
        Translate the given English text into natural Russian. Return ONLY the translation in "ru" —
        no commentary, alternatives, transliteration, or notes. \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        #"{"type":"object","properties":{"ru":{"type":"string"}},"required":["ru"]}"#
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> Translation {
        try decodeJSON(Translation.self, from: rawJSON)
    }
}

// MARK: - photoTranslate

/// OCR'd EN text → pure Russian translation (same schema as translateText).
public struct PhotoTranslateTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = Translation

    public let id = "photoTranslate"
    public init() {}

    public var systemPrompt: String {
        """
        The input is English text recognized from a photo (it may contain OCR noise).
        Translate it into natural Russian. Return ONLY the translation in "ru" — no commentary. \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        #"{"type":"object","properties":{"ru":{"type":"string"}},"required":["ru"]}"#
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> Translation {
        try decodeJSON(Translation.self, from: rawJSON)
    }
}

// MARK: - enrichCard

/// `{ en (+ optional ru) }` → `{ ru, example, synonyms }` for a study-list card.
public struct EnrichCardTemplate: PromptTemplate {
    public typealias Input = EnrichInput
    public typealias Output = CardEnrichment

    public let id = "enrichCard"
    public init() {}

    public var systemPrompt: String {
        """
        Enrich an English expression for a study card. Return:
        - "ru": a concise natural Russian translation.
        - "example": ONE natural English sentence that uses the expression.
        - "synonyms": 2 to 3 English near-equivalents. Use fewer if none fit; do NOT invent bad ones.
        \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        """
        {"type":"object","properties":{"ru":{"type":"string"},"example":{"type":"string"},
        "synonyms":{"type":"array","items":{"type":"string"},"maxItems":3}},
        "required":["ru","example","synonyms"]}
        """
    }

    public func userMessage(for input: EnrichInput) -> String {
        if let ru = input.ru, !ru.isEmpty {
            return "expression: \(input.en)\nknown_ru: \(ru)"
        }
        return "expression: \(input.en)"
    }

    public func decode(_ rawJSON: String) throws -> CardEnrichment {
        let raw = try decodeJSON(CardEnrichment.self, from: rawJSON)
        // Enforce the contract regardless of what the model returned:
        // plain text only, and 0–3 non-empty synonyms.
        let synonyms = raw.synonyms
            .map(PlainText.clean)
            .filter { !$0.isEmpty }
            .prefix(3)
        return CardEnrichment(
            ru: PlainText.clean(raw.ru),
            example: PlainText.clean(raw.example),
            synonyms: Array(synonyms)
        )
    }
}

// MARK: - healthCheck (connection probe)

/// Minimal probe used by the Settings live health check — the cheapest possible round-trip.
public struct HealthCheckTemplate: PromptTemplate {
    public typealias Input = Void
    public typealias Output = Bool

    public let id = "healthCheck"
    public init() {}

    public var systemPrompt: String { "Reply ONLY with the JSON object {\"ok\": true}." }
    public var outputJSONSchema: String {
        #"{"type":"object","properties":{"ok":{"type":"boolean"}},"required":["ok"]}"#
    }
    public func userMessage(for input: Void) -> String { "ping" }
    public func decode(_ rawJSON: String) throws -> Bool {
        try decodeJSON(Ping.self, from: rawJSON).ok
    }

    private struct Ping: Decodable { let ok: Bool }
}
