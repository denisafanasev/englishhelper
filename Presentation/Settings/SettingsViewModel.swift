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
        case .failed(let reason): health = .failed(reason)
        }
    }
}
