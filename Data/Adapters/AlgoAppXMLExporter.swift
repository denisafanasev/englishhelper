//
//  AlgoAppXMLExporter.swift
//  EnglishHelper — Data (adapter for DeckExporting)
//
//  Renders the study list into an AlgoApp .xml deck. Card content is built DETERMINISTICALLY from
//  stored fields (NOT the LLM) as exactly four plain-text lines. Export format lives ONLY here —
//  screens / repositories / LLM stay unaware; a CSV/APKG exporter could be added without touching them.
//
//  `XMLDocument` is macOS-only, so we serialize through a dedicated escaping writer (every field
//  value is XML-escaped — never raw concatenation) and validate the result with `XMLParser`.
//

import Foundation
import Domain

public final class AlgoAppXMLExporter: DeckExporting {

    /// Which face the recognition/production mapping puts on Front.
    public enum Mapping: Sendable {
        case recognition   // Front = en, Back = ru/example/synonyms  (default)
        case production    // Front = ru, Back = en/example/synonyms
    }

    private let mapping: Mapping
    private let deckName: String

    // Flipping recognition→production is this ONE default change (see README).
    public init(mapping: Mapping = .recognition, deckName: String = "EnglishHelper Export") {
        self.mapping = mapping
        self.deckName = deckName
    }

    public func export(_ expressions: [Domain.Expression]) async throws -> ExportedDeck {
        guard !expressions.isEmpty else { throw ExportError.nothingToExport }

        var writer = XMLWriter()
        writer.open("deck", attributes: ["name": deckName])
        writer.open("cards")
        for expression in expressions {
            let (front, back) = faces(for: expression)
            writer.open("card")
            writer.leaf("field", attributes: ["name": "Front"], text: front)
            writer.leaf("field", attributes: ["name": "Back"], text: back)
            writer.close("card")
        }
        writer.close("cards")
        writer.close("deck")

        let data = writer.data()
        guard Self.isWellFormed(data) else {
            throw ExportError.encodingFailed("produced XML failed validation")
        }
        return ExportedDeck(filename: "EnglishHelper-Export.xml", data: data, contentType: "public.xml")
    }

    /// Exactly four plain-text lines from stored fields.
    static func cardLines(for e: Domain.Expression) -> [String] {
        [e.en, e.ru, e.example, e.synonyms.joined(separator: " / ")]
    }

    private func faces(for e: Domain.Expression) -> (front: String, back: String) {
        let l = Self.cardLines(for: e)   // [en, ru, example, synonyms]
        switch mapping {
        case .recognition: return (l[0], [l[1], l[2], l[3]].joined(separator: "\n"))
        case .production:  return (l[1], [l[0], l[2], l[3]].joined(separator: "\n"))
        }
    }

    private static func isWellFormed(_ data: Data) -> Bool {
        XMLParser(data: data).parse()
    }
}

/// Minimal, correct XML serializer: every text/attribute value is escaped. Not string concatenation
/// of raw values.
struct XMLWriter {
    private var out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

    mutating func open(_ name: String, attributes: [String: String] = [:]) {
        out += "<\(name)\(attrs(attributes))>\n"
    }
    mutating func close(_ name: String) { out += "</\(name)>\n" }

    mutating func leaf(_ name: String, attributes: [String: String] = [:], text: String) {
        out += "<\(name)\(attrs(attributes))>\(Self.escape(text))</\(name)>\n"
    }

    func data() -> Data { Data(out.utf8) }

    private func attrs(_ a: [String: String]) -> String {
        a.sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\(Self.escape($0.value))\"" }
            .joined()
    }

    /// Escapes &, <, >, ", ' in every value.
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
