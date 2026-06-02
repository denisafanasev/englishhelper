//
//  Loc.swift
//  EnglishHelper — DesignSystem
//
//  DesignSystem-local runtime localizer. Reads the same interface-language preference as the app
//  (DesignSystem can't import Presentation), so component strings switch RU/EN together with the UI.
//

import Foundation

public enum DSLoc {
    public static func t(_ ru: String, _ en: String) -> String {
        let preference = UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "system"
        let isEnglish: Bool
        switch preference {
        case "ru": isEnglish = false
        case "en": isEnglish = true
        default: isEnglish = !(Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ru")
        }
        return isEnglish ? en : ru
    }
}
