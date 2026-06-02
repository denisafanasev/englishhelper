//
//  HistoryViewModel.swift
//  EnglishHelper — Presentation
//
//  "История" — chronological, read-only log of every request (how-to-say / translate / photo).
//

import Foundation
import Domain

@MainActor
@Observable
public final class HistoryViewModel {
    public enum Phase: Equatable { case loading, loaded, empty, failed }

    public private(set) var phase: Phase = .loading
    public private(set) var entries: [HistoryEntry] = []
    public private(set) var errorMessage: String?

    private let history: any RequestHistoryUseCase
    private let limit = 200

    public init(history: any RequestHistoryUseCase) {
        self.history = history
    }

    public func load() async {
        if entries.isEmpty { phase = .loading }
        do {
            let items = try await history.recent(limit: limit)   // most-recent-first
            entries = items
            phase = items.isEmpty ? .empty : .loaded
        } catch {
            errorMessage = "Не удалось загрузить историю."
            phase = .failed
        }
    }
}
