//
//  MockTextRecognizing.swift
//  EnglishHelper — Data (mock adapter)
//

import Foundation
import Domain

public final class MockTextRecognizing: TextRecognizing {
    private let cannedText: String
    public init(cannedText: String = "Please mind the gap between the train and the platform.") {
        self.cannedText = cannedText
    }

    public func recognizeText(in image: RecognizableImage) async throws -> String {
        cannedText
    }
}
