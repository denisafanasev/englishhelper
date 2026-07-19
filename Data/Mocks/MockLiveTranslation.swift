//
//  MockLiveTranslation.swift
//  EnglishHelper — Data (mock adapters)
//
//  Deterministic `LiveTranslating` + `SessionRecordingsManaging` for tests/previews/mock boots.
//  The mock session mirrors the live contract: it stays OPEN (like a hot mic) until `stop()` is
//  called, then emits `.finished` and completes — so view-model toggle logic is exercised for real.
//

import Foundation
import Domain

public final class MockLiveTranslating: LiveTranslating, @unchecked Sendable {
    /// Canned behavior for one session.
    public struct Script: Sendable {
        public var updates: [LiveTranslationText]
        public var recording: LiveSessionRecording?
        /// Non-nil = the stream throws AFTER the updates (still emitting `.finished` first,
        /// matching the live adapter's partial-save contract).
        public var failure: LiveTranslationError?

        public init(updates: [LiveTranslationText] = MockLiveTranslating.defaultUpdates,
                    recording: LiveSessionRecording? = LiveSessionRecording(fileName: "mock-session.m4a", duration: 12),
                    failure: LiveTranslationError? = nil) {
            self.updates = updates
            self.recording = recording
            self.failure = failure
        }
    }

    public static let defaultUpdates: [LiveTranslationText] = [
        LiveTranslationText(originalFinal: "", originalPending: "Mind the",
                            translationFinal: "", translationPending: ""),
        LiveTranslationText(originalFinal: "Mind the gap.", originalPending: "",
                            translationFinal: "", translationPending: "Осторожно,"),
        LiveTranslationText(originalFinal: "Mind the gap.", originalPending: "",
                            translationFinal: "Осторожно, промежуток.", translationPending: ""),
    ]

    private let script: Script
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<LiveTranslationEvent, Error>.Continuation?

    public init(script: Script = Script()) {
        self.script = script
    }

    public func start(studiedLanguage: String, nativeLanguage: String) -> AsyncThrowingStream<LiveTranslationEvent, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuation = nil
                self.lock.unlock()
            }
            continuation.yield(.listening)
            continuation.yield(.level(0.4))
            for update in script.updates { continuation.yield(.text(update)) }
            if let failure = script.failure {
                continuation.yield(.finished(recording: script.recording))
                continuation.finish(throwing: failure)
            }
            // Otherwise stay open — the "mic" keeps listening until stop().
        }
    }

    public func stop() async {
        let continuation = lock.withLock {
            let held = self.continuation
            self.continuation = nil
            return held
        }
        continuation?.yield(.finished(recording: script.recording))
        continuation?.finish()
    }
}

public final class MockSessionRecordings: SessionRecordingsManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var existing: Set<String>
    private var deletedNames: [String] = []

    public init(existing: Set<String> = []) {
        self.existing = existing
    }

    /// Names passed to `delete` — assert on this in tests.
    public var deleted: [String] {
        lock.lock(); defer { lock.unlock() }
        return deletedNames
    }

    public func exists(fileName: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return existing.contains(fileName)
    }

    public func delete(fileName: String) async {
        lock.withLock {
            existing.remove(fileName)
            deletedNames.append(fileName)
        }
    }

    public func sweep(keeping: Set<String>) async {
        lock.withLock {
            let orphaned = existing.subtracting(keeping)
            existing.subtract(orphaned)
            deletedNames.append(contentsOf: orphaned.sorted())
        }
    }

    public func play(fileName: String) -> AsyncThrowingStream<RecordingPlayback, Error> {
        let known = exists(fileName: fileName)
        return AsyncThrowingStream { continuation in
            guard known else {
                continuation.finish(throwing: RecordingPlaybackError.missing)
                return
            }
            continuation.yield(.playing(progress: 0.5))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
