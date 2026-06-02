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
    /// RU intent → exactly 3 variants in `tone` (also appended to history).
    func callAsFunction(_ russianIntent: String, tone: Register) async throws -> [PhraseVariant]
}

public extension HowToSayUseCase {
    func callAsFunction(_ russianIntent: String) async throws -> [PhraseVariant] {
        try await callAsFunction(russianIntent, tone: .casual)
    }
}

public struct HowToSayInteractor: HowToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ russianIntent: String, tone: Register) async throws -> [PhraseVariant] {
        let result = try await llm.run(HowToSayTemplate(tone: tone), input: russianIntent)
        try? await history.append(
            HistoryEntry(inputText: russianIntent, result: .howToSay(result.variants))
        )
        return result.variants
    }
}

// MARK: - regenerateHowToSay

public protocol RegenerateHowToSayUseCase: Sendable {
    /// A FRESH set of 3 variants in `tone` (also appended to history; prior set stays).
    func callAsFunction(_ russianIntent: String, tone: Register) async throws -> [PhraseVariant]
}

public extension RegenerateHowToSayUseCase {
    func callAsFunction(_ russianIntent: String) async throws -> [PhraseVariant] {
        try await callAsFunction(russianIntent, tone: .casual)
    }
}

public struct RegenerateHowToSayInteractor: RegenerateHowToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ russianIntent: String, tone: Register) async throws -> [PhraseVariant] {
        // Nudge the model toward different phrasings; history records the original intent only.
        let nudged = russianIntent + "\n\n(Предложи другие формулировки, отличные от прежних.)"
        let result = try await llm.run(HowToSayTemplate(tone: tone), input: nudged)
        try? await history.append(
            HistoryEntry(inputText: russianIntent, result: .howToSay(result.variants))
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

// MARK: - photoTranslate

public protocol PhotoTranslateUseCase: Sendable {
    /// Image → blocks of English text + Russian translation. The LLM does the recognition AND
    /// translation and decides the number of blocks. Also appends a history entry.
    func callAsFunction(_ image: RecognizableImage) async throws -> [TranslatedBlock]
}

public struct PhotoTranslateInteractor: PhotoTranslateUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ image: RecognizableImage) async throws -> [TranslatedBlock] {
        let result = try await llm.run(PhotoBlocksTemplate(), input: image)
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
