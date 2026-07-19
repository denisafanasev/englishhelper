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
    /// Keys the user has explicitly toggled. `loadSavedState` must NOT seed these — its `studyList.list()`
    /// await can resume AFTER a user tap and would otherwise clobber the user's just-made choice.
    private var userToggledKeys: Set<String> = []
    private let saveExpression: any SaveExpressionUseCase
    private let studyList: any StudyListUseCase
    private let pronounce: any PlayPronunciationUseCase
    /// Session-recording playback for live-translation entries (nil in lean test setups).
    private let recordings: (any SessionRecordingsManaging)?
    private var playTask: Task<Void, Never>?
    private var recordingTask: Task<Void, Never>?

    public init(
        entry: HistoryEntry,
        saveExpression: any SaveExpressionUseCase,
        studyList: any StudyListUseCase,
        pronounce: any PlayPronunciationUseCase,
        recordings: (any SessionRecordingsManaging)? = nil
    ) {
        self.entry = entry
        self.saveExpression = saveExpression
        self.studyList = studyList
        self.pronounce = pronounce
        self.recordings = recordings
    }

    /// For `.translate` / `.photoTranslate` the saveable English source is the request text.
    public var translationRU: String? {
        switch entry.result {
        case .translate(let ru), .photoTranslate(let ru): ru
        case .howToSay, .whatToSay, .photoExplain, .liveTranslation: nil
        }
    }

    // MARK: Live-session recording playback

    /// The session's stored audio, if this entry is a live translation AND the file still exists.
    public var recordingFileName: String? {
        guard case .liveTranslation(_, _, let fileName?, _) = entry.result,
              let recordings, recordings.exists(fileName: fileName) else { return nil }
        return fileName
    }

    public private(set) var isPlayingRecording = false
    public private(set) var recordingProgress: Double = 0
    /// Playback failures get their OWN channel: `errorMessage` is the study-list alert ("Study
    /// list" title) — a recording problem under that title reads as nonsense.
    public private(set) var playbackError: String?

    public func clearPlaybackError() { playbackError = nil }

    /// Play / stop the original session audio (toggle).
    public func toggleRecordingPlayback() {
        if isPlayingRecording {
            stopRecordingPlayback()
            return
        }
        guard let fileName = recordingFileName, let recordings else { return }
        stopPlayback()   // never talk over TTS
        isPlayingRecording = true
        recordingProgress = 0
        recordingTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await state in recordings.play(fileName: fileName) {
                    switch state {
                    case .playing(let progress): self.recordingProgress = progress
                    case .finished: break
                    }
                }
            } catch RecordingPlaybackError.busy {
                self.playbackError = Loc.t("Сначала остановите онлайн-прослушивание.",
                                           "Stop the live listening session first.")
            } catch {
                self.playbackError = Loc.t("Не удалось воспроизвести запись.", "Couldn't play the recording.")
            }
            if !Task.isCancelled {
                self.isPlayingRecording = false
                self.recordingProgress = 0
            }
        }
    }

    /// Hard stop — also called when the detail screen disappears (a minutes-long recording must
    /// not keep playing with no visible way to stop it).
    public func stopRecordingPlayback() {
        recordingTask?.cancel()
        recordingTask = nil
        isPlayingRecording = false
        recordingProgress = 0
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
        case .howToSay(let variants), .whatToSay(let variants):
            for variant in variants {
                let key = Self.variantKey(variant)
                guard !userToggledKeys.contains(key) else { continue }   // user already decided this one
                if let id = storedID(for: variant.en) {
                    savedKeys.insert(key)
                    savedIDs[key] = id
                }
            }
        case .translate, .photoTranslate:
            let key = Self.translationKey
            guard !userToggledKeys.contains(key) else { return }
            if let id = storedID(for: entry.inputText) {
                savedKeys.insert(key)
                savedIDs[key] = id
            }
        case .photoExplain, .liveTranslation:
            break   // native-language explanation / whole-session text — nothing saveable here
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
        if playingKey == key { stopPlayback(); return }   // tap again = stop
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
            if !Task.isCancelled, self.playingKey == key { self.playingKey = nil }
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playingKey = nil
    }

    private func toggle(key: String, en: String, knownRU: String?, context: String) {
        userToggledKeys.insert(key)   // user owns this key now; loadSavedState must not re-seed it
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
