//
//  MockDeckExporting.swift
//  EnglishHelper — Data (mock adapter)
//
//  Serializes the study list to JSON. The real exporter (deck format for AlgoApp) lands in v1.
//

import Foundation
import Domain

public final class MockDeckExporting: DeckExporting {
    public init() {}

    // `Domain.Expression` is qualified to avoid ambiguity with Foundation.Expression (Predicate).
    public func export(_ expressions: [Domain.Expression]) async throws -> ExportedDeck {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(expressions)
            return ExportedDeck(filename: "englishhelper-deck.json", data: data, contentType: "public.json")
        } catch {
            throw ExportError.encodingFailed(String(describing: error))
        }
    }
}
