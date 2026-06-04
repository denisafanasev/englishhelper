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

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ intent: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant] {
        let result = try await llm.run(
            HowToSayTemplate(tone: tone, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage), input: intent
        )
        try? await history.append(
            HistoryEntry(inputText: intent, result: .howToSay(result.variants))
        )
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

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ intent: String, tone: Register, studiedLanguage: String, nativeLanguage: String) async throws -> [PhraseVariant] {
        // Nudge the model toward different phrasings (a meta-instruction, kept in English so it
        // doesn't read as part of the user's intent); history records the original intent only.
        let nudged = intent + "\n\n(Offer different phrasings from the previous ones.)"
        let result = try await llm.run(
            HowToSayTemplate(tone: tone, studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage), input: nudged
        )
        try? await history.append(
            HistoryEntry(inputText: intent, result: .howToSay(result.variants))
        )
        return result.variants
    }
}

// MARK: - translateText

public protocol TranslateTextUseCase: Sendable {
    /// EN text → Russian translation (also appended to history).
    func callAsFunction(_ english: String) async throws -> String
}

public struct TranslateTextInteractor: TranslateTextUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ english: String) async throws -> String {
        let result = try await llm.run(TranslateTextTemplate(), input: english)
        try? await history.append(
            HistoryEntry(inputText: english, result: .translate(ru: result.ru))
        )
        return result.ru
    }
}

// MARK: - translateToTarget ("Понять"/In: understand OR compose, into target language)

public protocol TranslateToTargetUseCase: Sendable {
    /// Translate text into `targetLanguage` OR compose a phrase from an instruction — the model
    /// decides which. `tone` styles the composed phrase. Source auto-detected. Appends history.
    func callAsFunction(_ text: String, targetLanguage: String, tone: Register) async throws -> String
}

public extension TranslateToTargetUseCase {
    func callAsFunction(_ text: String, targetLanguage: String) async throws -> String {
        try await callAsFunction(text, targetLanguage: targetLanguage, tone: .casual)
    }
}

public struct TranslateToTargetInteractor: TranslateToTargetUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ text: String, targetLanguage: String, tone: Register) async throws -> String {
        let result = try await llm.run(
            TranslateToTargetTemplate(targetLanguage: targetLanguage, tone: tone), input: text
        )
        try? await history.append(HistoryEntry(inputText: text, result: .translate(ru: result.translation)))
        return result.translation
    }
}

// MARK: - explainExpression ("Понять"/Get: explain nuance in the native language)

public protocol ExplainExpressionUseCase: Sendable {
    /// Render an ANY-language input in the STUDIED language and explain it in the NATIVE language:
    /// meaning, tone/register, cultural context, and a native-language analogy. Not recorded in
    /// history — it's a reference lookup, not a produced phrase/translation.
    func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String) async throws -> ExpressionExplanation
}

public struct ExplainExpressionInteractor: ExplainExpressionUseCase {
    private let llm: LLMClient
    public init(llm: LLMClient) { self.llm = llm }

    public func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String) async throws -> ExpressionExplanation {
        try await llm.run(
            ExplainExpressionTemplate(studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage), input: text
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

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ text: String, studiedLanguage: String, nativeLanguage: String) async throws -> Understanding {
        let result = try await llm.run(
            UnderstandTemplate(studiedLanguage: studiedLanguage, nativeLanguage: nativeLanguage), input: text
        )
        // History records the STUDIED rendering as the entry text (the learning artifact: what the
        // card headlines, what TTS speaks in the studied language, and what saving files as the
        // study-card front), with the native translation as the result. Falls back to the raw input.
        let studied = result.studied.isEmpty ? text : result.studied
        try? await history.append(HistoryEntry(inputText: studied, result: .translate(ru: result.native)))
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
