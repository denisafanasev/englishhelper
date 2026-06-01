//
//  MockTextRecognizing.swift
//  EnglishHelper — Data (mock adapter)
//

import Domain   // no `import Foundation` — would make `Expression` ambiguous (unused here anyway).

public final class MockTextRecognizing: TextRecognizing {
    private let cannedText: String
    public init(cannedText: String = "Please mind the gap between the train and the platform.") {
        self.cannedText = cannedText
    }

    public func recognizeText(in image: RecognizableImage) async throws -> RecognizedText {
        let block = RecognizedTextBlock(
            text: cannedText,
            boundingBox: NormalizedRect(x: 0.08, y: 0.42, width: 0.84, height: 0.10),
            confidence: 0.97
        )
        return RecognizedText(fullText: cannedText, blocks: [block])
    }
}
