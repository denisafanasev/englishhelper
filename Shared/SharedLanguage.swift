//
//  SharedLanguage.swift
//  EnglishHelper — Shared (compiled into the app, the Share Extension, and tests)
//
//  The app's interface language lives in `UserDefaults.standard`, which an extension CANNOT read (it's
//  a different sandbox). This mirrors it through the App Group so the Share Extension can localize the
//  notification it posts. The app writes it (on launch / when it changes); the extension reads it,
//  falling back to the system language, then English.
//

import Foundation

public enum SharedLanguage {
    private static let key = "interfaceLanguage"
    private static var store: UserDefaults? { UserDefaults(suiteName: SharedInbox.appGroupID) }

    /// App side: mirror the current interface-language code (e.g. "ru") into the App Group.
    public static func mirror(_ code: String) { store?.set(code, forKey: key) }

    /// Extension side: the mirrored interface language, or the system language, or English.
    public static func current() -> String {
        if let code = store?.string(forKey: key), !code.isEmpty { return code }
        return Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
    }
}
