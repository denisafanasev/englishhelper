//
//  MockTranscriptionService.swift
//  EnglishHelper — Data (mock adapter)
//

import Domain

public struct MockTranscriptionService: TranscriptionServiceChecking {
    /// Nil = ping succeeds; set to make every ping fail with that error.
    private let failure: TranscriptionServiceError?
    public init(failure: TranscriptionServiceError? = nil) { self.failure = failure }

    public func ping() async throws {
        if let failure { throw failure }
    }
}
