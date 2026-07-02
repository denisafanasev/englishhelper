//
//  RequestUseCases.swift
//  EnglishHelper — Domain (use cases)
//
//  Thin interactors: they orchestrate ports + templates and record history. No feature logic
//  beyond that wiring lives here in the skeleton.
//

import Foundation

// MARK: - howToSay

public protocol HowToSayUseCase: Sendable {
    /// Intent in ANY language → exactly 3 variants in the STUDIED language in `tone`, with notes in
    /// the NATIVE language. Also appended to history.
    func callAsFunction(_ intent: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant]
}

public extension HowToSayUseCase {
    func callAsFunction(_ intent: String) async throws -> [PhraseVariant] {
        try await callAsFunction(intent, tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian")
    }
    func callAsFunction(_ intent: String, tone: Register) async throws -> [PhraseVariant] {
        try await callAsFunction(intent, tone: tone, studiedLanguage: "English", nativeLanguage: "Russian")
    }
}

public struct HowToSayInteractor: HowToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository
    /// Reuses an earlier result for the SAME intent+tone+languages instead of re-asking the model. Nil
    /// disables caching (tests / back-compat).
    private let cache: (any TranslationCache)?
    /// Resolves the model tier for "Say it" generation at call time (reads the user's Settings choice).
    private let tier: @Sendable () -> ModelTier

    public init(llm: LLMClient, history: HistoryRepository, cache: (any TranslationCache)? = nil,
                tier: @escaping @Sendable () -> ModelTier = { .standard }) {
        self.llm = llm
        self.history = history
        self.cache = cache
        self.tier = tier
    }

    public func callAsFunction(_ intent: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant] {
        let key = TranslationCacheKey.make(kind: .howToSay, input: intent, tone: tone,
                                           studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage,
                                           tier: tier())
        // Cache hit → return the earlier result, no model call.
        if let cached = await cache?.value(forKey: key),
           let variants = try? JSONDecoder().decode([PhraseVariant].self, from: cached), !variants.isEmpty {
            return variants
        }
        let result = try await llm.run(
            HowToSayTemplate(tone: tone, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, tier: tier()), input: intent
        )
        // History logging is INTENTIONALLY best-effort: the user already has their result, so a failed
        // (or cancelled) append must never fail/cancel the request. `try?` is deliberate here and at
        // every `history.append` below. (Domain is Foundation-only, so the drop can't be logged here;
        // a corrupt READ is logged in the SwiftData repository.)
        try? await history.append(
            HistoryEntry(inputText: intent, result: .howToSay(result.variants))
        )
        if let data = try? JSONEncoder().encode(result.variants) { await cache?.setValue(data, forKey: key) }
        return result.variants
    }
}

// MARK: - regenerateHowToSay

public protocol RegenerateHowToSayUseCase: Sendable {
    /// A FRESH set of 3 STUDIED-language variants in `tone` from an ANY-language intent (appended to
    /// history; the prior set stays). Notes in the NATIVE language.
    func callAsFunction(_ intent: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant]
}

public extension RegenerateHowToSayUseCase {
    func callAsFunction(_ intent: String) async throws -> [PhraseVariant] {
        try await callAsFunction(intent, tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian")
    }
    func callAsFunction(_ intent: String, tone: Register) async throws -> [PhraseVariant] {
        try await callAsFunction(intent, tone: tone, studiedLanguage: "English", nativeLanguage: "Russian")
    }
}

public struct RegenerateHowToSayInteractor: RegenerateHowToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository
    /// Regenerate NEVER reads the cache (the user explicitly wants a fresh set), but it OVERWRITES it so
    /// re-entering the same intent later shows this latest set instead of re-asking the model.
    private let cache: (any TranslationCache)?
    /// Resolves the model tier for "Say it" generation at call time (reads the user's Settings choice).
    private let tier: @Sendable () -> ModelTier

    public init(llm: LLMClient, history: HistoryRepository, cache: (any TranslationCache)? = nil,
                tier: @escaping @Sendable () -> ModelTier = { .standard }) {
        self.llm = llm
        self.history = history
        self.cache = cache
        self.tier = tier
    }

    public func callAsFunction(_ intent: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant] {
        // Nudge the model toward different phrasings (a meta-instruction, kept in English so it
        // doesn't read as part of the user's intent); history records the original intent only.
        let nudged = intent + "\n\n(Offer different phrasings from the previous ones.)"
        let result = try await llm.run(
            HowToSayTemplate(tone: tone, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, tier: tier()), input: nudged
        )
        try? await history.append(
            HistoryEntry(inputText: intent, result: .howToSay(result.variants))
        )
        if let data = try? JSONEncoder().encode(result.variants) {
            let key = TranslationCacheKey.make(kind: .howToSay, input: intent, tone: tone,
                                               studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage,
                                               tier: tier())
            await cache?.setValue(data, forKey: key)
        }
        return result.variants
    }
}

// MARK: - whatToSay

public protocol WhatToSayUseCase: Sendable {
    /// A SITUATION description in ANY language → the 3–10 most useful phrases for it in the STUDIED
    /// language in `tone`, with notes in the NATIVE language. `regenerate` asks for a fresh/different
    /// set (the prior set stays in history). Appended to history.
    func callAsFunction(_ situation: String, tone: Register, studiedLanguage: String, nativeLanguage: String, regenerate: Bool) async throws -> [PhraseVariant]
}

public extension WhatToSayUseCase {
    func callAsFunction(_ situation: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant] {
        try await callAsFunction(situation, tone: tone, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, regenerate: false)
    }
    func callAsFunction(_ situation: String) async throws -> [PhraseVariant] {
        try await callAsFunction(situation, tone: .casual, studiedLanguage: "English", nativeLanguage: "Russian", regenerate: false)
    }
}

public struct WhatToSayInteractor: WhatToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository
    /// Reuses an earlier set for the SAME situation+tone+languages on the initial request; `regenerate`
    /// always skips the lookup (but still overwrites the cache with the fresh set). Nil disables caching.
    private let cache: (any TranslationCache)?
    /// Resolves the model tier for "Say it" generation at call time (reads the user's Settings choice).
    private let tier: @Sendable () -> ModelTier

    public init(llm: LLMClient, history: HistoryRepository, cache: (any TranslationCache)? = nil,
                tier: @escaping @Sendable () -> ModelTier = { .standard }) {
        self.llm = llm
        self.history = history
        self.cache = cache
        self.tier = tier
    }

    public func callAsFunction(_ situation: String, tone: Register, studiedLanguage: String, nativeLanguage: String, regenerate: Bool) async throws -> [PhraseVariant] {
        let key = TranslationCacheKey.make(kind: .whatToSay, input: situation, tone: tone,
                                           studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage,
                                           tier: tier())
        if !regenerate, let cached = await cache?.value(forKey: key),
           let variants = try? JSONDecoder().decode([PhraseVariant].self, from: cached), !variants.isEmpty {
            return variants
        }
        // On regenerate, nudge for a different set (kept in English so it doesn't read as part of the
        // situation). History records the situation as its own `.whatToSay` kind.
        let input = regenerate
            ? situation + "\n\n(Suggest a different or additional set of useful phrases for this situation.)"
            : situation
        let result = try await llm.run(
            WhatToSayTemplate(tone: tone, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, tier: tier()), input: input
        )
        try? await history.append(
            HistoryEntry(inputText: situation, result: .whatToSay(result.variants))
        )
        if let data = try? JSONEncoder().encode(result.variants) { await cache?.setValue(data, forKey: key) }
        return result.variants
    }
}

// MARK: - explainExpression ("Понять"/Get: explain nuance in the native language)

public protocol ExplainExpressionUseCase: Sendable {
    /// Render an ANY-language input in the STUDIED language and explain it in the NATIVE language:
    /// meaning, tone/register, cultural context, and a native-language analogy. An optional `image`
    /// (e.g. the photo a block came from) is attached as visual context; optional `alternatives` are
    /// sibling phrasings to CONTRAST this one against (per-variant "why this one?"). Not recorded in
    /// history — it's a reference lookup, not a produced phrase/translation.
    func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String, image: Data?, alternatives: [String]) async throws -> ExpressionExplanation
}

public extension ExplainExpressionUseCase {
    func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String, image: Data? = nil) async throws -> ExpressionExplanation {
        try await callAsFunction(text, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, image: image, alternatives: [])
    }
}

public struct ExplainExpressionInteractor: ExplainExpressionUseCase {
    private let llm: LLMClient
    /// Resolves the model tier for explanation at call time (reads the user's Settings choice). Default
    /// keeps the standard model (Sonnet); the App wires a live provider so the setting takes effect.
    private let tier: @Sendable () -> ModelTier
    public init(llm: LLMClient, tier: @escaping @Sendable () -> ModelTier = { .standard }) {
        self.llm = llm
        self.tier = tier
    }

    public func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String, image: Data?, alternatives: [String]) async throws -> ExpressionExplanation {
        try await llm.run(
            ExplainExpressionTemplate(studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, tier: tier()),
            input: ExplainInput(text: text, image: image, alternatives: alternatives)
        )
    }
}

// MARK: - understand ("Понять"/Get, Translate mode — faithful into studied + native)

public protocol UnderstandUseCase: Sendable {
    /// Faithfully translate an ANY-language input into BOTH the studied and the native language.
    /// Appends a history entry (the native rendering, mirroring the prior translate behavior).
    func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String) async throws -> Understanding
}

public struct UnderstandInteractor: UnderstandUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository
    /// Reuses an earlier translation of the SAME text+languages instead of re-asking the model. The
    /// FULL `Understanding` (all variants + context) is cached, unlike the lossy history entry. Nil
    /// disables caching.
    private let cache: (any TranslationCache)?
    /// Resolves the model tier for translation at call time (reads the user's Settings choice). Default
    /// keeps the fast model (Haiku); the App wires a live provider so the setting takes effect.
    private let tier: @Sendable () -> ModelTier

    public init(llm: LLMClient, history: HistoryRepository, cache: (any TranslationCache)? = nil,
                tier: @escaping @Sendable () -> ModelTier = { .fast }) {
        self.llm = llm
        self.history = history
        self.cache = cache
        self.tier = tier
    }

    public func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String) async throws -> Understanding {
        let key = TranslationCacheKey.make(kind: .translate, input: text, tone: nil,
                                           studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage,
                                           tier: tier())
        if let cached = await cache?.value(forKey: key),
           let understanding = try? JSONDecoder().decode(Understanding.self, from: cached), !understanding.variants.isEmpty {
            return understanding
        }
        let result = try await llm.run(
            UnderstandTemplate(studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage, tier: tier()), input: text
        )
        // History records the STUDIED rendering as the entry text (the learning artifact: what the
        // card headlines, what TTS speaks in the studied language, and what saving files as the
        // study-card front), with the native translation as the result. Falls back to the raw input.
        let studied = result.studied.isEmpty ? text : result.studied
        try? await history.append(HistoryEntry(inputText: studied, result: .translate(ru: result.variants.first?.text ?? "")))
        if let data = try? JSONEncoder().encode(result) { await cache?.setValue(data, forKey: key) }
        return result
    }
}

// MARK: - photoTranslate

public protocol PhotoTranslateUseCase: Sendable {
    /// Image → blocks (each detected in any language), rendered in the STUDIED language (`en`,
    /// headline + TTS) and the NATIVE language (`ru`). The LLM does recognition AND translation and
    /// decides the number of blocks. Also appends a history entry.
    func callAsFunction(_ image: RecognizableImage, studiedLanguage: String, nativeLanguage: String) async throws -> [TranslatedBlock]
}

public extension PhotoTranslateUseCase {
    func callAsFunction(_ image: RecognizableImage) async throws -> [TranslatedBlock] {
        try await callAsFunction(image, studiedLanguage: "English", nativeLanguage: "Russian")
    }
}

public struct PhotoTranslateInteractor: PhotoTranslateUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ image: RecognizableImage, studiedLanguage: String, nativeLanguage: String) async throws -> [TranslatedBlock] {
        let result = try await llm.run(
            PhotoBlocksTemplate(studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage), input: image
        )
        guard !result.blocks.isEmpty else { throw TextRecognitionError.noTextFound }
        let en = result.blocks.map(\.en).joined(separator: "\n\n")
        let ru = result.blocks.map(\.ru).joined(separator: "\n\n")
        try? await history.append(HistoryEntry(inputText: en, result: .photoTranslate(ru: ru)))
        return result.blocks
    }
}

// MARK: - photoExplain ("See it" / Explain — explain WHAT a photo shows in its local/cultural context)

public protocol PhotoExplainUseCase: Sendable {
    /// Image → an explanation of WHAT it shows and its local/cultural context (a place + its history, a
    /// sign + the local rule, …), written in the native language. Not recorded in history — a reference
    /// lookup, like text Explain.
    func callAsFunction(_ image: RecognizableImage, studiedLanguage: String, nativeLanguage: String) async throws -> SceneExplanation
}

public struct PhotoExplainInteractor: PhotoExplainUseCase {
    private let llm: LLMClient
    public init(llm: LLMClient) { self.llm = llm }

    public func callAsFunction(_ image: RecognizableImage, studiedLanguage: String, nativeLanguage: String) async throws -> SceneExplanation {
        try await llm.run(
            PhotoExplainTemplate(studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage), input: image
        )
    }
}

// MARK: - enrichCard

public protocol EnrichExpressionUseCase: Sendable {
    /// Enrich an expression with ru + example + synonyms for a study card.
    func callAsFunction(_ input: EnrichInput) async throws -> CardEnrichment
}

public struct EnrichExpressionInteractor: EnrichExpressionUseCase {
    private let llm: LLMClient
    public init(llm: LLMClient) { self.llm = llm }

    public func callAsFunction(_ input: EnrichInput) async throws -> CardEnrichment {
        try await llm.run(EnrichCardTemplate(), input: input)
    }
}
