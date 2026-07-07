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

// MARK: - Save (create with enrichment)

public protocol SaveExpressionUseCase: Sendable {
    /// Expression CREATE from ANY flow: enrich (ru/example/synonyms) FIRST, then store.
    /// Returns the stored, enriched expression.
    func callAsFunction(en: String, knownRU: String?, context: String) async throws -> Expression
}

public struct SaveExpressionInteractor: SaveExpressionUseCase {
    private let enrich: EnrichExpressionUseCase
    private let repository: ExpressionRepository
    /// Optional product analytics (nil = disabled, e.g. tests / mock boot). Events carry NO user content.
    private let analytics: (any AnalyticsTracking)?

    public init(enrich: EnrichExpressionUseCase, repository: ExpressionRepository,
                analytics: (any AnalyticsTracking)? = nil) {
        self.enrich = enrich
        self.repository = repository
        self.analytics = analytics
    }

    public func callAsFunction(en: String, knownRU: String? = nil, context: String = "") async throws -> Expression {
        // Content-level de-dup FIRST: if this phrase is already saved, return it instead of inserting a
        // duplicate study row (which would also become a duplicate exported card). Doing it before
        // enrich also avoids a wasted paid LLM call.
        if let existing = try await repository.find(en: en) { return existing }
        let enrichment = try await enrich(EnrichInput(en: en, ru: knownRU))
        let expression = Expression(
            en: en,
            ru: enrichment.ru.isEmpty ? (knownRU ?? "") : enrichment.ru,
            example: enrichment.example,
            synonyms: enrichment.synonyms,
            context: context
        )
        try await repository.add(expression)
        analytics?.track(.expressionSaved)   // counts NEW cards only — the de-dup return above doesn't
        return expression
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

// MARK: - Translation cache admin (Settings: stats + clear)

public protocol TranslationCacheAdminUseCase: Sendable {
    func stats() async -> TranslationCacheStats
    func clear() async
}

public struct TranslationCacheAdminInteractor: TranslationCacheAdminUseCase {
    /// Optional so the app still builds without a cache (mock boot / tests) — then stats are zero and
    /// clear is a no-op.
    private let cache: (any TranslationCache)?
    public init(cache: (any TranslationCache)?) { self.cache = cache }

    public func stats() async -> TranslationCacheStats {
        await cache?.statistics() ?? TranslationCacheStats(entryCount: 0, hitCount: 0)
    }
    public func clear() async { await cache?.clear() }
}

// MARK: - Export deck

public protocol ExportDeckUseCase: Sendable {
    /// Export the whole study list as a shareable deck file.
    func callAsFunction() async throws -> ExportedDeck
}

public struct ExportDeckInteractor: ExportDeckUseCase {
    private let repository: ExpressionRepository
    private let exporter: DeckExporting
    /// Optional product analytics (nil = disabled, e.g. tests / mock boot). Events carry NO user content.
    private let analytics: (any AnalyticsTracking)?

    public init(repository: ExpressionRepository, exporter: DeckExporting,
                analytics: (any AnalyticsTracking)? = nil) {
        self.repository = repository
        self.exporter = exporter
        self.analytics = analytics
    }

    public func callAsFunction() async throws -> ExportedDeck {
        let expressions = try await repository.all()
        guard !expressions.isEmpty else { throw ExportError.nothingToExport }
        let deck = try await exporter.export(expressions)
        analytics?.track(.deckExported)
        return deck
    }
}
