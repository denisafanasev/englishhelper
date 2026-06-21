//
//  SharedInbox.swift
//  EnglishHelper — Shared (compiled into BOTH the app and the Share Extension)
//
//  The hand-off channel for the iOS Share sheet: the Share Extension WRITES the shared item to the
//  App Group container, then launches the app; the app CONSUMES it once and routes it to a scenario.
//  Foundation-only and self-contained (no app/extension imports) so the extension stays minimal.
//

import Foundation

/// One shared item handed from the Share Extension to the app.
public enum SharedPayload: Equatable, Sendable {
    case text(String)
    case image(Data)
}

public enum SharedInbox {
    /// Must match `com.apple.security.application-groups` in BOTH targets' entitlements.
    public static let appGroupID = "group.tech.10xt.englishhelper"

    private static let manifestName = "inbox.json"
    private static let imageName = "inbox.img"

    private struct Manifest: Codable {
        let kind: String        // "text" | "image"
        let text: String?
        let createdAt: TimeInterval
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Write the shared item, replacing any previous one (last share wins).
    @discardableResult
    public static func write(_ payload: SharedPayload, now: TimeInterval) -> Bool {
        guard let dir = containerURL else { return false }
        return write(payload, now: now, in: dir)
    }

    /// Read AND remove the pending item (single-consume), so a payload routes exactly once.
    public static func consume() -> SharedPayload? {
        guard let dir = containerURL else { return nil }
        return consume(in: dir)
    }

    // MARK: Directory-injectable core (unit-testable without the App Group entitlement)

    @discardableResult
    static func write(_ payload: SharedPayload, now: TimeInterval, in dir: URL) -> Bool {
        let manifestURL = dir.appendingPathComponent(manifestName)
        let imageURL = dir.appendingPathComponent(imageName)
        try? FileManager.default.removeItem(at: imageURL)
        do {
            let manifest: Manifest
            switch payload {
            case .text(let text):
                manifest = Manifest(kind: "text", text: text, createdAt: now)
            case .image(let data):
                try data.write(to: imageURL, options: .atomic)
                manifest = Manifest(kind: "image", text: nil, createdAt: now)
            }
            try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func consume(in dir: URL) -> SharedPayload? {
        let manifestURL = dir.appendingPathComponent(manifestName)
        let imageURL = dir.appendingPathComponent(imageName)
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }

        let result: SharedPayload?
        switch manifest.kind {
        case "text":
            result = manifest.text.map(SharedPayload.text)
        case "image":
            result = (try? Data(contentsOf: imageURL)).map(SharedPayload.image)
        default:
            result = nil
        }
        // Always clear, even on a malformed manifest, so a bad item can't wedge the inbox.
        try? FileManager.default.removeItem(at: manifestURL)
        try? FileManager.default.removeItem(at: imageURL)
        return result
    }
}
