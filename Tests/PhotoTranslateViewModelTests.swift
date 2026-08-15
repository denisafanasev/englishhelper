//
//  PhotoTranslateViewModelTests.swift
//  EnglishHelperTests
//
//  "Фото-перевод" (LLM vision): blocks of en+ru, no-text mapping, optimistic per-block save.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite(.serialized) @MainActor struct PhotoTranslateViewModelTests {

    /// The mode is persisted so the screen reopens as last used; each test starts from the default,
    /// not whatever a previous test (or app run on this simulator) left behind.
    init() { UserDefaults.standard.removeObject(forKey: "seeItMode") }

    private func makeVM(llm: any LLMClient = MockLLMClient(),
                        history: MockHistoryRepository = MockHistoryRepository()) -> PhotoTranslateViewModel {
        let repo = MockExpressionRepository(seed: [])
        return PhotoTranslateViewModel(
            photoTranslate: PhotoTranslateInteractor(llm: llm, history: history),
            photoExplain: PhotoExplainInteractor(llm: llm, history: history),
            pronounce: PlayPronunciationInteractor(synthesizer: MockSpeechSynthesizing()),
            saveExpression: SaveExpressionInteractor(
                enrich: EnrichExpressionInteractor(llm: llm), repository: repo
            ),
            studyList: StudyListInteractor(repository: repo),
            isConfigured: true
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

    /// The chosen mode is persisted: a fresh view model (next launch) starts in the last-used mode.
    @Test func modePersistsAcrossInstances() {
        let vm = makeVM()
        vm.selectMode(.translate)
        #expect(makeVM().mode == .translate)
    }

    /// A ROUTED mode change (shared-in image, widget deep link) applies for the session but must
    /// never overwrite the persisted selector choice — only an explicit on-screen tap does.
    @Test func routedModeIsSessionOnly() {
        let vm = makeVM()
        vm.routeMode(.translate)
        #expect(vm.mode == .translate)          // applied now…
        #expect(makeVM().mode == .explain)      // …but the next launch keeps the saved default
    }

    /// Explain is the default mode — a photo yields a scene explanation, not text blocks.
    @Test func explainModeIsDefaultAndProducesExplanation() async throws {
        let vm = makeVM()
        #expect(vm.mode == .explain)                 // default + first in the selector
        #expect(PhotoTranslateViewModel.Mode.allCases.first == .explain)
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.blocks.isEmpty)                   // no translate blocks in explain mode
        #expect(vm.explanation != nil)
        #expect(vm.explanation?.title.isEmpty == false)
        #expect(vm.explanation?.details.isEmpty == false)
    }

    /// Both See-it modes land in history: Explain writes a photoExplain entry (title + details).
    @Test func explainModeAppendsToHistory() async throws {
        let history = MockHistoryRepository()
        let vm = makeVM(history: history)
        vm.didPickFromLibrary(Data())                // default mode = Explain
        try await waitUntil { vm.phase == .result }
        let entries = try await history.recent(limit: 5)
        #expect(entries.count == 1)
        guard case .photoExplain(let title, let details) = entries.first?.result else {
            Issue.record("expected a photoExplain entry, got \(String(describing: entries.first))")
            return
        }
        #expect(title == vm.explanation?.title)
        #expect(details == vm.explanation?.details)
        #expect(entries.first?.inputText == title)   // the title doubles as the row's input text
    }

    @Test func photoExplainSurvivesCodingRoundTrip() throws {
        let result = RequestResult.photoExplain(title: "Blue plaque", details: "Marks a notable resident.")
        let decoded = try JSONDecoder().decode(RequestResult.self, from: JSONEncoder().encode(result))
        #expect(decoded == result)
        #expect(decoded.kind == .photoExplain)
    }

    @Test func producesBlocks() async throws {
        let vm = makeVM()
        vm.selectMode(.translate)
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.blocks.isEmpty == false)
        #expect(vm.blocks.allSatisfy { !$0.en.isEmpty && !$0.ru.isEmpty })
        #expect(vm.explanation == nil)               // translate mode → no explanation
    }

    @Test func noTextFoundMapsToFriendlyError() async throws {
        let vm = makeVM(llm: EmptyBlocksLLM())
        vm.selectMode(.translate)
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline == false)
        #expect(vm.errorMessage?.isEmpty == false)
        // Recognition is LLM-run (non-deterministic), so a re-run of the same photo is offered.
        #expect(vm.canRetry)
    }

    /// A recognition failure (no text found) must offer a retry of the SAME photo — the LLM may
    /// simply have misfired — and the retry must be able to succeed.
    @Test func retryAfterRecognitionFailureReRunsTheSamePhoto() async throws {
        let image = Data([0x0A, 0x0B])
        let vm = makeVM(llm: FlakyEmptyBlocksLLM(emptiesBeforeSuccess: 1))
        vm.selectMode(.translate)
        vm.didPickFromLibrary(image)
        try await waitUntil { vm.phase == .failed }
        #expect(vm.imageData == image)   // the photo is retained, not lost
        #expect(vm.canRetry)
        vm.retry()
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.blocks.isEmpty == false)
        #expect(vm.imageData == image)
    }

    @Test func toggleSaveMarksBlockSaved() async throws {
        let vm = makeVM()
        vm.selectMode(.translate)
        vm.didPickFromLibrary(Data())
        try await waitUntil { vm.phase == .result }
        let block = try #require(vm.blocks.first)
        vm.toggleSave(block)
        #expect(vm.isSaved(block))   // optimistic, immediate
    }

    /// A connection failure during processing must NOT lose the photo, and must offer a retry.
    @Test func connectionFailureKeepsImageAndAllowsRetry() async throws {
        let image = Data([0x01, 0x02, 0x03, 0xFF])
        let vm = makeVM(llm: OfflineLLM())
        vm.selectMode(.translate)
        vm.didPickFromLibrary(image)
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        #expect(vm.isOffline)
        #expect(vm.imageData == image)   // the photo is retained, not lost
        #expect(vm.canRetry)             // a retry of the same photo is offered
    }

    /// Retry re-runs the SAME photo; once the connection recovers it succeeds.
    @Test func retryReusesTheSameImageAndSucceeds() async throws {
        let image = Data([0xAB, 0xCD])
        let vm = makeVM(llm: FlakyLLM(failuresBeforeSuccess: 1))
        vm.selectMode(.translate)
        vm.didPickFromLibrary(image)
        try await waitUntil { vm.phase == .failed }
        #expect(vm.canRetry)
        vm.retry()                       // no need to re-pick the photo
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.blocks.isEmpty == false)
        #expect(vm.imageData == image)   // still the same photo
    }

    /// Hopping Explain ↔ Translate over the SAME photo reuses each mode's earlier result instead
    /// of re-running the request: exactly two model runs land in history, the cached results (and
    /// the optimistic saved flag) survive the round-trip, and the switch back is instant (phase
    /// stays .result — never .processing).
    @Test func switchingModesReusesCachedResultsWithoutRepeatRequests() async throws {
        let history = MockHistoryRepository()
        let vm = makeVM(history: history)
        vm.didPickFromLibrary(Data([0x01]))                       // Explain (default) runs
        try await waitUntil { vm.phase == .result }
        let cachedExplanation = try #require(vm.explanation)

        vm.selectMode(.translate)                                 // first visit → runs
        try await waitUntil { vm.phase == .result && !vm.blocks.isEmpty }
        #expect(vm.explanation == cachedExplanation)              // explain cache survived the run
        let block = try #require(vm.blocks.first)
        vm.toggleSave(block)

        vm.selectMode(.explain)                                   // cached → instant, no request
        #expect(vm.phase == .result)                              // synchronously — process() would say .processing
        #expect(vm.explanation == cachedExplanation)

        vm.selectMode(.translate)                                 // cached → instant, no request
        #expect(vm.phase == .result)
        #expect(vm.blocks.first == block)
        #expect(vm.isSaved(block))                                // saved flag survived the round-trip

        let runs = try await history.recent(limit: 10).count
        #expect(runs == 2)                                        // one explain + one translate, no repeats
    }

    /// A NEW photo invalidates BOTH modes' caches — switching mode after it must re-run, not show
    /// the previous photo's cached result.
    @Test func newPhotoDropsBothModeCaches() async throws {
        let vm = makeVM()
        vm.didPickFromLibrary(Data([0x01]))                       // Explain runs on photo 1
        try await waitUntil { vm.phase == .result }
        vm.selectMode(.translate)                                 // Translate runs on photo 1
        try await waitUntil { vm.phase == .result && !vm.blocks.isEmpty }

        vm.didPickFromLibrary(Data([0x02]))                       // NEW photo, translate mode
        #expect(vm.explanation == nil)                            // photo 1's explain cache is gone
        try await waitUntil { vm.phase == .result }
        vm.selectMode(.explain)                                   // must RUN for photo 2, not restore photo 1's
        #expect(vm.phase == .processing)
        try await waitUntil { vm.phase == .result }
        #expect(vm.explanation != nil)
    }

    /// Switching mode after a FAILURE must re-run the same photo (not stay stuck on the error).
    @Test func switchingModeAfterFailureReRunsOnTheSamePhoto() async throws {
        let vm = makeVM(llm: FlakyLLM(failuresBeforeSuccess: 1))   // default mode Explain → first run fails
        vm.didPickFromLibrary(Data([0x09]))
        try await waitUntil { vm.phase == .failed }
        #expect(vm.phase == .failed)
        vm.selectMode(.translate)                                  // switch → must retry the same photo
        try await waitUntil { vm.phase == .result }
        #expect(vm.phase == .result)
        #expect(vm.blocks.isEmpty == false)
    }
}

/// Always fails with a connection error — exercises the "photo kept + retry offered" path.
private struct OfflineLLM: LLMClient {
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        throw LLMError.offline
    }
}

/// Fails `failuresBeforeSuccess` times, then returns one translated block — simulates a recovered link.
/// The view model calls this sequentially (fail, then retry), so the unguarded counter is safe here.
private final class FlakyLLM: LLMClient, @unchecked Sendable {
    nonisolated(unsafe) private var remaining: Int
    init(failuresBeforeSuccess: Int) { self.remaining = failuresBeforeSuccess }
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        if remaining > 0 {
            remaining -= 1
            throw LLMError.offline
        }
        return try template.decode(#"{"blocks":[{"en":"Caution","ru":"Осторожно"}]}"#)
    }
}

/// Returns an empty-blocks result regardless of input — used to exercise the no-text path.
private struct EmptyBlocksLLM: LLMClient {
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        try template.decode(#"{"blocks":[]}"#)
    }
}

/// Returns empty blocks (→ noTextFound) `emptiesBeforeSuccess` times, then a real block — simulates
/// an LLM recognition misfire that succeeds on retry. Called sequentially, so the counter is safe.
private final class FlakyEmptyBlocksLLM: LLMClient, @unchecked Sendable {
    nonisolated(unsafe) private var remaining: Int
    init(emptiesBeforeSuccess: Int) { self.remaining = emptiesBeforeSuccess }
    func run<Template: PromptTemplate>(_ template: Template, input: Template.Input) async throws -> Template.Output {
        if remaining > 0 {
            remaining -= 1
            return try template.decode(#"{"blocks":[]}"#)
        }
        return try template.decode(#"{"blocks":[{"en":"Exit","ru":"Выход"}]}"#)
    }
}
