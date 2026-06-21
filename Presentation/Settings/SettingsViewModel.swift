//
//  SettingsViewModel.swift
//  EnglishHelper — Presentation
//

import Foundation
import Domain

@MainActor
@Observable
public final class SettingsViewModel {
    public enum Health: Equatable { case checking, ok, failed(String) }

    /// Standard model (Sonnet) — used for everything but plain translation.
    public private(set) var health: Health = .checking
    /// Fast model (Haiku) — used for plain translation. Shown alongside the standard one in Settings.
    public private(set) var fastHealth: Health = .checking
    public let appVersion: String
    public let modelName: String
    public let fastModelName: String

    private let connectionHealth: any ConnectionHealthUseCase

    public init(
        connectionHealth: any ConnectionHealthUseCase,
        appVersion: String,
        modelName: String,
        fastModelName: String
    ) {
        self.connectionHealth = connectionHealth
        self.appVersion = appVersion
        self.modelName = modelName
        self.fastModelName = fastModelName
    }

    /// Probe BOTH models concurrently and surface each status independently.
    public func check() async {
        let prevStandard = health, prevFast = fastHealth
        health = .checking
        fastHealth = .checking
        async let standard = connectionHealth(.standard)
        async let fast = connectionHealth(.fast)
        let (standardResult, fastResult) = await (standard, fast)
        health = Self.resolve(standardResult, previous: prevStandard)
        fastHealth = Self.resolve(fastResult, previous: prevFast)
    }

    private static func resolve(_ result: ConnectionHealth, previous: Health) -> Health {
        switch result {
        case .ok: .ok
        case .failed(let reason): .failed(message(for: reason))
        case .cancelled: previous   // check torn down — restore prior status, no false failure
        }
    }

    private static func message(for reason: ConnectionHealth.Reason) -> String {
        switch reason {
        case .noKey: Loc.t("Нет ключа Claude API", "No Claude API key")
        case .offline: Loc.t("Нет соединения", "No connection")
        case .timeout: Loc.t("Сервис не ответил вовремя", "The service didn't respond in time")
        case .overloaded: Loc.t("Сервис перегружен, попробуйте позже", "Service is overloaded — try later")
        case .badResponse: Loc.t("Неожиданный ответ сервиса", "Unexpected response from the service")
        case .unavailable: Loc.t("Сервис недоступен", "Service unavailable")
        case .unknown: Loc.t("Ошибка подключения", "Connection error")
        }
    }
}
