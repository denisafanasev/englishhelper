//
//  ExporterTests.swift
//  EnglishHelperTests
//
//  AlgoAppXMLExporter must produce well-formed XML and escape special characters in every field.
//

import Testing
import Foundation
import Domain
import Adapters

@Suite struct ExporterTests {

    private func sample() -> [Domain.Expression] {
        [
            Domain.Expression(en: "Tom & Jerry", ru: "<Том> & \"Джерри\"",
                              example: "He said 'hi' & left", synonyms: ["duo", "pair"]),
            Domain.Expression(en: "I appreciate it", ru: "Я ценю это",
                              example: "Thanks — I appreciate it.", synonyms: []),
        ]
    }

    @Test func outputIsWellFormedXML() async throws {
        let deck = try await AlgoAppXMLExporter().export(sample())
        #expect(XMLParser(data: deck.data).parse(), "exported deck must parse as XML")
        #expect(deck.filename.hasSuffix(".xml"))
    }

    @Test func specialCharactersAreEscapedInEveryField() async throws {
        let deck = try await AlgoAppXMLExporter().export(sample())
        let xml = String(data: deck.data, encoding: .utf8)!

        // No raw special chars survive inside field content.
        #expect(xml.contains("&amp;"))
        #expect(xml.contains("&lt;"))
        #expect(xml.contains("&gt;"))
        #expect(!xml.contains("Tom & Jerry"))   // the raw ampersand must be escaped
        #expect(!xml.contains("<Том>"))         // the raw angle brackets must be escaped
    }

    @Test func recognitionMappingPutsEnglishOnFront() async throws {
        let deck = try await AlgoAppXMLExporter(mapping: .recognition).export(sample())
        let xml = String(data: deck.data, encoding: .utf8)!
        #expect(xml.contains("<field name=\"Front\">I appreciate it</field>"))
    }

    @Test func emptyListThrows() async {
        await #expect(throws: ExportError.self) {
            _ = try await AlgoAppXMLExporter().export([])
        }
    }
}
