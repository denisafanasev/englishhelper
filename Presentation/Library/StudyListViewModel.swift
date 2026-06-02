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

    public enum ExportFormat: CaseIterable, Sendable {
        case algoApp, anki
        public var title: String {
            switch self {
            case .algoApp: "AlgoApp (.xml)"
            case .anki: "Anki (.txt)"
            }
        }
    }

    public private(set) var playingID: UUID?

    private let studyList: any StudyListUseCase
    private let saveExpression: any SaveExpressionUseCase
    private let exportAlgoApp: any ExportDeckUseCase
    private let exportAnki: any ExportDeckUseCase
    private let pronounce: any PlayPronunciationUseCase
    private let isConfigured: Bool
    private var playTask: Task<Void, Never>?

    public init(
        studyList: any StudyListUseCase,
        saveExpression: any SaveExpressionUseCase,
        exportAlgoApp: any ExportDeckUseCase,
        exportAnki: any ExportDeckUseCase,
        pronounce: any PlayPronunciationUseCase,
        isConfigured: Bool
    ) {
        self.studyList = studyList
        self.saveExpression = saveExpression
        self.exportAlgoApp = exportAlgoApp
        self.exportAnki = exportAnki
        self.pronounce = pronounce
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
            errorMessage = Loc.t("Не удалось загрузить список.", "Couldn't load the list.")
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

    public func export(_ format: ExportFormat) {
        exportError = nil
        let useCase = format == .anki ? exportAnki : exportAlgoApp
        Task { [weak self] in
            guard let self else { return }
            do {
                self.exportedDeck = try await useCase()
            } catch ExportError.nothingToExport {
                self.exportError = Loc.t("Список пуст — нечего экспортировать.", "The list is empty — nothing to export.")
            } catch {
                self.exportError = Loc.t("Не удалось создать файл для экспорта.", "Couldn't create the export file.")
            }
        }
    }

    // MARK: Playback

    public func isPlaying(_ expression: Domain.Expression) -> Bool { playingID == expression.id }

    public func play(_ expression: Domain.Expression) {
        if playingID == expression.id { stopPlayback(); return }   // tap again = stop
        playTask?.cancel()
        playingID = expression.id
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(expression.en) where state == .finished { break }
            } catch {
                // playback failure is non-fatal
            }
            if !Task.isCancelled, self.playingID == expression.id { self.playingID = nil }
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playingID = nil
    }

    public func clearExport() { exportedDeck = nil }
    public func clearExportError() { exportError = nil }
}
