//
//  PromptTemplate.swift
//  EnglishHelper — Domain
//
//  A prompt template is a DOMAIN concept, not a string buried in the LLM adapter.
//  Each use case owns its own system prompt + strict output schema + typed decoder.
//  Adding a 4th use case = adding a `PromptTemplate`, WITHOUT touching the LLM adapter.
//

import Foundation

/// A typed, self-describing LLM instruction: system prompt + output schema + decoder.
public protocol PromptTemplate<Input, Output>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    /// Stable identifier (also used by mocks/telemetry), e.g. "howToSay".
    var id: String { get }

    /// The system prompt that pins the model's behavior and output contract.
    var systemPrompt: String { get }

    /// JSON schema (as text) the model output MUST satisfy. Used to force structured output.
    var outputJSONSchema: String { get }

    /// Render the user-turn message from typed input.
    func userMessage(for input: Input) -> String

    /// Optional image to attach to the user turn (for multimodal templates). Default: none.
    func image(for input: Input) -> Data?

    /// Decode the model's raw JSON response text into the typed `Output`.
    /// Throws `LLMError.invalidOutput` if the response violates the schema.
    func decode(_ rawJSON: String) throws -> Output
}

public extension PromptTemplate {
    func image(for input: Input) -> Data? { nil }

    /// Output token budget for THIS template. Short tasks (a few phrasings, one translation, an
    /// explanation) need little; the photo translator can emit many text blocks and needs far more.
    /// The LLM adapter caps the response at this value — too low truncates the JSON mid-stream, which
    /// the adapter surfaces as `LLMError.responseTooLong`. Default suits the short text tasks.
    var maxOutputTokens: Int { 2048 }

    /// True for short, latency-sensitive TEXT tasks (phrasings, translation, explanation): lets the
    /// adapter pick faster model settings (low effort, no extended reasoning) to optimize response
    /// speed. Vision / long-output templates set this false to trade a little latency for accuracy
    /// and headroom. This is a backend-agnostic HINT — the LLM adapter maps it to provider params.
    var prefersFastResponse: Bool { true }
}

public extension PromptTemplate {
    /// Convenience for adapters/mocks: decode from `Decodable` JSON with a shared decoder.
    func decodeJSON<T: Decodable>(_ type: T.Type, from rawJSON: String) throws -> T {
        guard let data = rawJSON.data(using: .utf8) else {
            throw LLMError.invalidOutput("response was not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LLMError.invalidOutput("schema mismatch for \(id): \(error)")
        }
    }
}
