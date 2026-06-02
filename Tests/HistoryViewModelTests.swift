//
//  HistoryViewModelTests.swift
//  EnglishHelperTests
//
//  "История" view-model: load seeded → loaded; empty → empty.
//

import Testing
import Foundation
import Domain
import Adapters
import Presentation

@Suite @MainActor struct HistoryViewModelTests {

    @Test func loadSeededShowsLoaded() async {
        let repo = MockHistoryRepository(seed: [
            HistoryEntry(inputText: "I appreciate it", result: .translate(ru: "Я ценю это")),
            HistoryEntry(inputText: "как сказать привет",
                         result: .howToSay([PhraseVariant(en: "Hi", register: .casual, contextRU: "неформально")])),
        ])
        let vm = HistoryViewModel(history: RequestHistoryInteractor(history: repo))
        await vm.load()
        #expect(vm.phase == .loaded)
        #expect(vm.entries.count == 2)
    }

    @Test func loadEmptyShowsEmpty() async {
        let vm = HistoryViewModel(history: RequestHistoryInteractor(history: MockHistoryRepository(seed: [])))
        await vm.load()
        #expect(vm.phase == .empty)
    }
}
