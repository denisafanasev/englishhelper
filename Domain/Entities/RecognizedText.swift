//
//  RecognizedText.swift
//  EnglishHelper — Domain
//
//  OCR result shape. Carries bounding boxes so the photo-translate overlay can position labels.
//  A cloud OCR backend must return this SAME shape — no Vision/CGRect types leak here.
//

import Foundation

/// A rectangle in normalized [0,1] coordinates with a **top-left** origin (SwiftUI-friendly).
/// Adapters convert from their backend's coordinate space (e.g. Vision's lower-left).
public struct NormalizedRect: Sendable, Equatable, Hashable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// One recognized text run with its location and confidence.
public struct RecognizedTextBlock: Sendable, Equatable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let text: String
    public let boundingBox: NormalizedRect
    /// 0...1 recognizer confidence.
    public let confidence: Double
    public init(id: UUID = UUID(), text: String, boundingBox: NormalizedRect, confidence: Double) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// Full OCR output: the joined text plus per-block boxes.
public struct RecognizedText: Sendable, Equatable, Hashable, Codable {
    /// All blocks joined by newlines — what gets translated.
    public let fullText: String
    public let blocks: [RecognizedTextBlock]
    public init(fullText: String, blocks: [RecognizedTextBlock]) {
        self.fullText = fullText
        self.blocks = blocks
    }
    public var isEmpty: Bool { fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
