//
//  AppState.swift
//  EnglishHelper — Presentation
//
//  App-wide UI state shared above the tabs: theme preference (persisted) and the Settings sheet flag.
//

import SwiftUI

public enum ThemePreference: String, CaseIterable, Sendable {
    case system, light, dark
    public var title: String {
        switch self {
        case .system: "Система"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }
}

@MainActor
@Observable
public final class ThemeStore {
    public var preference: ThemePreference {
        didSet { UserDefaults.standard.set(preference.rawValue, forKey: Self.key) }
    }

    private static let key = "themePreference"

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        preference = raw.flatMap(ThemePreference.init(rawValue:)) ?? .system
    }

    public var colorScheme: ColorScheme? {
        switch preference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
public final class AppUIState {
    public var showSettings = false
    public init() {}
}
