//
//  EnglishHelperApp.swift
//  EnglishHelper — App (entry point)
//

import SwiftUI
import Presentation

@main
struct EnglishHelperApp: App {
    /// Composition root. Step 1 boots entirely on mocks.
    private let container = AppContainer.bootMock()

    var body: some Scene {
        WindowGroup {
            RootView(model: container.makeRootViewModel())
        }
    }
}
