//
//  NetworkMonitor.swift
//  EnglishHelper — Presentation
//
//  @Observable reachability state for the UI: drives the "no connection" banner and the auto-retry on
//  reconnect. It owns NO platform framework (Presentation must not import Network — that lives in the
//  Adapters layer); the App pushes path updates in via `update(...)`, keeping the dependency rule intact.
//

import Foundation

@MainActor
@Observable
public final class NetworkMonitor {
    /// Whether the device currently has a usable network path. Optimistic at launch (true) until the
    /// first path update, so we never flash "offline" before reachability has actually reported.
    public private(set) var isOnline = true
    /// Constrained path (Low Data Mode) — exposed for callers that may trim payload in future.
    public private(set) var isConstrained = false

    /// Invoked on the main actor when the path transitions offline → online. RootView uses it (via an
    /// `onChange`) to trigger an auto-retry of the last failed request.
    public var onReconnect: (() -> Void)?

    public init() {}

    /// Pushed by the platform reachability adapter (wired in the App composition root). Fires
    /// `onReconnect` exactly on an offline → online edge.
    public func update(isOnline online: Bool, isConstrained constrained: Bool = false) {
        let recovered = online && !isOnline
        isOnline = online
        isConstrained = constrained
        if recovered { onReconnect?() }
    }
}
