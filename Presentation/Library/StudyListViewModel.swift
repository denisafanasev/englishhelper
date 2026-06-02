//
//  StudyListViewModel.swift
//  EnglishHelper — Presentation
//
//  "Изучаю" — the flat study list. Manual add (enrich-then-store), swipe-delete, toggle learned,
//  export to an AlgoApp .xml deck.
//

import Foundation
import Domain

@MainActor
@Observable
public final class StudyListViewModel {
    public enum Phase: Equatable { case loading, loaded, empty, failed }

    public private(set) var phase: Phase = .loading
    public private(set) var expressions: [Domain.Expression] = []   // Domain.* avoids Foundation.Expression
    public private(set) var errorMessage: String?

    // Add form
    public var showAddSheet = false
    public var newEnglish = ""
    public var newContext = ""
    public private(set) var isAdding = false
    public private(set) var addError: String?

    // Export
    public private(set) var exportedDeck: ExportedDeck?
    public private(set) var exportError: String?

    private let studyList: any StudyListUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let exportDeck: any ExportDeckUseCase
    private let isConfigured: Bool

    public init(
        studyList: any StudyListUseCase,
        saveExpression: any SaveExpressionUseCase,
        exportDeck: any ExportDeckUseCase,
        isConfigured: Bool
    ) {
        self.studyList = studyList
        self.saveExpression = saveExpression
        self.exportDeck = exportDeck
        self.isConfigured = isConfigured
    }

    public var canAdd: Bool { !newEnglish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var needsAPIKey: Bool { !isConfigured }

    public func load() async {
        if expressions.isEmpty { phase = .loading }
        do {
            let items = try await studyList.list()
            expressions = items
            phase = items.isEmpty ? .empty : .loaded
        } catch {
            errorMessage = "Не удалось загрузить список."
            phase = .failed
        }
    }

    public func add() {
        let english = newEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !english.isEmpty, !isAdding else { return }
        let context = newContext.trimmingCharacters(in: .whitespacesAndNewlines)
        isAdding = true
        addError = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.saveExpression(en: english, knownRU: nil, context: context)
                self.newEnglish = ""
                self.newContext = ""
                self.isAdding = false
                self.showAddSheet = false
                await self.load()
            } catch {
                self.isAdding = false
                self.addError = presentableError(error).message
            }
        }
    }

    public func delete(_ expression: Domain.Expression) {
        expressions.removeAll { $0.id == expression.id }
        if expressions.isEmpty { phase = .empty }
        Task { [weak self] in
            guard let self else { return }
            try? await self.studyList.delete(id: expression.id)
        }
    }

    public func toggleLearned(_ expression: Domain.Expression) {
        let newValue = !expression.learned
        if let index = expressions.firstIndex(where: { $0.id == expression.id }) {
            expressions[index].learned = newValue
        }
        Task { [weak self] in
            guard let self else { return }
            try? await self.studyList.setLearned(newValue, id: expression.id)
        }
    }

    public func export() {
        exportError = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                self.exportedDeck = try await self.exportDeck()
            } catch ExportError.nothingToExport {
                self.exportError = "Список пуст — нечего экспортировать."
            } catch {
                self.exportError = "Не удалось создать файл для экспорта."
            }
        }
    }

    public func clearExport() { exportedDeck = nil }
    public func clearExportError() { exportError = nil }
}
