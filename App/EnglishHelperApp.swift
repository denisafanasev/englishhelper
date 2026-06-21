//
//  EnglishHelperApp.swift
//  EnglishHelper — App (entry point)
//

import SwiftUI
import Presentation

@main
struct EnglishHelperApp: App {
    /// Composition root. Boots LIVE adapters. `bootLive` already degrades a failed on-disk store to
    /// an in-memory one (flagged via `usingFallbackStore` → a visible banner), so the only way it
    /// throws is a total SwiftData failure; mocks are the last-resort so the app still opens.
    private let container: AppContainer

    init() {
        let config = AppConfig.load()
        do {
            container = try AppContainer.bootLive(config: config)
        } catch {
            container = AppContainer.bootMock(config: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                out: container.makeVoiceViewModel(),        // "Out": RU → 3 English variants
                inbound: container.makeInViewModel(),        // "In": any/English → 1 translation
                photo: container.makePhotoTranslateViewModel(),
                library: container.makeStudyListViewModel(),
                history: container.makeHistoryViewModel(),
                settings: container.makeSettingsViewModel(),
                degradedStorage: container.usingFallbackStore
            )
        }
    }
}
