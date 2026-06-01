//
//  LLMClient.swift
//  EnglishHelper — Domain (port)
//

import Foundation

/// Executes a `PromptTemplate` against an LLM and returns its typed, structured result.
///
/// The client is template-agnostic: it knows how to run *any* template, so new use cases
/// never require changes here. Concrete impl (ClaudeLLMClient) lives in Data.
public protocol LLMClient: Sendable {
    /// Run `template` with `input`, returning the decoded `Output`.
    /// Throws `LLMError` on configuration, transport, cancellation, or schema failure.
    func run<Template: PromptTemplate>(
        _ template: Template,
        input: Template.Input
    ) async throws -> Template.Output
}
