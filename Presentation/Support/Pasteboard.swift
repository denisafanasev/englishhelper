//
//  Pasteboard.swift
//  EnglishHelper — Presentation (support)
//
//  Clipboard METADATA for arming the paste-into-input affordance. A protocol (not UIPasteboard
//  directly) so view-model tests can inject canned clipboard state.
//
//  PRIVACY: `hasText` is a metadata-only check — it never triggers the iOS paste banner or the
//  "Allow Paste" confirmation. The CONTENT is never read here: the actual paste goes through the
//  system UIPasteControl (`EHPasteButton`), whose tap is itself the user's pasteboard consent —
//  so the "Allow Paste?" dialog is never shown at all.
//

import UIKit

public protocol PasteboardReading: Sendable {
    /// Whether the clipboard currently holds any text (metadata check, no paste notification).
    @MainActor var hasText: Bool { get }
}

@MainActor
public struct SystemPasteboard: PasteboardReading {
    public init() {}
    public var hasText: Bool { UIPasteboard.general.hasStrings }
}
