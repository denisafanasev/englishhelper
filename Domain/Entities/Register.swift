//
//  Register.swift
//  EnglishHelper — Domain
//
//  Pure Domain. Foundation only (value types). No platform/UI frameworks.
//

import Foundation

/// Politeness / formality register of an English phrase variant.
///
/// NOTE: the `howToSay` output schema enumerates four levels (formal/neutral/casual/slang),
/// so the Domain models all four. The DesignSystem, however, only styles THREE register tags
/// (formal/casual/slang) — `neutral` has no distinct visual token and is presented as `casual`.
/// See `DesignSystem/Tokens.swift` (Register flag) and `RegisterTagView`.
public enum Register: String, Codable, Sendable, CaseIterable, Hashable {
    case formal
    case neutral
    case casual
    case slang

    /// Tolerant decode: the LLM is non-deterministic, so `register` can arrive capitalized
    /// ("Formal"), as a synonym ("informal", "polite"), or localized despite the schema's enum
    /// constraint. Normalize and map known synonyms; fall back to `.neutral` for anything unknown
    /// rather than throwing — one off-schema tag must not discard the whole (otherwise valid) batch.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch raw {
        case "formal", "polite": self = .formal
        case "neutral", "standard", "default": self = .neutral
        case "casual", "informal", "colloquial", "conversational": self = .casual
        case "slang", "vulgar", "street": self = .slang
        default: self = Register(rawValue: raw) ?? .neutral
        }
    }
}
