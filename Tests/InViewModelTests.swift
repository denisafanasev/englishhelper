//
//  InViewModelTests.swift
//  EnglishHelperTests
//
//  "In" view-model behavior: single translation happy path, error→offline mapping, and that saving
//  files the English side as the study card's `en` (target = Russian).
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite @MainActor struct InViewModelTests {

    private func makeVM(
        llm: any LLMClient = MockLLMClient(),
        repo: MockExpressionRepository = MockExpressionRepository(seed: []),
        isConfigured: Bool = true
    ) -> InViewModel {
        let history = MockHistoryRepository()
        return InViewModel(
            translate: TranslateToTargetInteractor(llm: llm, history: history),
            voiceCapture: VoiceCaptureInteractor(recognizer: MockSpeechRecognizing()),
            pronounce: PlayPronunciationInteractor(synthesizer: MockSpeechSynthesizing()),
            saveExpression: SaveExpressionInteractor(
                enrich: EnrichExpressionInteractor(llm: llm), repository: repo
            ),
            studyList: StudyListInteractor(repository: repo),
            isConfigured: isConfigured
        )
    }

    private func waitUntil(_ condition: () -> Bool, timeout: Duration = .seconds(2)) async throws {
        let clock = ContinuousClock()
        let start = clock.now
        while !condition() {
            if clock.now - start > timeout { return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func submitProducesSingleTranslation() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        let vm = makeVM()
        vm.source = "Could you give me a hand?"
        vm.submit()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.translation == "Это тестовый перевод.")
    }

    @Test func translateTemplateOffersTranslateAndCompose() {
        let prompt = TranslateToTargetTemplate(targetLanguage: "Russian", tone: .formal).systemPrompt
        #expect(prompt.contains("Russian"))          // target language is injected
        #expect(prompt.contains("Translate"))         // mode 1: faithful translation
        #expect(prompt.contains("Compose"))           // mode 2: compose from an instruction
        #expect(prompt.contains("formal"))            // tone of voice is applied to composing
    }

    @Test func secondTapStopsPlayback() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        let vm = makeVM()
        vm.source = "Could you give me a hand?"
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.play()                    // first tap starts playback (synchronous flag)
        #expect(vm.isPlaying)
        vm.play()                    // second tap on the same phrase stops it
        #expect(!vm.isPlaying)
    }

    @Test func failureMapsToOfflineWhenNotConfigured() async throws {
        let vm = makeVM(llm: StubLLMClient(behavior: .failure(.notConfigured), latency: .milliseconds(1)))
        vm.source = "hello"
        vm.submit()
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline)
    }

    @Test func saveFilesEnglishSourceAsCard() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        let repo = MockExpressionRepository(seed: [])
        let vm = makeVM(repo: repo)
        vm.source = "Could you give me a hand?"
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.toggleSave()
        #expect(vm.isSaved)   // optimistic flag flips instantly

        // With target = Russian, the English source is the study card's `en` — wait for the
        // background enrich+store to land in the repository.
        let list = StudyListInteractor(repository: repo)
        var stored: [Domain.Expression] = []
        let clock = ContinuousClock(); let start = clock.now
        while !stored.contains(where: { $0.en == "Could you give me a hand?" }) {
            if clock.now - start > .seconds(2) { break }
            try await Task.sleep(for: .milliseconds(10))
            stored = (try? await list.list()) ?? []
        }
        #expect(stored.contains { $0.en == "Could you give me a hand?" })
    }

    /// The study card is ALWAYS the source (what was translated), never the user's-language result —
    /// even when the target language is English.
    @Test func saveFilesSourceRegardlessOfTarget() async throws {
        UserDefaults.standard.set("english", forKey: "targetLanguage")
        defer { UserDefaults.standard.set("russian", forKey: "targetLanguage") }
        let repo = MockExpressionRepository(seed: [])
        let vm = makeVM(repo: repo)
        vm.source = "Bonjour le monde"          // a non-English source; translation would be English
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.toggleSave()
        let list = StudyListInteractor(repository: repo)
        var stored: [Domain.Expression] = []
        let clock = ContinuousClock(); let start = clock.now
        while !stored.contains(where: { $0.en == "Bonjour le monde" }) {
            if clock.now - start > .seconds(2) { break }
            try await Task.sleep(for: .milliseconds(10))
            stored = (try? await list.list()) ?? []
        }
        // The source is filed as `en` — NOT the translation "Это тестовый перевод.".
        #expect(stored.contains { $0.en == "Bonjour le monde" })
        #expect(!stored.contains { $0.en == "Это тестовый перевод." })
    }
}
