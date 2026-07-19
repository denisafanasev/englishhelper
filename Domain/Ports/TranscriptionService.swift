//
//  TranscriptionService.swift
//  EnglishHelper — Domain (port)
//
//  Cloud transcription service (Soniox) backing the online-translation feature. Backend-agnostic:
//  leaks no SDK/transport types. For now the port covers only the connection probe that Settings
//  shows; the online-translation use cases will extend it.
//

public enum TranscriptionServiceError: Error, Sendable, Equatable {
    case notConfigured    // no API key present
    case unauthorized     // the service rejected the key
    case offline
    case timedOut
    case unavailable      // server error / overload
    case badResponse
    case cancelled
}

public protocol TranscriptionServiceChecking: Sendable {
    /// Cheapest possible AUTHENTICATED round-trip to the service, so Settings can show a live
    /// connection status. Throws `TranscriptionServiceError`.
    func ping() async throws
}
