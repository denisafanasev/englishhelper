//
//  MockRepositories.swift
//  EnglishHelper — Data (mock adapters)
//
//  In-memory actors. The SwiftData-backed implementations land in v1 (Step 2).
//

import Domain   // NB: no `import Foundation` — it would make `Expression` ambiguous with Foundation.Expression (Predicate).

public actor MockExpressionRepository: ExpressionRepository {
    private var items: [Expression]

    public init(seed: [Expression] = MockExpressionRepository.defaultSeed) {
        self.items = seed
    }

    public func all() async throws -> [Expression] {
        items.sorted { $0.createdAt > $1.createdAt }
    }

    public func add(_ expression: Expression) async throws {
        items.append(expression)
    }

    public func update(_ expression: Expression) async throws {
        guard let idx = items.firstIndex(where: { $0.id == expression.id }) else {
            throw RepositoryError.notFound
        }
        items[idx] = expression
    }

    public func delete(id: Expression.ID) async throws {
        items.removeAll { $0.id == id }
    }

    public func setLearned(_ learned: Bool, id: Expression.ID) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        items[idx].learned = learned
    }

    public static let defaultSeed: [Expression] = [
        Expression(en: "I appreciate it", ru: "Я ценю это",
                   example: "Thanks for covering my shift — I really appreciate it.",
                   synonyms: ["I'm grateful", "thank you"],
                   context: "Тёплая благодарность."),
        Expression(en: "No worries at all", ru: "Ничего страшного",
                   example: "No worries at all, take your time.",
                   synonyms: ["it's fine", "don't mention it"],
                   context: "Снять неловкость.", learned: true),
    ]
}

public actor MockHistoryRepository: HistoryRepository {
    private var entries: [HistoryEntry]

    public init(seed: [HistoryEntry] = []) {
        self.entries = seed
    }

    public func append(_ entry: HistoryEntry) async throws {
        entries.append(entry)
    }

    public func recent(limit: Int) async throws -> [HistoryEntry] {
        Array(entries.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
}
