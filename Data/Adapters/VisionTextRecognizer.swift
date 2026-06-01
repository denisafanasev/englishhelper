//
//  VisionTextRecognizer.swift
//  EnglishHelper — Data (adapter for TextRecognizing)
//
//  iOS 26 Vision `RecognizeTextRequest`. Returns text WITH normalized (top-left) bounding boxes —
//  the photo-translate overlay needs them. A cloud OCR must return the same `RecognizedText` shape.
//

import Foundation
import Vision
import Domain

public final class VisionTextRecognizer: TextRecognizing {
    private let languages: [Locale.Language]
    public init(languages: [Locale.Language] = [Locale.Language(identifier: "en-US")]) {
        self.languages = languages
    }

    // `Domain.` qualifiers disambiguate from Vision.RecognizedText / Vision.NormalizedRect.
    public func recognizeText(in image: RecognizableImage) async throws -> Domain.RecognizedText {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let observations: [RecognizedTextObservation]
        do {
            observations = try await request.perform(on: image.data)
        } catch is CancellationError {
            throw TextRecognitionError.cancelled
        } catch {
            throw TextRecognitionError.unsupportedImage
        }

        var blocks: [RecognizedTextBlock] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            // Vision uses a lower-left origin; flip to top-left for SwiftUI.
            let rect = observation.boundingBox.verticallyFlipped().cgRect
            blocks.append(RecognizedTextBlock(
                text: candidate.string,
                boundingBox: Domain.NormalizedRect(
                    x: Double(rect.origin.x), y: Double(rect.origin.y),
                    width: Double(rect.size.width), height: Double(rect.size.height)
                ),
                confidence: Double(candidate.confidence)
            ))
        }

        guard !blocks.isEmpty else { throw TextRecognitionError.noTextFound }
        return Domain.RecognizedText(fullText: blocks.map(\.text).joined(separator: "\n"), blocks: blocks)
    }
}
