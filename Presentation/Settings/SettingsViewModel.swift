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
    /// Soniox (speech-to-text — online translation). Third status row in Settings.
    public private(set) var sonioxHealth: Health = .checking
    public let appVersion: String
    public let modelName: String
    public let fastModelName: String
    /// Soniox real-time model (online translation) — shown like the Claude models.
    public let sonioxModelName: String
    /// Translation-cache usage shown in Settings (entries stored + times served from cache).
    public private(set) var cacheStats = TranslationCacheStats(entryCount: 0, hitCount: 0)

    private let connectionHealth: any ConnectionHealthUseCase
    private let transcriptionHealth: any TranscriptionHealthUseCase
    private let cacheAdmin: any TranslationCacheAdminUseCase

    public init(
        connectionHealth: any ConnectionHealthUseCase,
        transcriptionHealth: any TranscriptionHealthUseCase,
        cacheAdmin: any TranslationCacheAdminUseCase,
        appVersion: String,
        modelName: String,
        fastModelName: String,
        sonioxModelName: String
    ) {
        self.connectionHealth = connectionHealth
        self.transcriptionHealth = transcriptionHealth
        self.cacheAdmin = cacheAdmin
        self.appVersion = appVersion
        self.modelName = modelName
        self.fastModelName = fastModelName
        self.sonioxModelName = sonioxModelName
    }

    public func loadCacheStats() async { cacheStats = await cacheAdmin.stats() }

    public func clearCache() async {
        await cacheAdmin.clear()
        cacheStats = await cacheAdmin.stats()
    }

    /// Probe both Claude models AND Soniox concurrently; surface each status independently.
    public func check() async {
        let prevStandard = health, prevFast = fastHealth, prevSoniox = sonioxHealth
        health = .checking
        fastHealth = .checking
        sonioxHealth = .checking
        async let standard = connectionHealth(.standard)
        async let fast = connectionHealth(.fast)
        async let soniox = transcriptionHealth()
        let (standardResult, fastResult, sonioxResult) = await (standard, fast, soniox)
        health = Self.resolve(standardResult, previous: prevStandard, service: "Claude")
        fastHealth = Self.resolve(fastResult, previous: prevFast, service: "Claude")
        sonioxHealth = Self.resolve(sonioxResult, previous: prevSoniox, service: "Soniox")
    }

    private static func resolve(_ result: ConnectionHealth, previous: Health, service: String) -> Health {
        switch result {
        case .ok: .ok
        case .failed(let reason): .failed(message(for: reason, service: service))
        case .cancelled: previous   // check torn down — restore prior status, no false failure
        }
    }

    private static func message(for reason: ConnectionHealth.Reason, service: String) -> String {
        switch reason {
        case .noKey: Loc.t("Нет ключа \(service) API", "No \(service) API key")
        case .unauthorized: Loc.t("Сервис не принял ключ API", "The service rejected the API key")
        case .offline: Loc.t("Нет соединения", "No connection")
        case .timeout: Loc.t("Сервис не ответил вовремя", "The service didn't respond in time")
        case .overloaded: Loc.t("Сервис перегружен, попробуйте позже", "Service is overloaded — try later")
        case .badResponse: Loc.t("Неожиданный ответ сервиса", "Unexpected response from the service")
        case .unavailable: Loc.t("Сервис недоступен", "Service unavailable")
        case .unknown: Loc.t("Ошибка подключения", "Connection error")
        }
    }
}
