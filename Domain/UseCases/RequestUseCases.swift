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
    /// RU intent → exactly 3 register-tagged variants (also appended to history).
    func callAsFunction(_ russianIntent: String) async throws -> [PhraseVariant]
}

public struct HowToSayInteractor: HowToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ russianIntent: String) async throws -> [PhraseVariant] {
        let result = try await llm.run(HowToSayTemplate(), input: russianIntent)
        try? await history.append(
            HistoryEntry(inputText: russianIntent, result: .howToSay(result.variants))
        )
        return result.variants
    }
}

// MARK: - regenerateHowToSay

public protocol RegenerateHowToSayUseCase: Sendable {
    /// A FRESH set of 3 variants for the same intent (also appended to history; prior set stays).
    func callAsFunction(_ russianIntent: String) async throws -> [PhraseVariant]
}

public struct RegenerateHowToSayInteractor: RegenerateHowToSayUseCase {
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(llm: LLMClient, history: HistoryRepository) {
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ russianIntent: String) async throws -> [PhraseVariant] {
        // Nudge the model toward different phrasings; history records the original intent only.
        let nudged = russianIntent + "\n\n(Предложи другие формулировки, отличные от прежних.)"
        let result = try await llm.run(HowToSayTemplate(), input: nudged)
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

/// OCR result + its translation. `blocks` carry the boxes the overlay draws.
public struct PhotoTranslation: Sendable, Equatable {
    public let recognizedText: String
    public let blocks: [RecognizedTextBlock]
    public let ru: String
}

public protocol PhotoTranslateUseCase: Sendable {
    /// Image → OCR'd English (+ boxes) → Russian translation (also appended to history).
    func callAsFunction(_ image: RecognizableImage) async throws -> PhotoTranslation
}

public struct PhotoTranslateInteractor: PhotoTranslateUseCase {
    private let ocr: TextRecognizing
    private let llm: LLMClient
    private let history: HistoryRepository

    public init(ocr: TextRecognizing, llm: LLMClient, history: HistoryRepository) {
        self.ocr = ocr
        self.llm = llm
        self.history = history
    }

    public func callAsFunction(_ image: RecognizableImage) async throws -> PhotoTranslation {
        let recognized = try await ocr.recognizeText(in: image)
        guard !recognized.isEmpty else { throw TextRecognitionError.noTextFound }
        let result = try await llm.run(PhotoTranslateTemplate(), input: recognized.fullText)
        try? await history.append(
            HistoryEntry(inputText: recognized.fullText, result: .photoTranslate(ru: result.ru))
        )
        return PhotoTranslation(recognizedText: recognized.fullText, blocks: recognized.blocks, ru: result.ru)
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
