//
//  AppState.swift
//  EnglishHelper — Presentation
//
//  App-wide UI state shared above the tabs: theme preference (persisted) and the Settings sheet flag.
//

import SwiftUI
import Domain

/// Preferred tone/register for generated phrases ("Как сказать" / "Текст").
public enum ToneOfVoice: String, CaseIterable, Sendable {
    case formal, casual, slang
    public var title: String {
        switch self {
        case .formal: "Формальный и вежливый"
        case .casual: "Разговорно-бытовой"
        case .slang: "Неформальный, сленговый"
        }
    }
    public var register: Register {
        switch self {
        case .formal: .formal
        case .casual: .casual
        case .slang: .slang
        }
    }
    /// Read the persisted preference (shared key, also read by the view models at generation time).
    public static var current: ToneOfVoice {
        ToneOfVoice(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .casual
    }
    static let storageKey = "toneOfVoice"
}

@MainActor
@Observable
public final class ToneStore {
    public var tone: ToneOfVoice {
        didSet { UserDefaults.standard.set(tone.rawValue, forKey: ToneOfVoice.storageKey) }
    }
    public init() { tone = ToneOfVoice.current }
}

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
