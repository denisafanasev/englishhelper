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
            understand: UnderstandInteractor(llm: llm, history: history),
            explain: ExplainExpressionInteractor(llm: llm),
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

    @Test func submitProducesStudiedAndNative() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let vm = makeVM()
        vm.source = "Could you give me a hand?"
        vm.submit()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.studied == "Could you give me a hand?")   // headline = studied rendering
        #expect(vm.translation == "Это тестовый перевод.")    // understanding line = native
    }

    @Test func understandTemplateIsFaithfulStudiedPlusNative() {
        let prompt = UnderstandTemplate(studiedLanguage: "English", nativeLanguage: "Russian").systemPrompt
        #expect(prompt.contains("English"))    // studied rendering
        #expect(prompt.contains("Russian"))    // native rendering
        #expect(prompt.contains("FAITHFUL"))   // faithful translation only (no compose/tone)
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

    /// The study card front is the STUDIED-language rendering (what you're learning), never the raw
    /// input or the native translation.
    @Test func saveStudiesTheStudiedRendering() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let repo = MockExpressionRepository(seed: [])
        let vm = makeVM(repo: repo)
        vm.source = "Bonjour le monde"          // a non-studied input; studied rendering is what we save
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.toggleSave()
        #expect(vm.isSaved)   // optimistic flag flips instantly

        let list = StudyListInteractor(repository: repo)
        var stored: [Domain.Expression] = []
        let clock = ContinuousClock(); let start = clock.now
        while !stored.contains(where: { $0.en == "Could you give me a hand?" }) {
            if clock.now - start > .seconds(2) { break }
            try await Task.sleep(for: .milliseconds(10))
            stored = (try? await list.list()) ?? []
        }
        // Front = the studied rendering (mock "Could you give me a hand?") — NOT the raw input
        // "Bonjour le monde" nor the native gloss "Это тестовый перевод.".
        #expect(stored.contains { $0.en == "Could you give me a hand?" })
        #expect(!stored.contains { $0.en == "Bonjour le monde" })
        #expect(!stored.contains { $0.en == "Это тестовый перевод." })
    }

    // MARK: Explain mode

    @Test func explainModeProducesExplanationNotTranslation() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        let vm = makeVM()
        vm.source = "give me a hand"
        vm.selectMode(.explain)          // no result yet → just switches, no auto-run
        #expect(vm.translation == nil)
        vm.submit()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.explanation != nil)
        #expect(vm.translation == nil)   // explain mode never leaves a stale translation
    }

    @Test func explainTemplateTargetsNativeLanguageAndNuance() {
        let prompt = ExplainExpressionTemplate(studiedLanguage: "English", nativeLanguage: "Russian").systemPrompt
        #expect(prompt.contains("Russian"))     // explanation is written in the native language
        #expect(prompt.contains("English"))     // ...about the studied-language rendering
        #expect(prompt.contains("studied"))     // returns the studied form for the headline
        #expect(prompt.contains("meaning"))     // facet: what it means
        #expect(prompt.contains("register"))    // facet: tone / formality / offensiveness
        #expect(prompt.contains("analogy"))     // facet: native-culture analogy
    }

    @Test func explainModeSaveFilesEnglishSource() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        let repo = MockExpressionRepository(seed: [])
        let vm = makeVM(repo: repo)
        vm.source = "give me a hand"
        vm.selectMode(.explain)
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.toggleSave()                  // saveable even with no direct gloss (enrich derives it)
        #expect(vm.isSaved)

        let list = StudyListInteractor(repository: repo)
        var stored: [Domain.Expression] = []
        let clock = ContinuousClock(); let start = clock.now
        while !stored.contains(where: { $0.en == "give me a hand" }) {
            if clock.now - start > .seconds(2) { break }
            try await Task.sleep(for: .milliseconds(10))
            stored = (try? await list.list()) ?? []
        }
        #expect(stored.contains { $0.en == "give me a hand" })
    }
}
