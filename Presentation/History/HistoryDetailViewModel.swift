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

    public private(set) var playingKey: String?

    private var savedKeys: Set<String> = []       // optimistic "saved" flag (instant UI)
    private var savedIDs: [String: UUID] = [:]    // item key → stored Expression.id
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let pronounce: any PlayPronunciationUseCase
    private var playTask: Task<Void, Never>?

    public init(
        entry: HistoryEntry,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        pronounce: any PlayPronunciationUseCase
    ) {
        self.entry = entry
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.pronounce = pronounce
    }

    /// For `.translate` / `.photoTranslate` the saveable English source is the request text.
    public var translationRU: String? {
        switch entry.result {
        case .translate(let ru), .photoTranslate(let ru): ru
        case .howToSay: nil
        }
    }

    public func isSaved(_ key: String) -> Bool { savedKeys.contains(key) }
    public func clearError() { errorMessage = nil }

    /// Reflect phrases already in the study list (match by English text), so the bookmarks show
    /// as saved when you open an old request.
    public func loadSavedState() async {
        let existing = (try? await studyList.list()) ?? []
        func storedID(for english: String) -> UUID? {
            let target = english.trimmingCharacters(in: .whitespacesAndNewlines)
            return existing.first { $0.en.caseInsensitiveCompare(target) == .orderedSame }?.id
        }
        switch entry.result {
        case .howToSay(let variants):
            for variant in variants {
                if let id = storedID(for: variant.en) {
                    let key = Self.variantKey(variant)
                    savedKeys.insert(key)
                    savedIDs[key] = id
                }
            }
        case .translate, .photoTranslate:
            if let id = storedID(for: entry.inputText) {
                savedKeys.insert(Self.translationKey)
                savedIDs[Self.translationKey] = id
            }
        }
    }
    public static func variantKey(_ variant: PhraseVariant) -> String { variant.id.uuidString }
    public static let translationKey = "translation"

    public func toggleSaveVariant(_ variant: PhraseVariant) {
        toggle(key: Self.variantKey(variant), en: variant.en, knownRU: nil, context: variant.contextRU)
    }

    public func toggleSaveTranslation() {
        guard let ru = translationRU else { return }
        toggle(key: Self.translationKey, en: entry.inputText, knownRU: ru, context: "")
    }

    // MARK: Play (TTS of the English text)

    public func isPlaying(_ key: String) -> Bool { playingKey == key }

    public func playVariant(_ variant: PhraseVariant) {
        play(key: Self.variantKey(variant), english: variant.en)
    }

    /// For translate / photo entries the English text to speak is the request source.
    public func playTranslationSource() {
        play(key: Self.translationKey, english: entry.inputText)
    }

    private func play(key: String, english: String) {
        guard !english.isEmpty else { return }
        playTask?.cancel()
        playingKey = key
        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in self.pronounce(english) where state == .finished { break }
            } catch {
                // playback failure is non-fatal
            }
            if self.playingKey == key { self.playingKey = nil }
        }
    }

    private func toggle(key: String, en: String, knownRU: String?, context: String) {
        if savedKeys.contains(key) {
            savedKeys.remove(key)                        // instant UI
            let storedID = savedIDs[key]
            savedIDs[key] = nil
            if let storedID {
                Task { [weak self] in try? await self?.studyList.delete(id: storedID) }
            }
        } else {
            savedKeys.insert(key)                        // instant UI; enrich+store in background
            Task { [weak self] in
                guard let self else { return }
                do {
                    let stored = try await self.saveExpression(en: en, knownRU: knownRU, context: context)
                    if self.savedKeys.contains(key) { self.savedIDs[key] = stored.id }
                    else { try? await self.studyList.delete(id: stored.id) }
                } catch {
                    self.savedKeys.remove(key)           // revert
                    self.errorMessage = Loc.t("Не удалось сохранить в изучаемое.",
                                              "Couldn't save to your study list.")
                }
            }
        }
    }
}
