//
//  MockAnalytics.swift
//  EnglishHelper — Data (mock adapter)
//
//  Records tracked events in memory so tests can assert WHICH event a use case reported (and that
//  failures report none). Lock-guarded because `track` is synchronous and may be called from any
//  task; reads snapshot under the same lock.
//

import Foundation
import Domain

public final class MockAnalyticsTracker: AnalyticsTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [AnalyticsEvent] = []

    public init() {}

    public func track(_ event: AnalyticsEvent) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(event)
    }

    /// All events tracked so far, in call order.
    public var events: [AnalyticsEvent] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }
}
