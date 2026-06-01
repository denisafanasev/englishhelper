//
//  DeckExporting.swift
//  EnglishHelper — Domain (port)
//

import Foundation

/// A shareable, format-agnostic deck file ready to hand to the system share sheet / an external app.
public struct ExportedDeck: Sendable, Equatable {
    public let filename: String
    public let data: Data
    /// UTI-style content-type string (e.g. "public.json"). Kept as `String` to avoid a
    /// `UniformTypeIdentifiers` dependency leaking into the Domain.
    public let contentType: String

    public init(filename: String, data: Data, contentType: String) {
        self.filename = filename
        self.data = data
        self.contentType = contentType
    }
}

/// Exports study-list items into a shareable deck file (e.g. for AlgoApp). Format-agnostic.
public protocol DeckExporting: Sendable {
    func export(_ expressions: [Expression]) async throws -> ExportedDeck
}
