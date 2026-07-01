//
//  SwiftDataRepositories.swift
//  EnglishHelper — Data (SwiftData adapters)
//
//  @ModelActor isolates each repository's ModelContext to its own actor, so persistence runs off
//  the main thread and is Sendable-safe under Swift 6.
//

import Foundation
import SwiftData
import OSLog
import Domain

private let persistenceLog = Logger(subsystem: "tech.10xt.englishhelper", category: "persistence")

@ModelActor
public actor SwiftDataExpressionRepository: ExpressionRepository {
    public func all() async throws -> [Domain.Expression] {
        let descriptor = FetchDescriptor<ExpressionModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func add(_ expression: Domain.Expression) async throws {
        modelContext.insert(ExpressionModel(expression))
        try save()
    }

    public func update(_ expression: Domain.Expression) async throws {
        guard let model = try fetchModel(id: expression.id) else { throw RepositoryError.notFound }
        model.apply(expression)
        try save()
    }

    public func delete(id: Domain.Expression.ID) async throws {
        guard let model = try fetchModel(id: id) else { return }
        modelContext.delete(model)
        try save()
    }

    public func setLearned(_ learned: Bool, id: Domain.Expression.ID) async throws {
        guard let model = try fetchModel(id: id) else { throw RepositoryError.notFound }
        model.learned = learned
        try save()
    }

    public func find(en: String) async throws -> Domain.Expression? {
        // Case-insensitive/trimmed match in memory: the study list is small (single user) and
        // SwiftData #Predicate can't express the same normalization reliably.
        let key = SwiftDataExpressionRepository.normalizedKey(en)
        let descriptor = FetchDescriptor<ExpressionModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]   // oldest first → return the original
        )
        return try modelContext.fetch(descriptor)
            .first { SwiftDataExpressionRepository.normalizedKey($0.en) == key }?
            .toDomain()
    }

    private func fetchModel(id: UUID) throws -> ExpressionModel? {
        var descriptor = FetchDescriptor<ExpressionModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func save() throws {
        do { try modelContext.save() }
        catch { throw RepositoryError.persistenceFailed(error.localizedDescription) }
    }
}

@ModelActor
public actor SwiftDataHistoryRepository: HistoryRepository {
    /// Keep only the newest N requests so history doesn't grow without bound. MUST be ≥ the History
    /// screen's read limit (`HistoryViewModel.limit`, 200), otherwise the screen can never show its
    /// requested capacity because the store prunes below it.
    public static let maxEntries = 200

    public func append(_ entry: HistoryEntry) async throws {
        modelContext.insert(try HistoryModel(entry))
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
        // The entry is already persisted, so pruning is best-effort: a prune failure must NOT report
        // the append itself as failed (the caller would think nothing was saved when it actually was).
        try? pruneBeyondLimit()
    }

    /// Delete everything older than the newest `maxEntries` entries.
    private func pruneBeyondLimit() throws {
        var descriptor = FetchDescriptor<HistoryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = Self.maxEntries
        let stale = try modelContext.fetch(descriptor)
        guard !stale.isEmpty else { return }
        for model in stale { modelContext.delete(model) }
        try modelContext.save()
    }

    public func recent(limit: Int) async throws -> [HistoryEntry] {
        var descriptor = FetchDescriptor<HistoryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).compactMap { model in
            do {
                return try model.toDomain()
            } catch {
                // Don't silently vanish a corrupt row: log it (with the persisted `kindRaw`, which is
                // otherwise unused) so a decode regression is diagnosable instead of invisible.
                persistenceLog.error("Dropping undecodable history row kind=\(model.kindRaw, privacy: .public): \(String(describing: error), privacy: .public)")
                return nil
            }
        }
    }
}

/// Persistent cache of completed text translations (`TranslationCache`). Keyed by the opaque
/// `TranslationCacheKey` string; value is the JSON of the scenario's typed result. Read/write are
/// best-effort — a miss or any error just lets the request hit the model.
@ModelActor
public actor SwiftDataTranslationCache: TranslationCache {
    /// Cap so the cache can't grow without bound; oldest entries are pruned past this.
    public static let maxEntries = 500
    /// Running total of cache hits (reads served from the cache), persisted in UserDefaults so it
    /// survives relaunches and can be shown in Settings.
    private static let hitsKey = "tech.10xt.englishhelper.translationCacheHits"

    public func value(forKey key: String) async -> Data? {
        var descriptor = FetchDescriptor<CachedTranslationModel>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        guard let value = try? modelContext.fetch(descriptor).first?.value else { return nil }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: Self.hitsKey) + 1, forKey: Self.hitsKey)   // count the hit
        return value
    }

    public func statistics() async -> TranslationCacheStats {
        let count = (try? modelContext.fetchCount(FetchDescriptor<CachedTranslationModel>())) ?? 0
        return TranslationCacheStats(entryCount: count, hitCount: UserDefaults.standard.integer(forKey: Self.hitsKey))
    }

    public func clear() async {
        try? modelContext.delete(model: CachedTranslationModel.self)
        try? modelContext.save()
        UserDefaults.standard.set(0, forKey: Self.hitsKey)
    }

    public func setValue(_ value: Data, forKey key: String) async {
        var descriptor = FetchDescriptor<CachedTranslationModel>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.value = value
            existing.createdAt = Date()           // bump recency so it isn't pruned as stale
        } else {
            modelContext.insert(CachedTranslationModel(key: key, value: value))
        }
        try? modelContext.save()
        try? pruneBeyondLimit()                   // best-effort; the value is already saved
    }

    private func pruneBeyondLimit() throws {
        var descriptor = FetchDescriptor<CachedTranslationModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = Self.maxEntries
        let stale = try modelContext.fetch(descriptor)
        guard !stale.isEmpty else { return }
        for model in stale { modelContext.delete(model) }
        try modelContext.save()
    }
}

public enum PersistenceSchema {
    /// The model types the app's ModelContainer must register (single source of truth — `bootLive`
    /// and migrations both read this rather than re-listing the @Model types).
    public static let models: [any PersistentModel.Type] = AppSchemaV2.models
    /// The current versioned schema, paired with `AppMigrationPlan` when opening the store.
    public static let current = Schema(versionedSchema: AppSchemaV2.self)
}
