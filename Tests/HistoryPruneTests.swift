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

    /// `.translate` and `.photoTranslate` carry the SAME payload shape and are distinguished only by
    /// the synthesized Codable case key — lock that so a case rename/encoding change can't silently
    /// merge them (which would mislabel photo translations as plain translations in History).
    @Test func translateAndPhotoTranslateStayDistinctAcrossCoding() throws {
        let translate = RequestResult.translate(ru: "привет")
        let photo = RequestResult.photoTranslate(ru: "привет")
        #expect(translate != photo)
        #expect(translate.kind == .translate)
        #expect(photo.kind == .photoTranslate)

        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let translate2 = try decoder.decode(RequestResult.self, from: encoder.encode(translate))
        let photo2 = try decoder.decode(RequestResult.self, from: encoder.encode(photo))
        #expect(translate2 == translate)
        #expect(photo2 == photo)
        #expect(translate2 != photo2)            // distinction survives the encode→decode round-trip
        #expect(photo2.kind == .photoTranslate)
    }
}
