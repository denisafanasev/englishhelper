//
//  HistoryDetailViewModel.swift
//  EnglishHelper — Presentation
//
//  Read-only review of a past request, plus the ability to save phrases into the study list
//  (enrich-then-store, toggle). Saveable items are keyed so each can be toggled independently.
//

import Foundation
import Domain

@MainActor
@Observable
public final class HistoryDetailViewModel {
    public let entry: HistoryEntry
    public private(set) var errorMessage: String?

    private var savedIDs: [String: UUID] = [:]   // item key → stored Expression.id
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase

    public init(
        entry: HistoryEntry,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase
    ) {
        self.entry = entry
        self.saveExpression = saveExpression
        self.studyList = studyList
    }

    /// For `.translate` / `.photoTranslate` the saveable English source is the request text.
    public var translationRU: String? {
        switch entry.result {
        case .translate(let ru), .photoTranslate(let ru): ru
        case .howToSay: nil
        }
    }

    public func isSaved(_ key: String) -> Bool { savedIDs[key] != nil }
    public func clearError() { errorMessage = nil }
    public static func variantKey(_ variant: PhraseVariant) -> String { variant.id.uuidString }
    public static let translationKey = "translation"

    public func toggleSaveVariant(_ variant: PhraseVariant) {
        toggle(key: Self.variantKey(variant), en: variant.en, knownRU: nil, context: variant.contextRU)
    }

    public func toggleSaveTranslation() {
        guard let ru = translationRU else { return }
        toggle(key: Self.translationKey, en: entry.inputText, knownRU: ru, context: "")
    }

    private func toggle(key: String, en: String, knownRU: String?, context: String) {
        if let storedID = savedIDs[key] {
            savedIDs[key] = nil
            Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
        } else {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: en, knownRU: knownRU, context: context)
                    self.savedIDs[key] = stored.id
                } catch {
                    self.errorMessage = "Не удалось сохранить в изучаемое."
                }
            }
        }
    }
}
