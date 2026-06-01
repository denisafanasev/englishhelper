//
//  SwiftDataRepositories.swift
//  EnglishHelper — Data (SwiftData adapters)
//
//  @ModelActor isolates each repository's ModelContext to its own actor, so persistence runs off
//  the main thread and is Sendable-safe under Swift 6.
//

import Foundation
import SwiftData
import Domain

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
    public func append(_ entry: HistoryEntry) async throws {
        modelContext.insert(try HistoryModel(entry))
        do { try modelContext.save() }
        catch { throw RepositoryError.persistenceFailed(error.localizedDescription) }
    }

    public func recent(limit: Int) async throws -> [HistoryEntry] {
        var descriptor = FetchDescriptor<HistoryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).compactMap { try? $0.toDomain() }
    }
}

public enum PersistenceSchema {
    /// The model types the app's ModelContainer must register.
    public static let models: [any PersistentModel.Type] = [ExpressionModel.self, HistoryModel.self]
}
