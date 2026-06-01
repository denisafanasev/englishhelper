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
}
