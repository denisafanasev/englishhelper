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
}

/// Append + fetch of request history. Append-only by intent.
public protocol HistoryRepository: Sendable {
    func append(_ entry: HistoryEntry) async throws
    /// Most-recent-first, capped at `limit`.
    func recent(limit: Int) async throws -> [HistoryEntry]
}
