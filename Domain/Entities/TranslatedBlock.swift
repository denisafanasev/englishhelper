//
//  TranslatedBlock.swift
//  EnglishHelper — Domain
//

import Foundation

/// One block of connected English text recognized from a photo, with its Russian translation.
/// The LLM decides how many blocks a photo yields.
public struct TranslatedBlock: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: UUID
    public let en: String
    public let ru: String

    public init(id: UUID = UUID(), en: String, ru: String) {
        self.id = id
        self.en = en
        self.ru = ru
    }

    // Decoded from the LLM JSON `{ "en", "ru" }` — `id` is synthesized.
    private enum CodingKeys: String, CodingKey { case en, ru }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.en = try c.decode(String.self, forKey: .en)
        self.ru = try c.decode(String.self, forKey: .ru)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(en, forKey: .en)
        try c.encode(ru, forKey: .ru)
    }

    // Equality/identity are CONTENT-based: `id` is freshly synthesized on every decode, so including
    // it would make an encode→decode round-trip non-equal (defeating diffing/dedup). `id` still serves
    // Identifiable for SwiftUI list identity within a session.
    public static func == (lhs: TranslatedBlock, rhs: TranslatedBlock) -> Bool {
        lhs.en == rhs.en && lhs.ru == rhs.ru
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(en); hasher.combine(ru)
    }
}
