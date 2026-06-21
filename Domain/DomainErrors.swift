//
//  DomainErrors.swift
//  EnglishHelper — Domain
//
//  First-class, backend-agnostic failure types. Adapters in Data MUST translate their
//  framework/transport errors into these — no SDK error types leak across a port.
//

import Foundation

public enum LLMError: Error, Sendable, Equatable {
    case notConfigured              // missing/invalid/revoked API key (401/403)
    case overloaded                 // 429/529 — rate-limited or server overloaded (after retries)
    case offline                    // no usable network path (DNS/host/data/roaming/not-connected)
    case timedOut                   // the request did not complete within the timeout
    case requestFailed(String)      // any other transport/HTTP failure (detail is diagnostic, NOT a category)
    case invalidOutput(String)      // model output did not satisfy the template schema
    case cancelled                  // superseded / task cancelled — never a real failure
}

public enum SpeechRecognitionError: Error, Sendable, Equatable {
    case permissionDenied
    case unavailable
    case noSpeechDetected
    case cancelled
    case underlying(String)
}

public enum SpeechSynthesisError: Error, Sendable, Equatable {
    case unavailable
    case cancelled
    case underlying(String)
}

public enum TextRecognitionError: Error, Sendable, Equatable {
    case noTextFound
    case unsupportedImage
    case cancelled
    case underlying(String)
}

public enum RepositoryError: Error, Sendable, Equatable {
    case notFound
    case persistenceFailed(String)
}

public enum ExportError: Error, Sendable, Equatable {
    case nothingToExport
    case encodingFailed(String)
}
