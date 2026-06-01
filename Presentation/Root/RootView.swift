//
//  RootView.swift
//  EnglishHelper — Presentation
//

import SwiftUI
import Domain

/// The app's root. v1 screens (Voice / Study / Camera) replace the placeholder in Step 2.
public struct RootView: View {
    @State private var model: RootViewModel

    public init(model: RootViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        PlaceholderView(status: model.status, expressionCount: model.expressionCount)
            .task { await model.load() }
    }
}
