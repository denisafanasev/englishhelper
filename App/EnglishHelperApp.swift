//
//  EnglishHelperApp.swift
//  EnglishHelper — App (entry point)
//

import SwiftUI
import Adapters
import Presentation

@main
struct EnglishHelperApp: App {
    /// Composition root. Boots LIVE adapters. `bootLive` already degrades a failed on-disk store to
    /// an in-memory one (flagged via `usingFallbackStore` → a visible banner), so the only way it
    /// throws is a total SwiftData failure; mocks are the last-resort so the app still opens.
    private let container: AppContainer
    /// UI reachability state (@Observable) — drives the offline banner + auto-retry in RootView.
    private let network: NetworkMonitor
    /// Platform reachability (NWPathMonitor, Adapters layer). Retained here so it stays alive; its
    /// thread-safe `isReachable` backs the LLM client's fast-offline pre-check, and its updates are
    /// forwarded to `network` for the UI.
    private let reachability: ReachabilityMonitor

    init() {
        let config = AppConfig.load()
        let networkUI = NetworkMonitor()
        network = networkUI
        // NWPathMonitor (Adapters) pushes every path change to the UI monitor on the main actor.
        reachability = ReachabilityMonitor { online, constrained in
            Task { @MainActor in networkUI.update(isOnline: online, isConstrained: constrained) }
        }
        let probe = reachability
        do {
            container = try AppContainer.bootLive(
                config: config,
                isReachable: { [weak probe] in probe?.isReachable ?? true }
            )
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
                degradedStorage: container.usingFallbackStore,
                network: network,
                consumeShared: {
                    // Bridge the App-Group payload (App target) to the Presentation route type.
                    switch SharedInbox.consume() {
                    case .text(let text): return .explainText(text)
                    case .image(let data): return .explainImage(data)
                    case nil: return nil
                    }
                }
            )
        }
    }
}
