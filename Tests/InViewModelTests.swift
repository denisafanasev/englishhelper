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

@Suite(.serialized) @MainActor struct InViewModelTests {

    /// The mode is persisted so the screen reopens as last used; each test starts from the default,
    /// not whatever a previous test (or app run on this simulator) left behind.
    init() { UserDefaults.standard.removeObject(forKey: "getItMode") }

    private func makeVM(
        llm: any LLMClient = MockLLMClient(),
        repo: MockExpressionRepository = MockExpressionRepository(seed: []),
        isConfigured: Bool = true,
        recognizer: any SpeechRecognizing = MockSpeechRecognizing()
    ) -> InViewModel {
        let history = MockHistoryRepository()
        return InViewModel(
            understand: UnderstandInteractor(llm: llm, history: history),
            explain: ExplainExpressionInteractor(llm: llm),
            voiceCapture: VoiceCaptureInteractor(recognizer: recognizer),
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
        vm.selectMode(.translate)                            // default is now Explain; test Translate
        vm.source = "bank"
        vm.submit()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.studied == "bank")                        // headline = studied rendering
        #expect(vm.translations.count == 2)                  // a word with two senses → two variants
        #expect(vm.translations.first?.text == "банк")       // first translation
        #expect(vm.translations.first?.context == "финансовое учреждение")   // with its context note
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
        vm.selectMode(.translate)               // default is now Explain; this test exercises Translate
        vm.source = "Bonjour le monde"          // a non-studied input; studied rendering is what we save
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.toggleSave()
        #expect(vm.isSaved)   // optimistic flag flips instantly

        let list = StudyListInteractor(repository: repo)
        var stored: [Domain.Expression] = []
        let clock = ContinuousClock(); let start = clock.now
        while !stored.contains(where: { $0.en == "bank" }) {
            if clock.now - start > .seconds(2) { break }
            try await Task.sleep(for: .milliseconds(10))
            stored = (try? await list.list()) ?? []
        }
        // Front = the studied rendering (mock "bank") — NOT the raw input "Bonjour le monde" nor a
        // native gloss ("банк").
        #expect(stored.contains { $0.en == "bank" })
        #expect(!stored.contains { $0.en == "Bonjour le monde" })
        #expect(!stored.contains { $0.en == "банк" })
    }

    // MARK: State preservation (leave / return)

    /// Leaving the screen with a result on screen drops an edit the user never submitted, so on
    /// return the input matches the visible result. The result itself is untouched.
    @Test func leavingScreenRevertsUnsubmittedEdit() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let vm = makeVM()
        vm.selectMode(.translate)
        vm.source = "bank"
        vm.submit()
        try await waitUntil { vm.phase == .result }

        vm.source = "river"                     // edited, never submitted
        vm.screenDisappeared()                  // ← tab switched away

        #expect(vm.source == "bank")
        #expect(vm.phase == .result)
        #expect(vm.translations.first?.text == "банк")
    }

    /// With nothing generated there is nothing to mismatch — a draft survives leaving the screen.
    @Test func leavingScreenKeepsDraftWhenNothingGenerated() {
        let vm = makeVM()
        vm.source = "draft text"
        vm.screenDisappeared()
        #expect(vm.source == "draft text")
        #expect(vm.phase == .idle)
    }

    /// The chosen mode is persisted: a fresh view model (next launch) starts in the last-used mode.
    @Test func modePersistsAcrossInstances() {
        let vm = makeVM()
        vm.selectMode(.translate)
        #expect(makeVM().mode == .translate)
    }

    /// A ROUTED mode change (deep link / shared-in text) applies for the session but must never
    /// overwrite the persisted selector choice — only an explicit on-screen tap does.
    @Test func routedModeIsSessionOnly() {
        let vm = makeVM()
        vm.routeMode(.translate)
        #expect(vm.mode == .translate)          // applied now…
        #expect(makeVM().mode == .explain)      // …but the next launch keeps the saved default
    }

    /// startExplain (Explain from a card / History / Share Extension) is a routed action too: it
    /// must not overwrite a persisted Translate preference.
    @Test func startExplainDoesNotOverwritePersistedMode() async throws {
        makeVM().selectMode(.translate)         // the user's explicit, persisted choice

        let vm = makeVM()
        vm.startExplain(text: "give me a hand")
        try await waitUntil { vm.phase == .result }
        #expect(vm.mode == .explain)            // routed action ran in Explain…
        #expect(makeVM().mode == .translate)    // …but the saved preference is intact
    }

    /// Clearing the input and switching the mode mid-flight must CANCEL the old-mode request — its
    /// late result must not land under the new mode, and the deliberately cleared text must not be
    /// resurrected by a later tab round-trip.
    @Test func clearedInputModeSwitchCancelsInFlightRequest() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let vm = makeVM(llm: StubLLMClient(behavior: .success, latency: .milliseconds(150)))
        vm.selectMode(.translate)
        vm.source = "bank"
        vm.submit()
        #expect(vm.phase == .processing)

        vm.source = ""                          // the field's clear (X) button
        vm.selectMode(.explain)
        #expect(vm.phase == .idle)              // in-flight request dropped, not left running

        try await Task.sleep(for: .milliseconds(300))
        #expect(vm.phase == .idle)              // the slow translate result never landed
        #expect(vm.translations.isEmpty)
        vm.screenDisappeared()
        #expect(vm.source.isEmpty)              // cleared text is not resurrected on leave/return
    }

    // MARK: Explain mode

    @Test func explainModeProducesExplanationNotTranslation() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        let vm = makeVM()
        vm.source = "give me a hand"
        vm.selectMode(.explain)          // no result yet → just switches, no auto-run
        #expect(vm.translations.isEmpty)
        vm.submit()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.explanation != nil)
        #expect(vm.translations.isEmpty)   // explain mode never leaves a stale translation
    }

    /// Regression: toggling Translate/Explain WHILE a request is in flight must cancel-and-restart
    /// cleanly — never leave the screen stuck in `.failed`. Pre-fix the in-flight URLSession cancel
    /// surfaced as `LLMError.requestFailed("cancelled")`/`.cancelled` and InViewModel routed it to
    /// `handleRequestError` → `.failed` + "Request cancelled", from which a further toggle couldn't
    /// recover. (StubLLMClient maps a cancelled sleep to LLMError.cancelled, like the live adapter.)
    @Test func switchingModeMidGenerationNeverErrors() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let vm = makeVM(llm: StubLLMClient(behavior: .success, latency: .milliseconds(120)))
        vm.selectMode(.translate)
        vm.source = "Could you give me a hand?"

        vm.submit()
        #expect(vm.phase == .processing)        // set synchronously, request in flight

        vm.selectMode(.explain)                 // toggle the style mid-generation → supersede
        #expect(vm.phase == .processing)        // restarted, NOT flipped to .failed
        #expect(vm.errorMessage == nil)

        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)            // deterministic: ends generating, not erroring
        #expect(vm.errorMessage == nil)         // the self-inflicted cancel never surfaced
        #expect(vm.mode == .explain)            // ...in the newly chosen style
        #expect(vm.explanation != nil)
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

    /// Switching mode after a FAILURE must re-run the same input (not stay stuck on the error).
    @Test func switchingModeAfterFailureReRunsOnTheSameInput() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let vm = makeVM(llm: FlakyUnderstandLLM(failuresBeforeSuccess: 1))   // default mode Explain → first run fails
        vm.source = "bank"
        vm.submit()
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        vm.selectMode(.translate)                                            // switch → must retry the input
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.translations.isEmpty == false)
    }

    /// Regression: explaining a phrase routed from a See it card must NOT carry the source photo — the
    /// explanation should generalise (what the phrase means on its own), not describe the whole photo.
    @Test func startExplainCarriesNoPhotoContext() async throws {
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let spy = ExplainImageSpyLLM()
        let vm = makeVM(llm: spy)
        vm.startExplain(text: "NAUGHTY BOY")          // as if tapped from a See it / Translate block
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.explanation != nil)
        #expect(spy.explainHadImage == false)         // no image attached → explained broadly, not in-photo
    }

    // MARK: Push-to-talk (capture runs while the button is held; release runs the current mode)

    /// Press starts the mic; RELEASE stops it and runs Translate/Explain (per the on-screen mode)
    /// on what was heard — the live-mic contract (the stream stays open until cancelled).
    @Test func holdCapturesAndReleaseRunsCurrentMode() async throws {
        UserDefaults.standard.set(true, forKey: "didPrimeMic")
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let vm = makeVM(recognizer: HoldingEnRecognizer(partial: "bank"))
        vm.selectMode(.translate)
        vm.micPressBegan()
        #expect(vm.isListening)
        try await waitUntil { vm.source == "bank" }
        #expect(vm.isListening)                                   // still held — no submit yet
        vm.micPressEnded()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.translations.first?.text == "банк")
    }

    /// Releasing with nothing heard must return to idle without firing a request.
    @Test func releaseWithNothingHeardReturnsToIdle() async throws {
        UserDefaults.standard.set(true, forKey: "didPrimeMic")
        let vm = makeVM(recognizer: HoldingEnRecognizer(partial: nil))
        vm.micPressBegan()
        #expect(vm.isListening)
        vm.micPressEnded()
        #expect(vm.phase == .idle)
        try await Task.sleep(for: .milliseconds(100))             // nothing may resurface later
        #expect(vm.phase == .idle)
        #expect(vm.translations.isEmpty)
        #expect(vm.explanation == nil)
    }

    /// Release must actually SHUT DOWN the capture: the stream is terminated and late audio can't
    /// mutate the input afterwards — a hot-mic regression (submit without stop) fails here.
    @Test func releaseTerminatesCaptureAndIgnoresLateTranscripts() async throws {
        UserDefaults.standard.set(true, forKey: "didPrimeMic")
        UserDefaults.standard.set("russian", forKey: "targetLanguage")
        UserDefaults.standard.set("english", forKey: "studiedLanguage")
        let recognizer = HoldingEnRecognizer(partial: "bank")
        let vm = makeVM(recognizer: recognizer)
        vm.selectMode(.translate)
        vm.micPressBegan()
        try await waitUntil { vm.source == "bank" }
        vm.micPressEnded()
        try await waitUntil { recognizer.terminated }
        #expect(recognizer.terminated)                            // the mic is OFF, not just submitted-from
        recognizer.yield("late words")
        try await waitUntil { vm.phase == .result }
        #expect(vm.source == "bank")                              // late audio never joined the input
    }

    /// A SYSTEM cancel of the hold stops the mic WITHOUT running Translate/Explain.
    @Test func cancelledHoldStopsWithoutSubmitting() async throws {
        UserDefaults.standard.set(true, forKey: "didPrimeMic")
        let recognizer = HoldingEnRecognizer(partial: "bank")
        let vm = makeVM(recognizer: recognizer)
        vm.micPressBegan()
        try await waitUntil { vm.source == "bank" }
        vm.micPressCancelled()
        #expect(vm.phase == .idle)
        try await waitUntil { recognizer.terminated }
        #expect(recognizer.terminated)
        try await Task.sleep(for: .milliseconds(100))             // no request may surface later
        #expect(vm.phase == .idle)
        #expect(vm.translations.isEmpty)
        #expect(vm.explanation == nil)
    }

    /// A press while the mic is ALREADY on (widget auto-start) must not restart the capture — and
    /// the matching release stops and runs the current mode, so a tap ends a routed capture.
    @Test func pressDuringRoutedListeningIsNoOpAndReleaseSubmits() async throws {
        UserDefaults.standard.set(true, forKey: "didPrimeMic")
        let vm = makeVM(recognizer: HoldingEnRecognizer(partial: "bank"))
        vm.beginVoiceInput()                                      // routed (widget): mic on, no finger down
        try await waitUntil { vm.source == "bank" }
        vm.micPressBegan()                                        // tap lands on the live mic
        #expect(vm.isListening)
        #expect(vm.source == "bank")                              // no restart — transcript survived
        vm.micPressEnded()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
    }

    /// Press-originated priming must NOT auto-start (no finger to release); the ROUTED priming
    /// path must (the widget promised a hands-free mic).
    @Test func primingAutoStartsOnlyForRoutedFlow() {
        UserDefaults.standard.removeObject(forKey: "didPrimeMic")
        let pressVM = makeVM(recognizer: HoldingEnRecognizer(partial: nil))
        pressVM.micPressBegan()
        #expect(pressVM.showMicPriming)
        pressVM.confirmPriming()
        #expect(!pressVM.isListening)                             // armed, not started

        UserDefaults.standard.removeObject(forKey: "didPrimeMic")
        let routedVM = makeVM(recognizer: HoldingEnRecognizer(partial: nil))
        routedVM.beginVoiceInput()                                // widget deep link, unprimed
        #expect(routedVM.showMicPriming)
        routedVM.confirmPriming()
        #expect(routedVM.isListening)                             // hands-free promise kept
    }
}

/// A capture stream that behaves like the LIVE mic under push-to-talk: yields a partial (if any)
/// and stays OPEN until the hold ends (task cancellation) — never finishes on its own. Records the
/// termination and allows LATE yields, so tests can assert the release/cancel actually SHUT DOWN
/// the capture (not merely that a submit happened).
private final class HoldingEnRecognizer: SpeechRecognizing, @unchecked Sendable {
    private let partial: String?
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<SpeechTranscript, Error>.Continuation?
    private var terminatedFlag = false

    init(partial: String?) { self.partial = partial }

    /// True once the consumer tore the stream down (the mic is OFF).
    var terminated: Bool { lock.lock(); defer { lock.unlock() }; return terminatedFlag }

    /// Simulate audio arriving AFTER the stream was (or should have been) stopped.
    func yield(_ text: String) {
        lock.lock(); let c = continuation; lock.unlock()
        c?.yield(SpeechTranscript(text: text, isFinal: false))
    }

    func transcribe() -> AsyncThrowingStream<SpeechTranscript, Error> {
        AsyncThrowingStream { continuation in
            continuation.onTermination = { @Sendable _ in
                self.lock.lock(); self.terminatedFlag = true; self.lock.unlock()
            }
            self.lock.lock(); self.continuation = continuation; self.lock.unlock()
            if let partial = self.partial {
                continuation.yield(SpeechTranscript(text: partial, isFinal: false))
            }
            // No finish: the session ends only via onTermination (release cancels the capture task).
        }
    }
}

/// Records whether the Explain template carried an attached image, then defers to the mock for a valid
/// response — proves the See it → Explain handoff sends just the phrase, WITHOUT the source photo.
private final class ExplainImageSpyLLM: LLMClient, @unchecked Sendable {
    nonisolated(unsafe) private(set) var explainHadImage: Bool?
    private let backing = MockLLMClient()
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        if template.id == "explainExpression" { explainHadImage = template.image(for: input) != nil }
        return try await backing.run(template, input: input)
    }
}

/// Fails once (the previous-mode error), then returns a valid translation — verifies that switching
/// mode after a failure re-runs the request on the same input.
private final class FlakyUnderstandLLM: LLMClient, @unchecked Sendable {
    nonisolated(unsafe) private var remaining: Int
    init(failuresBeforeSuccess: Int) { self.remaining = failuresBeforeSuccess }
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        if remaining > 0 { remaining -= 1; throw LLMError.offline }
        return try template.decode(#"{"studied":"bank","variants":[{"text":"банк","context":""}]}"#)
    }
}
