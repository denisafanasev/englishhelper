//
//  ReachabilityMonitor.swift
//  EnglishHelper — Data (Adapters)
//
//  NWPathMonitor lives here (Network is a platform engine framework — forbidden in Presentation). Two
//  consumers: the LLM client reads `isReachable` (thread-safe) for its fast-offline short-circuit, and
//  the App forwards `onChange` into Presentation's @Observable NetworkMonitor for the banner/auto-retry.
//

import Foundation
import Network

public final class ReachabilityMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.englishhelper.reachability")
    private let lock = NSLock()
    private var _isReachable = true
    private var _isConstrained = false
    private let onChange: @Sendable (_ isReachable: Bool, _ isConstrained: Bool) -> Void

    /// Thread-safe snapshot — safe to read from any thread/actor (the client's pre-check runs off-main).
    public var isReachable: Bool { lock.lock(); defer { lock.unlock() }; return _isReachable }

    /// - Parameter onChange: called on every path update (off the main thread) with the latest state.
    ///   The App hops to the main actor and forwards it to the UI `NetworkMonitor`.
    public init(onChange: @escaping @Sendable (_ isReachable: Bool, _ isConstrained: Bool) -> Void) {
        self.onChange = onChange
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let reachable = path.status == .satisfied
            let constrained = path.isConstrained
            self.lock.lock(); self._isReachable = reachable; self._isConstrained = constrained; self.lock.unlock()
            self.onChange(reachable, constrained)
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
