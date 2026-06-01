//
//  AppContainer.swift
//  EnglishHelper — App (composition root / DI)
//
//  The ONLY place that knows about concrete adapters. Builds ports, wires them into use cases,
//  and hands use cases to Presentation. v1 swaps `bootMock()` adapters for live ones; nothing
//  else in the graph changes.
//

import Foundation
import Domain
import Adapters
import Presentation

public final class AppContainer: Sendable {
    public let config: AppConfig

    // Ports (adapters)
    public let llm: any LLMClient
    public let speechRecognizer: any SpeechRecognizing
    public let speechSynthesizer: any SpeechSynthesizing
    public let textRecognizer: any TextRecognizing
    public let expressions: any ExpressionRepository
    public let history: any HistoryRepository
    public let exporter: any DeckExporting

    // Use cases (what Presentation consumes)
    public let howToSay: any HowToSayUseCase
    public let translateText: any TranslateTextUseCase
    public let photoTranslate: any PhotoTranslateUseCase
    public let enrich: any EnrichExpressionUseCase
    public let studyList: any StudyListUseCase
    public let requestHistory: any RequestHistoryUseCase
    public let exportDeck: any ExportDeckUseCase

    public init(
        config: AppConfig,
        llm: any LLMClient,
        speechRecognizer: any SpeechRecognizing,
        speechSynthesizer: any SpeechSynthesizing,
        textRecognizer: any TextRecognizing,
        expressions: any ExpressionRepository,
        history: any HistoryRepository,
        exporter: any DeckExporting
    ) {
        self.config = config
        self.llm = llm
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
        self.textRecognizer = textRecognizer
        self.expressions = expressions
        self.history = history
        self.exporter = exporter

        // Wire use cases onto the ports.
        self.howToSay = HowToSayInteractor(llm: llm, history: history)
        self.translateText = TranslateTextInteractor(llm: llm, history: history)
        self.photoTranslate = PhotoTranslateInteractor(ocr: textRecognizer, llm: llm, history: history)
        self.enrich = EnrichExpressionInteractor(llm: llm)
        self.studyList = StudyListInteractor(repository: expressions)
        self.requestHistory = RequestHistoryInteractor(history: history)
        self.exportDeck = ExportDeckInteractor(repository: expressions, exporter: exporter)
    }

    /// Step 1 / previews / tests: the whole graph on mocks. No network, no permissions.
    public static func bootMock(config: AppConfig = .load()) -> AppContainer {
        AppContainer(
            config: config,
            llm: MockLLMClient(),
            speechRecognizer: MockSpeechRecognizing(),
            speechSynthesizer: MockSpeechSynthesizing(),
            textRecognizer: MockTextRecognizing(),
            expressions: MockExpressionRepository(),
            history: MockHistoryRepository(),
            exporter: MockDeckExporting()
        )
    }

    @MainActor
    public func makeRootViewModel() -> RootViewModel {
        RootViewModel(studyList: studyList)
    }
}
