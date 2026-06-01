//
//  LibraryUseCases.swift
//  EnglishHelper — Domain (use cases)
//
//  Study-list, history-read, and export orchestration over the repository / exporter ports.
//

import Foundation

// MARK: - Study list

public protocol StudyListUseCase: Sendable {
    func list() async throws -> [Expression]
    func add(_ expression: Expression) async throws
    func update(_ expression: Expression) async throws
    func delete(id: Expression.ID) async throws
    func setLearned(_ learned: Bool, id: Expression.ID) async throws
}

public struct StudyListInteractor: StudyListUseCase {
    private let repository: ExpressionRepository
    public init(repository: ExpressionRepository) { self.repository = repository }

    public func list() async throws -> [Expression] { try await repository.all() }
    public func add(_ expression: Expression) async throws { try await repository.add(expression) }
    public func update(_ expression: Expression) async throws { try await repository.update(expression) }
    public func delete(id: Expression.ID) async throws { try await repository.delete(id: id) }
    public func setLearned(_ learned: Bool, id: Expression.ID) async throws {
        try await repository.setLearned(learned, id: id)
    }
}

// MARK: - History (read)

public protocol RequestHistoryUseCase: Sendable {
    func recent(limit: Int) async throws -> [HistoryEntry]
}

public struct RequestHistoryInteractor: RequestHistoryUseCase {
    private let history: HistoryRepository
    public init(history: HistoryRepository) { self.history = history }
    public func recent(limit: Int) async throws -> [HistoryEntry] {
        try await history.recent(limit: limit)
    }
}

// MARK: - Export deck

public protocol ExportDeckUseCase: Sendable {
    /// Export the whole study list as a shareable deck file.
    func callAsFunction() async throws -> ExportedDeck
}

public struct ExportDeckInteractor: ExportDeckUseCase {
    private let repository: ExpressionRepository
    private let exporter: DeckExporting

    public init(repository: ExpressionRepository, exporter: DeckExporting) {
        self.repository = repository
        self.exporter = exporter
    }

    public func callAsFunction() async throws -> ExportedDeck {
        let expressions = try await repository.all()
        guard !expressions.isEmpty else { throw ExportError.nothingToExport }
        return try await exporter.export(expressions)
    }
}
