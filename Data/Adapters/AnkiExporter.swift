//
//  AnkiExporter.swift
//  EnglishHelper — Data (adapter for DeckExporting)
//
//  Exports the study list as an Anki-importable tab-separated text file. Front = English, Back =
//  ru + example + synonyms (HTML <br> line breaks). The `#separator`/`#html` headers let modern
//  Anki (2.1.55+) auto-configure the import. Export format lives ONLY here — like AlgoAppXMLExporter,
//  behind the DeckExporting port.
//

import Foundation
import Domain

public final class AnkiExporter: DeckExporting {
    private let deckName: String
    public init(deckName: String = "EnglishHelper") { self.deckName = deckName }

    public func export(_ expressions: [Domain.Expression]) async throws -> ExportedDeck {
        guard !expressions.isEmpty else { throw ExportError.nothingToExport }

        var lines = [
            "#separator:tab",
            "#html:true",
            "#deck:\(field(deckName))",
            "#columns:Front\tBack",
        ]
        for e in expressions {
            let front = ankiSafeLeadingHash(field(e.en))
            let backParts = [e.ru, e.example, e.synonyms.joined(separator: ", ")]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let back = field(backParts.joined(separator: "<br>"))
            lines.append("\(front)\t\(back)")
        }

        let data = Data(lines.joined(separator: "\n").utf8)
        return ExportedDeck(filename: "EnglishHelper-Anki.txt", data: data, contentType: "public.plain-text")
    }

    /// Tabs and newlines delimit rows/fields, so neutralize them inside a value.
    private func field(_ s: String) -> String {
        s.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    /// Anki treats any import line that STARTS with '#' as a directive/comment and silently drops it,
    /// so a card whose front begins with '#' ("#1 priority", "#blessed") would vanish. With `#html:true`
    /// already set, encoding the leading '#' as the numeric entity renders identically ('#') while the
    /// line no longer begins with a literal '#'. Only the first character matters for the line check.
    private func ankiSafeLeadingHash(_ s: String) -> String {
        guard s.first == "#" else { return s }
        return "&#35;" + s.dropFirst()
    }
}
