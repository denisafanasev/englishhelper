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

/// `{ studied, native }` — a faithful rendering of the input in BOTH the studied language (the
/// card headline + TTS) and the native language (the understanding line). "Get it" / Translate.
public struct Understanding: Codable, Sendable, Equatable {
    /// The input rendered in the STUDIED language (headline + spoken).
    public let studied: String
    /// The input rendered in the NATIVE language (the understanding line).
    public let native: String
    public init(studied: String, native: String) {
        self.studied = studied
        self.native = native
    }
}

/// `{ studied, meaning, register, context, analogy }` — a learner-facing explanation of an
/// expression. `studied` is the expression in the STUDIED language (headline + TTS); the rest are
/// written in the user's NATIVE language (not a translation).
public struct ExpressionExplanation: Codable, Sendable, Equatable {
    /// The expression rendered in the STUDIED language (headline + spoken).
    public let studied: String
    /// What the expression actually means / what is implied.
    public let meaning: String
    /// Tone of voice + how formal, casual, slangy, rude or offensive it is, and who says it to whom.
    public let register: String
    /// How it lands in the studied-language culture — when and where it's used.
    public let context: String
    /// A comparison to an equivalent in the learner's own (native) language/culture.
    public let analogy: String

    public init(studied: String, meaning: String, register: String, context: String, analogy: String) {
        self.studied = studied
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
    public let studiedLanguage: String   // the language being learned — the variants are in THIS language
    public let nativeLanguage: String    // the learner's own language — the notes are in THIS language
    public init(tone: Register = .casual, studiedLanguage: String = "English", nativeLanguage: String = "Russian") {
        self.tone = tone
        self.studiedLanguage = studiedLanguage
        self.nativeLanguage = nativeLanguage
    }

    public var systemPrompt: String {
        """
        You help a \(nativeLanguage) speaker who is learning \(studiedLanguage) say something naturally
        in \(studiedLanguage). The input may be written in \(nativeLanguage), in \(studiedLanguage), or
        in ANY other language — detect it and understand the intended meaning (interpret the intent as
        if expressed in \(nativeLanguage) first).
        Then return EXACTLY THREE \(studiedLanguage) variants of that intent, all in a \(toneHint) tone,
        each a DIFFERENT natural phrasing.
        Each variant has: "en" (the \(studiedLanguage) phrasing), "register" (use "\(toneRegister)"),
        and "context_ru" (one short note IN \(nativeLanguage) on when/why to use it).
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
        let cleaned = result.variants.map {
            PhraseVariant(id: $0.id, en: PlainText.clean($0.en), register: $0.register,
                          contextRU: PlainText.clean($0.contextRU))
        }
        return HowToSayResult(variants: cleaned)
    }
}

// MARK: - whatToSay

/// A SITUATION description → the 3–10 most useful phrases to say in that situation, in the studied
/// language and chosen tone, each with a native-language note. Same card shape as `howToSay`
/// (`HowToSayResult`), but the model decides HOW MANY phrases (by relevance), not a fixed three.
public struct WhatToSayTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = HowToSayResult

    public let id = "whatToSay"
    public let tone: Register
    public let studiedLanguage: String   // the phrases are produced in THIS language
    public let nativeLanguage: String    // the notes are written in THIS language
    public init(tone: Register = .casual, studiedLanguage: String = "English", nativeLanguage: String = "Russian") {
        self.tone = tone
        self.studiedLanguage = studiedLanguage
        self.nativeLanguage = nativeLanguage
    }

    public var systemPrompt: String {
        """
        You help a \(nativeLanguage) speaker who is learning \(studiedLanguage) handle a real-life
        SITUATION in \(studiedLanguage). The input is a short description of a situation (e.g. "a
        doctor's appointment", "booking a car service", "checking in at a hotel"), written in
        \(nativeLanguage), in \(studiedLanguage), or in ANY other language — detect it and understand
        the situation (do NOT translate the description; it is not the phrase to say).
        Return the phrases that would actually be MOST USEFUL to say in that situation, in
        \(studiedLanguage), all in a \(toneHint) tone. Decide how many to give by genuine usefulness:
        AT LEAST 3 and AT MOST 10 — no filler, no near-duplicates. Order them from most to least
        likely to be needed.
        Each item has: "en" (the \(studiedLanguage) phrase), "register" (use "\(toneRegister)"),
        and "context_ru" (one short note IN \(nativeLanguage) on when/why to use this phrase here).
        \(plainTextRule)
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
        tone == .neutral ? "casual" : tone.rawValue
    }

    public var outputJSONSchema: String {
        """
        {"type":"object","properties":{"variants":{"type":"array","minItems":3,"maxItems":10,
        "items":{"type":"object","properties":{"en":{"type":"string"},
        "register":{"enum":["formal","neutral","casual","slang"]},
        "context_ru":{"type":"string"}},"required":["en","register","context_ru"]}}},
        "required":["variants"]}
        """
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> HowToSayResult {
        let result = try decodeJSON(HowToSayResult.self, from: rawJSON)
        // The schema/prompt ASK for 3–10 (a quality nudge for the model). The decoder is deliberately
        // lenient on the low end: if the model returns just 1–2 genuinely-useful phrases, show them
        // rather than hard-failing the whole request — only an EMPTY set is an error. The 10-max is
        // still enforced here in case the model overshoots. Sanitize to plain text like every template.
        let clamped = result.variants.prefix(10).map {
            PhraseVariant(id: $0.id, en: PlainText.clean($0.en), register: $0.register,
                          contextRU: PlainText.clean($0.contextRU))
        }
        guard !clamped.isEmpty else {
            throw LLMError.invalidOutput("whatToSay returned no phrases")
        }
        return HowToSayResult(variants: clamped)
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

/// A word, phrase, OR a longer multi-line passage → a structured explanation in the learner's NATIVE
/// language: what it means, its tone/register, how it lands in an English-speaking culture, and an
/// analogy to the learner's own language. For understanding nuance, NOT translating. The input is
/// always explained as ONE coherent whole — a passage is never collapsed down to a single word.
///
/// Input carries the text plus an OPTIONAL photo: when explaining a block recognized from a photo
/// (the "See it" screen), the image is attached so the explanation reflects where the text actually
/// appears (a sign, menu, screenshot, post, …).
public struct ExplainInput: Sendable, Equatable {
    public let text: String
    public let image: Data?
    public init(text: String, image: Data? = nil) {
        self.text = text
        self.image = image
    }
}

public struct ExplainExpressionTemplate: PromptTemplate {
    public typealias Input = ExplainInput
    public typealias Output = ExpressionExplanation

    public let id = "explainExpression"
    public let studiedLanguage: String   // the language being learned (the "studied" headline)
    public let nativeLanguage: String    // the explanation is written in THIS language
    public init(studiedLanguage: String = "English", nativeLanguage: String = "Russian") {
        self.studiedLanguage = studiedLanguage
        self.nativeLanguage = nativeLanguage
    }

    public var systemPrompt: String {
        """
        A \(nativeLanguage) speaker who is learning \(studiedLanguage) wants to understand some input.
        The input may be a single word, a phrase, or a longer MULTI-LINE passage (e.g. several lines
        read from a photo). Detect the input language (it may be in \(studiedLanguage), in
        \(nativeLanguage), or in any other language). If a photo is attached, it shows where this text
        appears (a sign, menu, screen, post, …) — use that visual context so the explanation fits that
        specific situation.

        Explain ALL of the input as ONE coherent whole. NEVER reduce a multi-line passage to a single
        word or phrase and explain only that — cover everything you were given:
        - a single word or short phrase → explain that expression (its real sense and connotations);
        - a longer / multi-line passage → explain the passage as a whole: its overall meaning, its
          overall tone, where such text appears, and a familiar equivalent — do not pick out just one
          line.

        LANGUAGE RULES (critical):
        - The "studied" field is in \(studiedLanguage) (the input itself).
        - EVERY other field — "meaning", "register", "context", "analogy" — MUST be written ENTIRELY in
          \(nativeLanguage). Even when a field describes the \(studiedLanguage) text or
          \(studiedLanguage)-speaking culture, write that description IN \(nativeLanguage). Never write
          meaning, register, or context in \(studiedLanguage).

        Return (explain the nuance — do NOT just translate):
        - "studied": the WHOLE input in \(studiedLanguage), preserving every line (if it is already in
          \(studiedLanguage), copy it verbatim; never shorten it to one expression).
        - "meaning" (in \(nativeLanguage)): what it actually means and what is implied — the real sense
          of the whole thing.
        - "register" (in \(nativeLanguage)): the tone of voice and how formal, neutral, casual, slangy,
          rude, or offensive it is, and who would say it to whom.
        - "context" (in \(nativeLanguage)): what it signals in \(studiedLanguage)-speaking culture —
          when and where it is used.
        - "analogy" (in \(nativeLanguage)): a comparison to an equivalent expression or situation in
          \(nativeLanguage)-speaking culture, so the learner can map it onto something familiar.

        If the input is a single neutral word, still describe its connotations and typical usage.
        \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        """
        {"type":"object","properties":{"studied":{"type":"string"},"meaning":{"type":"string"},
        "register":{"type":"string"},"context":{"type":"string"},"analogy":{"type":"string"}},
        "required":["studied","meaning","register","context","analogy"]}
        """
    }

    public func userMessage(for input: ExplainInput) -> String { input.text }

    public func image(for input: ExplainInput) -> Data? { input.image }

    public func decode(_ rawJSON: String) throws -> ExpressionExplanation {
        let raw = try decodeJSON(ExpressionExplanation.self, from: rawJSON)
        return ExpressionExplanation(
            studied: PlainText.clean(raw.studied),
            meaning: PlainText.clean(raw.meaning),
            register: PlainText.clean(raw.register),
            context: PlainText.clean(raw.context),
            analogy: PlainText.clean(raw.analogy)
        )
    }
}

// MARK: - understand ("Понять"/Get, Translate mode — faithful, into studied + native)

/// Faithful translation of input (ANY language) into BOTH the studied language (headline + TTS) and
/// the native language (understanding line). No composing, no tone — pure translation, source
/// auto-detected. Each rendering is translated from the ORIGINAL (never chained); when the input is
/// already in a target language, that field is the input verbatim.
public struct UnderstandTemplate: PromptTemplate {
    public typealias Input = String
    public typealias Output = Understanding

    public let id = "understand"
    public let studiedLanguage: String
    public let nativeLanguage: String
    public init(studiedLanguage: String = "English", nativeLanguage: String = "Russian") {
        self.studiedLanguage = studiedLanguage
        self.nativeLanguage = nativeLanguage
    }

    public var systemPrompt: String {
        """
        The user wants to understand some text. It may be in \(studiedLanguage), in \(nativeLanguage),
        or in ANY other language — detect the source language automatically. Provide a FAITHFUL
        translation that preserves the exact meaning and register; do NOT compose, embellish, add
        commentary, or change the register.
        Return TWO fields, each translated independently from the ORIGINAL text (never translate one
        translation into another):
        - "studied": the text in \(studiedLanguage) (if the input is already in \(studiedLanguage),
          copy it verbatim).
        - "native": the text in \(nativeLanguage) (if the input is already in \(nativeLanguage),
          copy it verbatim).
        \(plainTextRule)
        """
    }

    public var outputJSONSchema: String {
        #"{"type":"object","properties":{"studied":{"type":"string"},"native":{"type":"string"}},"required":["studied","native"]}"#
    }

    public func userMessage(for input: String) -> String { input }

    public func decode(_ rawJSON: String) throws -> Understanding {
        let raw = try decodeJSON(Understanding.self, from: rawJSON)
        return Understanding(studied: PlainText.clean(raw.studied), native: PlainText.clean(raw.native))
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
    public let studiedLanguage: String   // each block is rendered in THIS language as "en" (headline + TTS)
    public let nativeLanguage: String    // ...and in THIS language as "ru" (understanding line)
    public init(studiedLanguage: String = "English", nativeLanguage: String = "Russian") {
        self.studiedLanguage = studiedLanguage
        self.nativeLanguage = nativeLanguage
    }

    // A photo can contain a LOT of text (a full menu, a page) — each block emits en + ru, so the
    // response is far larger than the short text tasks. 2048 truncates it mid-JSON; give it room.
    public var maxOutputTokens: Int { 8192 }
    // Vision OCR + translation of dense text: lean toward accuracy/headroom over raw speed.
    public var prefersFastResponse: Bool { false }

    public var systemPrompt: String {
        """
        You read text from a photo. The text may be in ANY language. Group it into BLOCKS of connected
        meaning — decide how many blocks yourself (e.g. a sign, a paragraph, one menu item) and detect
        each block's language. For each block return:
        - "en": the block rendered in \(studiedLanguage) (if the block is already in \(studiedLanguage),
          copy it verbatim).
        - "ru": the block rendered in \(nativeLanguage) (if the block is already in \(nativeLanguage),
          copy it verbatim).
        Translate each rendering from the ORIGINAL block text (do not chain translations). Ignore
        decorative noise, logos, and fragments that are only numbers or symbols; if there is no
        readable text, return an empty "blocks" array. \(plainTextRule)
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
        "Read the text blocks from the image; render each in \(studiedLanguage) as \"en\" and in \(nativeLanguage) as \"ru\"."
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
