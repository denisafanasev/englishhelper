//
//  AppContainer.swift
//  EnglishHelper — App (composition root / DI)
//
//  The ONLY place that knows about concrete adapters. Builds ports, wires them into use cases,
//  and hands use cases to Presentation. v1 swaps `bootMock()` adapters for live ones; nothing
//  else in the graph changes.
//

import Foundation
import SwiftData
import OSLog
import Domain
import Adapters
import Presentation

public final class AppContainer: Sendable {
    public let config: AppConfig
    /// True when the on-disk store could not be opened and the app is running on an in-memory store:
    /// real Claude still works, but study-list/history changes WON'T survive relaunch. Drives a banner.
    public let usingFallbackStore: Bool

    private static let log = Logger(subsystem: "com.englishhelper.app", category: "persistence")

    // Ports (adapters)
    public let llm: any LLMClient
    public let speechRecognizer: any SpeechRecognizing       // ru-RU (Out)
    public let speechRecognizerEN: any SpeechRecognizing     // en-US (In)
    public let speechSynthesizer: any SpeechSynthesizing
    public let textRecognizer: any TextRecognizing
    public let expressions: any ExpressionRepository
    public let history: any HistoryRepository
    public let exporter: any DeckExporting

    // Use cases (what Presentation consumes)
    public let howToSay: any HowToSayUseCase
    public let whatToSay: any WhatToSayUseCase
    public let translateText: any TranslateTextUseCase
    public let photoTranslate: any PhotoTranslateUseCase
    public let enrich: any EnrichExpressionUseCase
    public let studyList: any StudyListUseCase
    public let requestHistory: any RequestHistoryUseCase
    public let exportDeck: any ExportDeckUseCase        // AlgoApp .xml
    public let exportAnkiDeck: any ExportDeckUseCase    // Anki .txt
    public let regenerateHowToSay: any RegenerateHowToSayUseCase
    public let saveExpression: any SaveExpressionUseCase
    public let voiceCapture: any VoiceCaptureUseCase
    public let voiceCaptureEN: any VoiceCaptureUseCase
    public let pronounce: any PlayPronunciationUseCase
    public let connectionHealth: any ConnectionHealthUseCase
    public let translateToTarget: any TranslateToTargetUseCase
    public let understand: any UnderstandUseCase
    public let explainExpression: any ExplainExpressionUseCase

    public init(
        config: AppConfig,
        usingFallbackStore: Bool = false,
        llm: any LLMClient,
        speechRecognizer: any SpeechRecognizing,
        speechRecognizerEN: any SpeechRecognizing,
        speechSynthesizer: any SpeechSynthesizing,
        textRecognizer: any TextRecognizing,
        expressions: any ExpressionRepository,
        history: any HistoryRepository,
        exporter: any DeckExporting
    ) {
        self.config = config
        self.usingFallbackStore = usingFallbackStore
        self.llm = llm
        self.speechRecognizer = speechRecognizer
        self.speechRecognizerEN = speechRecognizerEN
        self.speechSynthesizer = speechSynthesizer
        self.textRecognizer = textRecognizer
        self.expressions = expressions
        self.history = history
        self.exporter = exporter

        // Wire use cases onto the ports.
        self.howToSay = HowToSayInteractor(llm: llm, history: history)
        self.whatToSay = WhatToSayInteractor(llm: llm, history: history)
        self.translateText = TranslateTextInteractor(llm: llm, history: history)
        self.photoTranslate = PhotoTranslateInteractor(llm: llm, history: history)   // LLM vision (no local OCR)
        self.enrich = EnrichExpressionInteractor(llm: llm)
        self.studyList = StudyListInteractor(repository: expressions)
        self.requestHistory = RequestHistoryInteractor(history: history)
        self.exportDeck = ExportDeckInteractor(repository: expressions, exporter: exporter)
        // Anki exporter is pure (no deps), built here at the composition root.
        self.exportAnkiDeck = ExportDeckInteractor(repository: expressions, exporter: AnkiExporter())
        self.regenerateHowToSay = RegenerateHowToSayInteractor(llm: llm, history: history)
        self.saveExpression = SaveExpressionInteractor(
            enrich: EnrichExpressionInteractor(llm: llm), repository: expressions
        )
        self.voiceCapture = VoiceCaptureInteractor(recognizer: speechRecognizer)
        self.voiceCaptureEN = VoiceCaptureInteractor(recognizer: speechRecognizerEN)
        self.pronounce = PlayPronunciationInteractor(synthesizer: speechSynthesizer)
        self.connectionHealth = ConnectionHealthInteractor(llm: llm)
        self.translateToTarget = TranslateToTargetInteractor(llm: llm, history: history)
        self.understand = UnderstandInteractor(llm: llm, history: history)
        self.explainExpression = ExplainExpressionInteractor(llm: llm)
    }

    /// v1: the whole graph on LIVE adapters. Swapping any engine is exactly ONE line below
    /// (see README "Swapping an engine"). The Domain/Presentation never learn which one is wired.
    public static func bootLive(config: AppConfig = .load()) throws -> AppContainer {
        let (modelContainer, usingFallbackStore) = try makePersistentContainer()
        return AppContainer(
            config: config,
            usingFallbackStore: usingFallbackStore,
            llm: ClaudeLLMClient(apiKey: config.claudeAPIKey ?? "",
                                 model: config.claudeModel,
                                 baseURL: config.claudeBaseURL),
            // "Say it": the microphone follows the user's chosen native language (resolved per capture).
            speechRecognizer: NativeSpeechRecognizer(localeProvider: {
                Locale(identifier: TargetLanguage.current.speechLocale)
            }),
            // "Get it" mic listens in the STUDIED language (you capture studied-language speech to understand it).
            speechRecognizerEN: NativeSpeechRecognizer(localeProvider: {
                Locale(identifier: StudiedLanguage.current.speechLocale)
            }),
            // All TTS speaks the STUDIED language (resolved per utterance). ← swap TTS engine here
            speechSynthesizer: NativeSpeechSynthesizer(localeProvider: { StudiedLanguage.current.speechLocale }),
            // NB: the photo flow currently uses Claude's vision (PhotoTranslateInteractor → LLM), so this
            // on-device OCR adapter is wired for the port contract / future use but NOT consumed today.
            textRecognizer: VisionTextRecognizer(),         // ← swap OCR engine here (when OCR is used)
            expressions: SwiftDataExpressionRepository(modelContainer: modelContainer),
            history: SwiftDataHistoryRepository(modelContainer: modelContainer),
            exporter: AlgoAppXMLExporter()
        )
    }

    /// Open the on-disk SwiftData store, applying `AppMigrationPlan`. If the store can't be opened
    /// (corruption, or a schema change with no migration stage), DON'T silently downgrade to canned
    /// mocks — log it and fall back to an IN-MEMORY store so the app stays on real adapters (real
    /// Claude, real in-session save/history). The returned flag drives a visible "changes won't be
    /// saved" banner, so the user is never quietly losing data. The on-disk file is left untouched so
    /// a future build with a proper migration can still recover it. Throws only if even an in-memory
    /// store can't be created.
    private static func makePersistentContainer() throws -> (ModelContainer, fallback: Bool) {
        let schema = PersistenceSchema.current
        do {
            let onDisk = ModelConfiguration(schema: schema)
            let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: onDisk)
            return (container, false)
        } catch {
            log.error("On-disk store failed to open: \(String(describing: error), privacy: .public). Falling back to in-memory storage — changes this session will NOT persist.")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try ModelContainer(for: schema, configurations: memory), true)
        }
    }

    /// Previews / tests / offline fallback: the whole graph on mocks. No network, no permissions.
    public static func bootMock(config: AppConfig = .load()) -> AppContainer {
        AppContainer(
            config: config,
            llm: MockLLMClient(),
            speechRecognizer: MockSpeechRecognizing(),
            speechRecognizerEN: MockSpeechRecognizing(),
            speechSynthesizer: MockSpeechSynthesizing(),
            textRecognizer: MockTextRecognizing(),
            expressions: MockExpressionRepository(),
            history: MockHistoryRepository(),
            exporter: MockDeckExporting()
        )
    }

    @MainActor
    public func makeVoiceViewModel() -> VoiceViewModel {
        VoiceViewModel(
            howToSay: howToSay,
            regenerateHowToSay: regenerateHowToSay,
            whatToSay: whatToSay,
            voiceCapture: voiceCapture,
            pronounce: pronounce,
            saveExpression: saveExpression,
            studyList: studyList,
            isConfigured: config.isClaudeConfigured
        )
    }

    @MainActor
    public func makeInViewModel() -> InViewModel {
        InViewModel(
            understand: understand,
            explain: explainExpression,
            voiceCapture: voiceCaptureEN,
            pronounce: pronounce,
            saveExpression: saveExpression,
            studyList: studyList,
            isConfigured: config.isClaudeConfigured
        )
    }

    @MainActor
    public func makePhotoTranslateViewModel() -> PhotoTranslateViewModel {
        PhotoTranslateViewModel(
            photoTranslate: photoTranslate,
            pronounce: pronounce,
            saveExpression: saveExpression,
            studyList: studyList,
            isConfigured: config.isClaudeConfigured
        )
    }

    @MainActor
    public func makeStudyListViewModel() -> StudyListViewModel {
        StudyListViewModel(
            studyList: studyList,
            saveExpression: saveExpression,
            exportAlgoApp: exportDeck,
            exportAnki: exportAnkiDeck,
            pronounce: pronounce,
            isConfigured: config.isClaudeConfigured
        )
    }

    @MainActor
    public func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(
            history: requestHistory, saveExpression: saveExpression,
            studyList: studyList, pronounce: pronounce
        )
    }

    @MainActor
    public func makeSettingsViewModel() -> SettingsViewModel {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return SettingsViewModel(
            connectionHealth: connectionHealth,
            appVersion: version,
            modelName: config.claudeModel
        )
    }
}
