//
//  PhraseVariant.swift
//  EnglishHelper — Domain
//

import Foundation

/// One way to say something in English, with its register and a short Russian context note.
/// Produced by the `howToSay` use case (exactly three per request).
public struct PhraseVariant: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: UUID
    /// The English phrasing.
    public let en: String
    /// formal / neutral / casual / slang.
    public let register: Register
    /// One-line Russian note on when to use this variant.
    public let contextRU: String

    public init(id: UUID = UUID(), en: String, register: Register, contextRU: String) {
        self.id = id
        self.en = en
        self.register = register
        self.contextRU = contextRU
    }

    // Decoded from the LLM JSON: { "en", "register", "context_ru" } — `id` is synthesized.
    private enum CodingKeys: String, CodingKey {
        case en, register
        case contextRU = "context_ru"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.en = try c.decode(String.self, forKey: .en)
        self.register = try c.decode(Register.self, forKey: .register)
        self.contextRU = try c.decode(String.self, forKey: .contextRU)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(en, forKey: .en)
        try c.encode(register, forKey: .register)
        try c.encode(contextRU, forKey: .contextRU)
    }
}
