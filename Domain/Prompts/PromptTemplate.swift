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

    /// Decode the model's raw JSON response text into the typed `Output`.
    /// Throws `LLMError.invalidOutput` if the response violates the schema.
    func decode(_ rawJSON: String) throws -> Output
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
