//
//  Pasteboard.swift
//  EnglishHelper — Presentation (support)
//
//  Read-only clipboard access for the paste-into-input affordance on the Get it screen. A protocol
//  (not UIPasteboard directly) so view-model tests can inject canned clipboard content.
//
//  PRIVACY: `hasText` is a metadata-only check — it never triggers the iOS paste banner or the
//  "Allow Paste" confirmation. `readText()` is the actual read; it's only ever called from the
//  user's explicit tap on the Paste button, so the system prompt (when iOS shows one) matches a
//  deliberate user action.
//

import UIKit

public protocol PasteboardReading: Sendable {
    /// Whether the clipboard currently holds any text (metadata check, no paste notification).
    @MainActor var hasText: Bool { get }
    /// The clipboard text (may present the system paste confirmation).
    @MainActor func readText() -> String?
}

@MainActor
public struct SystemPasteboard: PasteboardReading {
    public init() {}
    public var hasText: Bool { UIPasteboard.general.hasStrings }
    public func readText() -> String? { UIPasteboard.general.string }
}
