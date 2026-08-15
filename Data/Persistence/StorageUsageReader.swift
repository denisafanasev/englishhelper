//
//  StorageUsageReader.swift
//  EnglishHelper — Data (SwiftData + files)
//
//  Disk usage for Settings (`StorageUsageReading`): cache and history are summed from the row
//  CONTENTS (key/input text + payload JSON) — all three tables share ONE SQLite file, so per-kind
//  file sizes don't exist and SQLite overhead can't be attributed — while session audio is the
//  actual size of the files in the recordings directory. Everything is best-effort: a failed read
//  contributes zero rather than failing the Settings screen.
//

import Foundation
import SwiftData
import Domain

@ModelActor
public actor StorageUsageReader: StorageUsageReading {
    /// Nil → the shared SessionRecordings directory (same resolution as the recorder/player).
    /// Tests inject a temp directory so the numbers are deterministic on any host.
    /// `var`, not `let`: the optional needs the implicit nil default so the @ModelActor-generated
    /// `init(modelContainer:)` still compiles (same pattern as SwiftDataHistoryRepository).
    private var recordingsDirectory: URL?

    /// Designated init with the directory override (@ModelActor only generates
    /// `init(modelContainer:)`, which leaves `recordingsDirectory` nil).
    public init(modelContainer: ModelContainer, recordingsDirectory: URL?) {
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
        self.recordingsDirectory = recordingsDirectory
    }

    public func usage() async -> StorageUsage {
        // Row counts are capped (cache 500, history 200), so loading the payloads to sum them is cheap.
        let cacheBytes = ((try? modelContext.fetch(FetchDescriptor<CachedTranslationModel>())) ?? [])
            .reduce(0) { $0 + $1.value.count + $1.key.utf8.count }
        let historyBytes = ((try? modelContext.fetch(FetchDescriptor<HistoryModel>())) ?? [])
            .reduce(0) { $0 + $1.resultData.count + $1.inputText.utf8.count }
        return StorageUsage(cacheBytes: cacheBytes, historyBytes: historyBytes, audioBytes: audioBytes())
    }

    private func audioBytes() -> Int {
        guard let dir = recordingsDirectory ?? (try? RecordingsDirectory.url()),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}
