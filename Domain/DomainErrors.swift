//
//  DomainErrors.swift
//  EnglishHelper — Domain
//
//  First-class, backend-agnostic failure types. Adapters in Data MUST translate their
//  framework/transport errors into these — no SDK error types leak across a port.
//

import Foundation

public enum LLMError: Error, Sendable, Equatable {
    case notConfigured              // missing/invalid API key
    case overloaded                 // 429/529 — rate-limited or server overloaded (after retries)
    case requestFailed(String)
    case invalidOutput(String)      // model output did not satisfy the template schema
    case cancelled
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
