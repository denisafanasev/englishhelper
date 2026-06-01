//
//  TextRecognizing.swift
//  EnglishHelper — Domain (port)
//

import Foundation

/// A backend-agnostic image payload: raw encoded bytes only, so no `UIImage`/`CGImage`/`Vision`
/// type ever leaks into the Domain.
public struct RecognizableImage: Sendable, Equatable {
    public let data: Data
    public init(data: Data) { self.data = data }
}

/// Recognizes English text in an image (OCR).
///
/// Backend note: Apple `Vision` (on-device) today, a cloud OCR tomorrow — both accept encoded
/// image bytes and return plain text, so the signature fits either.
public protocol TextRecognizing: Sendable {
    /// Recognize text in `image`. Throws `TextRecognitionError`.
    func recognizeText(in image: RecognizableImage) async throws -> String
}
