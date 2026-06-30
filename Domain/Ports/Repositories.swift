//
//  Repositories.swift
//  EnglishHelper — Domain (ports)
//

import Foundation

/// CRUD for the curated study list. Concrete impl is SwiftData-backed (Data layer).
public protocol ExpressionRepository: Sendable {
    func all() async throws -> [Expression]
    func add(_ expression: Expression) async throws
    func update(_ expression: Expression) async throws
    func delete(id: Expression.ID) async throws
    /// Toggle the staging "learned" flag.
    func setLearned(_ learned: Bool, id: Expression.ID) async throws
    /// First existing expression whose `en` matches (case-insensitive, trimmed), or nil. Drives
    /// content-level de-duplication so the same phrase isn't stored twice.
    func find(en: String) async throws -> Expression?
}

public extension ExpressionRepository {
    /// Normalized key for content-level matching of an expression's `en`.
    static func normalizedKey(_ en: String) -> String {
        en.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Append + fetch of request history. Append-only by intent.
public protocol HistoryRepository: Sendable {
    func append(_ entry: HistoryEntry) async throws
    /// Most-recent-first, capped at `limit`.
    func recent(limit: Int) async throws -> [HistoryEntry]
}

/// A persistent cache of completed TEXT-translation requests (Say it · How to say / What to say, and
/// Get it · Translate), so the exact same input isn't sent to the model twice — a repeat shows the
/// earlier result instantly. Keyed by `TranslationCacheKey` (kind + text + tone + languages) and stores
/// the typed result as JSON `Data`. Both sides are best-effort: a miss (or any error) just runs the
/// request. Distinct from `HistoryRepository`, which is a lossy, display-shaped log.
public protocol TranslationCache: Sendable {
    /// The cached result bytes for `key`, or nil on a miss. A non-nil return counts as a hit.
    func value(forKey key: String) async -> Data?
    /// Persist `value` under `key` (upsert — the newest result for a key wins).
    func setValue(_ value: Data, forKey key: String) async
    /// Current entry count + the running total of hits (reads served from the cache).
    func statistics() async -> TranslationCacheStats
    /// Empty the cache and reset the hit counter.
    func clear() async
}

/// Cache usage shown in Settings.
public struct TranslationCacheStats: Sendable, Equatable {
    /// How many results are currently stored.
    public let entryCount: Int
    /// How many times a request was served from the cache instead of the model.
    public let hitCount: Int
    public init(entryCount: Int, hitCount: Int) {
        self.entryCount = entryCount
        self.hitCount = hitCount
    }
}

/// Builds the cache key for a text-translation request. Inputs that change the result must all be in
/// the key: the scenario `kind`, the (trimmed) input text, the `tone`/register (Say it only; nil for
/// Translate), and both languages. Case is preserved — case can change meaning ("polish"/"Polish").
public enum TranslationCacheKey {
    public static func make(kind: RequestKind, input: String, tone: Register?,
                            studiedLanguage: String, nativeLanguage: String) -> String {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let toneKey = tone?.rawValue ?? "-"
        // \u{1} (a control char) can't appear in user text, so fields can't collide.
        return [kind.rawValue, studiedLanguage, nativeLanguage, toneKey, normalized].joined(separator: "\u{1}")
    }
}
