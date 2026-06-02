//
//  EnglishHelperApp.swift
//  EnglishHelper — App (entry point)
//

import SwiftUI
import Presentation

@main
struct EnglishHelperApp: App {
    /// Composition root. Boots LIVE adapters; falls back to mocks if persistence can't initialize
    /// so the app always launches.
    private let container: AppContainer

    init() {
        let config = AppConfig.load()
        if let live = try? AppContainer.bootLive(config: config) {
            container = live
        } else {
            container = AppContainer.bootMock(config: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                voice: container.makeVoiceViewModel(),
                translate: container.makeTranslateViewModel()
            )
        }
    }
}
