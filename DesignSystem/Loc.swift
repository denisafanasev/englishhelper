//
//  Loc.swift
//  EnglishHelper — DesignSystem
//
//  Runtime interface-language resolution + the DesignSystem-local localizer. Lives in DesignSystem
//  (the lowest UI layer) so BOTH DesignSystem components (`DSLoc`) and Presentation (`Loc`, which
//  forwards here) share ONE resolver and ONE translation catalog.
//
//  Russian + English are supplied inline at each call site (`t(ru, en)`); French + Spanish come from
//  `LocCatalog`, keyed by the exact English string. A missing key falls back to English.
//

import Foundation

/// Which interface language is in effect, resolved from the user's stored choice or the system.
public enum AppLocale {
    public static let storageKey = "interfaceLanguage"
    /// The interface languages the app ships, as ISO 639-1 codes.
    public static let supported = ["ru", "en", "fr", "es"]

    /// First system-preferred language we support, else English. Used when the user hasn't chosen.
    public static func systemDefaultCode() -> String {
        for language in Locale.preferredLanguages {
            let code = String(language.prefix(2)).lowercased()
            if supported.contains(code) { return code }
        }
        return "en"
    }

    /// The language actually used: the user's stored choice if it's one we support; otherwise the
    /// system default among supported; otherwise English. (An obsolete stored value like the old
    /// "system" is treated as "not chosen".)
    public static func currentCode() -> String {
        if let stored = UserDefaults.standard.string(forKey: storageKey), supported.contains(stored) {
            return stored
        }
        return systemDefaultCode()
    }
}

public enum DSLoc {
    /// Russian + English inline; French/Spanish from `LocCatalog` (English key), English fallback.
    public static func t(_ ru: String, _ en: String) -> String {
        t(ru, en, LocCatalog.fr[en] ?? en, LocCatalog.es[en] ?? en)
    }

    /// Explicit four-language variant — for strings with interpolation that can't be table-keyed.
    public static func t(_ ru: String, _ en: String, _ fr: String, _ es: String) -> String {
        switch AppLocale.currentCode() {
        case "ru": return ru
        case "fr": return fr
        case "es": return es
        default:   return en
        }
    }
}
