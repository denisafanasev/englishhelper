//
//  ConnectionUseCase.swift
//  EnglishHelper — Domain (use case)
//
//  Live connection health for Settings — runs the cheapest possible LLM round-trip and maps any
//  failure to a domain status.
//

import Foundation

public enum ConnectionHealth: Sendable, Equatable {
    case ok
    case failed(Reason)

    /// Localizable failure reasons (the UI maps these to text).
    public enum Reason: Sendable, Equatable {
        case noKey, offline, timeout, overloaded, badResponse, unavailable, unknown
    }
}

public protocol ConnectionHealthUseCase: Sendable {
    func callAsFunction() async -> ConnectionHealth
}

public struct ConnectionHealthInteractor: ConnectionHealthUseCase {
    private let llm: LLMClient
    public init(llm: LLMClient) { self.llm = llm }

    public func callAsFunction() async -> ConnectionHealth {
        do {
            _ = try await llm.run(HealthCheckTemplate(), input: ())
            return .ok
        } catch let error as LLMError {
            switch error {
            case .notConfigured: return .failed(.noKey)
            case .overloaded: return .failed(.overloaded)
            case .requestFailed(let info) where info.contains("offline"): return .failed(.offline)
            case .requestFailed(let info) where info.contains("timed out"): return .failed(.timeout)
            case .requestFailed: return .failed(.unavailable)
            case .invalidOutput: return .failed(.badResponse)
            case .cancelled: return .failed(.unknown)
            }
        } catch {
            return .failed(.unknown)
        }
    }
}
