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

/// `{ "translation": "..." }` — translation into a configurable target language.
public struct TargetTranslation: Codable, Sendable, Equatable {
    public let translation: String
}

/// `{ "variants": [ { en, register, context_ru } ] }`
public struct HowToSayResult: Codable, Sendable, Equatable {
    public let variants: [PhraseVariant]
}

/// `{ meaning, register, context, analogy }` — a learner-facing explanation of an English
/// expression, written in the user's NATIVE language (not a translation).
public struct ExpressionExplanation: Codable, Sendable, Equatable {
    /// What the expression actually means / what is implied.
    public let meaning: String
    /// Tone of voice + how formal, casual, slangy, rude or offensive it is, and who says it to whom.
    public let register: String
    /// How it lands in an English-speaking culture — when and where it's used.
    public let context: String
    /// A comparison to an equivalent in the learner's own language/culture.
    public let analogy: String

    public init(meaning: String, register: String, context: String, analogy: String) {
        self.meaning = meaning
        self.register = register
        self.context = context
        self.analogy = analogy
    }
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

// MARK: - translateToTarget ("Понять"/In: understand OR compose, into target language)

/// The model decides between TWO jobs and returns ONE result in `targetLanguage`:
///  • a faithful, meaning-accurate translation of text the user wants to understand, OR
///  • a phrase composed from an instruction ("скажи, что я занят"), styled by `tone`.
/// Source language auto-detected.
public struct TranslateToTargetTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = TargetTranslation

    public let id = "translateToTarget"
    public let targetLanguage: String   // e.g. "Russian", "English"
    public let tone: Register
    public init(targetLanguage: String, tone: Register = .casual) {
        self.targetLanguage = targetLanguage
        self.tone = tone
    }

    public var systemPrompt: String {
        """
        You produce ONE result in \(targetLanguage) for someone learning a language.
        Detect the source language automatically and decide what the user's input is:

        1. A word, phrase, sentence, or passage to UNDERSTAND (something they read or heard).
           Translate it into \(targetLanguage), preserving the exact meaning. Do not embellish or
           change the register.

        2. An INSTRUCTION describing what they want to say, e.g. "say that I have no time",
           "tell him I'll be late", "вежливо откажись от встречи". Compose ONE natural
           \(targetLanguage) phrase that expresses it in a \(toneHint) register, worded as if the
           user is saying it themselves — not a description of the request.

        If the input could be read either way, prefer a faithful translation.
        Return ONLY the result in "translation" — no commentary, labels, quotes, transliteration,
        or alternatives. \(plainTextRule)
        """
    }

    private var toneHint: String {
        switch tone {
        case .formal: "formal and polite"
        case .neutral, .casual: "everyday conversational"
        case .slang: "informal and slangy"
        }
    }

    public var outputJSONSchema: String {
        #"{"type":"object","properties":{"translation":{"type":"string"}},"required":["translation"]}"#
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> TargetTranslation {
        try decodeJSON(TargetTranslation.self, from: rawJSON)
    }
}

// MARK: - explainExpression ("Понять"/Get, Explain mode)

/// An English word/phrase → a structured explanation in the learner's NATIVE language: what it
/// means, its tone/register, how it lands in an English-speaking culture, and an analogy to the
/// learner's own language. For understanding nuance, NOT translating.
public struct ExplainExpressionTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = ExpressionExplanation

    public let id = "explainExpression"
    public let explanationLanguage: String   // the user's native language, e.g. "Russian"
    public init(explanationLanguage: String) {
        self.explanationLanguage = explanationLanguage
    }

    public var systemPrompt: String {
        """
        You explain an English word, phrase, or expression to a native \(explanationLanguage) speaker
        who is learning English. Write EVERY field in \(explanationLanguage), in clear, friendly
        language a non-native speaker understands. Explain the nuance — do NOT just translate it.

        Return four fields:
        - "meaning": what the expression actually means and what is implied — the real sense, not a
          word-for-word translation.
        - "register": the tone of voice and how formal, neutral, casual, slangy, rude, or offensive
          it is, and who would say it to whom in which situations.
        - "context": what it signals in an English-speaking culture — when and where it is used and
          how it tends to land on a listener.
        - "analogy": a comparison to an equivalent expression or situation in the
          \(explanationLanguage)-speaking culture, so the learner can map it onto something familiar.

        If the input is a single neutral word, still describe its connotations and typical usage.
        \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        """
        {"type":"object","properties":{"meaning":{"type":"string"},"register":{"type":"string"},
        "context":{"type":"string"},"analogy":{"type":"string"}},
        "required":["meaning","register","context","analogy"]}
        """
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> ExpressionExplanation {
        let raw = try decodeJSON(ExpressionExplanation.self, from: rawJSON)
        return ExpressionExplanation(
            meaning: PlainText.clean(raw.meaning),
            register: PlainText.clean(raw.register),
            context: PlainText.clean(raw.context),
            analogy: PlainText.clean(raw.analogy)
        )
    }
}

// MARK: - photoBlocks (multimodal: image → blocks of en + ru)

/// `{ "blocks": [ { en, ru } ] }` — the model decides how many blocks.
public struct PhotoBlocksResult: Codable, Sendable, Equatable {
    public let blocks: [TranslatedBlock]
}

/// Image → blocks of connected English text, each with a Russian translation. The LLM does the
/// recognition AND translation (replaces local OCR).
public struct PhotoBlocksTemplate: PromptTemplate {
    public typealias Input = RecognizableImage
    public typealias Output = PhotoBlocksResult

    public let id = "photoBlocks"
    public init() {}

    public var systemPrompt: String {
        """
        You read English text from a photo. Group the text into BLOCKS of connected meaning — decide
        how many blocks yourself (e.g. a sign, a paragraph, one menu item). For each block return the
        English text in "en" and a natural Russian translation in "ru". Ignore decorative noise and
        anything that isn't English text; if there is no English text, return an empty "blocks" array.
        \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        """
        {"type":"object","properties":{"blocks":{"type":"array","items":{"type":"object",
        "properties":{"en":{"type":"string"},"ru":{"type":"string"}},"required":["en","ru"]}}},
        "required":["blocks"]}
        """
    }

    public func userMessage(for input: RecognizableImage) -> String {
        "Извлеки блоки английского текста с изображения и переведи каждый блок на русский."
    }

    public func image(for input: RecognizableImage) -> Data? { input.data }

    public func decode(_ rawJSON: String) throws -> PhotoBlocksResult {
        let raw = try decodeJSON(PhotoBlocksResult.self, from: rawJSON)
        let cleaned = raw.blocks
            .map { TranslatedBlock(en: PlainText.clean($0.en), ru: PlainText.clean($0.ru)) }
            .filter { !$0.en.isEmpty }
        return PhotoBlocksResult(blocks: cleaned)
    }
}

// MARK: - photoTranslate (legacy text-translate; kept for the port/history shape)

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
