//
//  StorageUsageTests.swift
//  EnglishHelperTests
//
//  Disk-usage reporting (Settings): the SwiftData reader sums cache/history row contents and the
//  recordings directory's actual file sizes; the interactor degrades to zero without a reader.
//

import Testing
import Foundation
import SwiftData
import Domain
import Adapters

@Suite struct StorageUsageTests {

    private func makeContainer() throws -> ModelContainer {
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PersistenceSchema.current, configurations: memory)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "StorageUsageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func emptyStoreAndEmptyRecordingsReportZero() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let reader = StorageUsageReader(modelContainer: try makeContainer(), recordingsDirectory: dir)
        #expect(await reader.usage() == .zero)
    }

    @Test func sumsCacheHistoryAndAudioSeparately() async throws {
        let container = try makeContainer()
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Cache: one entry through the real adapter → key bytes + payload bytes.
        let cache = SwiftDataTranslationCache(modelContainer: container)
        let payload = Data(repeating: 7, count: 100)
        await cache.setValue(payload, forKey: "key")
        let expectedCache = payload.count + "key".utf8.count

        // History: one entry through the real adapter → input bytes + result-JSON bytes.
        let history = SwiftDataHistoryRepository(modelContainer: container, recordings: nil)
        let result = RequestResult.translate(ru: "привет")
        try await history.append(HistoryEntry(inputText: "hello", result: result))
        let expectedHistory = try JSONEncoder().encode(result).count + "hello".utf8.count

        // Audio: two files of known size in the recordings directory.
        try Data(repeating: 1, count: 10).write(to: dir.appending(path: "a.m4a"))
        try Data(repeating: 2, count: 20).write(to: dir.appending(path: "b.m4a"))

        let usage = await StorageUsageReader(modelContainer: container, recordingsDirectory: dir).usage()
        #expect(usage.cacheBytes == expectedCache)
        #expect(usage.historyBytes == expectedHistory)
        #expect(usage.audioBytes == 30)
        #expect(usage.totalBytes == expectedCache + expectedHistory + 30)
    }

    @Test func interactorWithoutReaderReportsZero() async {
        #expect(await StorageUsageInteractor(reader: nil)() == .zero)
    }
}
