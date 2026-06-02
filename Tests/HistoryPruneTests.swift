//
//  HistoryPruneTests.swift
//  EnglishHelperTests
//
//  SwiftDataHistoryRepository keeps only the newest `maxEntries` requests.
//

import Testing
import Foundation
import SwiftData
import Domain
import Adapters

@Suite struct HistoryPruneTests {

    @Test func keepsOnlyNewestEntries() async throws {
        let container = try ModelContainer(
            for: HistoryModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataHistoryRepository(modelContainer: container)

        let overflow = SwiftDataHistoryRepository.maxEntries + 5
        for i in 0..<overflow {
            try await repo.append(HistoryEntry(inputText: "q\(i)", result: .translate(ru: "r\(i)")))
        }

        let all = try await repo.recent(limit: overflow + 100)
        #expect(all.count == SwiftDataHistoryRepository.maxEntries)
    }
}
