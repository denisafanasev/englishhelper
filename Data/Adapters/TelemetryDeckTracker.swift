//
//  TelemetryDeckTracker.swift
//  EnglishHelper — Data (live analytics adapter)
//
//  The ONLY place in the codebase that touches the TelemetryDeck SDK (enforced by
//  ForbiddenImportTests for Domain/Presentation). TelemetryDeck is privacy-first: no ATT/IDFA,
//  no device fingerprinting — so there is no tracking-consent prompt anywhere in the app.
//  We send bare signal names only (see `AnalyticsEvent`) — never user content.
//

import Foundation
import Domain
import TelemetryDeck

public struct TelemetryDeckTracker: AnalyticsTracking {

    /// One-time SDK setup — call from the app entry point (`@main` init) BEFORE the first signal.
    /// The SDK is linked into this module only, so the composition root initializes it through
    /// this wrapper rather than importing TelemetryDeck itself.
    public static func initialize(appID: String) {
        TelemetryDeck.initialize(config: .init(appID: appID))
    }

    public init() {}

    /// Fire-and-forget: `TelemetryDeck.signal` is thread-safe, queues internally, and never throws —
    /// analytics can't slow down or fail a use case.
    public func track(_ event: AnalyticsEvent) {
        TelemetryDeck.signal(event.rawValue)
    }
}
