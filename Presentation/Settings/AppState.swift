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
        case .formal: Loc.t("Формальный и вежливый", "Formal and polite")
        case .casual: Loc.t("Разговорно-бытовой", "Everyday conversational")
        case .slang: Loc.t("Неформальный, сленговый", "Casual, slangy")
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
        case .system: Loc.t("Система", "System")
        case .light: Loc.t("Светлая", "Light")
        case .dark: Loc.t("Тёмная", "Dark")
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

// MARK: - Interface language (RU / EN, default: system)

public enum AppLanguage: String, CaseIterable, Sendable {
    case system, ru, en
    public var title: String {
        switch self {
        case .system: Loc.t("Системный", "System")
        case .ru: "Русский"
        case .en: "English"
        }
    }
    static let storageKey = "interfaceLanguage"

    public static var preference: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }
    /// The language actually used (system → ru if the device prefers Russian, else en).
    public static var effective: AppLanguage {
        switch preference {
        case .system: (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ru") ? .ru : .en
        case .ru: .ru
        case .en: .en
        }
    }
}

@MainActor
@Observable
public final class LanguageStore {
    public var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey) }
    }
    public init() { language = AppLanguage.preference }
    public var locale: Locale { AppLanguage.effective == .ru ? Locale(identifier: "ru") : Locale(identifier: "en") }
}

/// Tiny runtime localizer — picks Russian or English by the selected interface language.
public enum Loc {
    public static func t(_ ru: String, _ en: String) -> String {
        AppLanguage.effective == .en ? en : ru
    }
}

// MARK: - Target language for "In" translation (RU / EN, default: RU)

public enum TargetLanguage: String, CaseIterable, Sendable {
    case russian, english
    public var title: String {
        switch self {
        case .russian: Loc.t("Русский", "Russian")
        case .english: Loc.t("Английский", "English")
        }
    }
    /// Name used in the LLM prompt.
    public var promptName: String {
        switch self {
        case .russian: "Russian"
        case .english: "English"
        }
    }
    static let storageKey = "targetLanguage"
    public static var current: TargetLanguage {
        TargetLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .russian
    }
}

@MainActor
@Observable
public final class TargetLanguageStore {
    public var language: TargetLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: TargetLanguage.storageKey) }
    }
    public init() { language = TargetLanguage.current }
}
