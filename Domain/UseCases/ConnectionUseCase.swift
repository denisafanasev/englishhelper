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
    case failed(String)
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
            case .notConfigured:
                return .failed("Нет ключа Claude API")
            case .requestFailed(let info) where info.contains("offline"):
                return .failed("Нет соединения")
            case .requestFailed(let info) where info.contains("timed out"):
                return .failed("Сервис не ответил вовремя")
            case .requestFailed:
                return .failed("Сервис недоступен")
            case .invalidOutput:
                return .failed("Неожиданный ответ сервиса")
            case .cancelled:
                return .failed("Проверка отменена")
            }
        } catch {
            return .failed("Ошибка подключения")
        }
    }
}
