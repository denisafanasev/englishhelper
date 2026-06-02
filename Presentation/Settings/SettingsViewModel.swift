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

    public private(set) var health: Health = .checking
    public let appVersion: String
    public let modelName: String
    public let voiceLanguage: String

    private let connectionHealth: any ConnectionHealthUseCase

    public init(
        connectionHealth: any ConnectionHealthUseCase,
        appVersion: String,
        modelName: String,
        voiceLanguage: String = "English (US)"
    ) {
        self.connectionHealth = connectionHealth
        self.appVersion = appVersion
        self.modelName = modelName
        self.voiceLanguage = voiceLanguage
    }

    public func check() async {
        health = .checking
        switch await connectionHealth() {
        case .ok: health = .ok
        case .failed(let reason): health = .failed(Self.message(for: reason))
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
