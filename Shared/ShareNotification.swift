//
//  ShareNotification.swift
//  EnglishHelper — Shared (compiled into the app, the Share Extension, and tests)
//
//  iOS intentionally bars an app extension from foregrounding its host app: the old `openURL:`
//  responder-chain hack is force-failed on iOS 18+ ("…needs to migrate to the non-deprecated
//  UIApplication.open…. Force returning false"). Apple's sanctioned alternative (per DTS) is for the
//  extension to post a LOCAL NOTIFICATION the user taps to bring the app forward. This builds that
//  notification's localized text. Pure + Foundation-only so it compiles into the extension and is unit
//  testable; the App Group payload (SharedInbox) carries the actual photo/text, so the notification is
//  only the tappable "come to the foreground" trigger.
//

import Foundation

public enum ShareNotification {
    /// Stable id for the posted notification, so the app can clear it once the payload is consumed.
    public static let requestIdentifier = "englishhelper.share.ready"

    /// (title, body) for a freshly-shared item. `isImage` picks the See it / Get it wording; `language`
    /// is the app's interface language (mirrored into the App Group), falling back to English.
    public static func text(isImage: Bool, language: String) -> (title: String, body: String) {
        let title = "Gist It"
        let body: String
        switch language {
        case "ru": body = isImage ? "Фото готово — нажмите, чтобы перевести"
                                   : "Текст готов — нажмите, чтобы объяснить"
        case "de": body = isImage ? "Foto bereit – tippen, um zu übersetzen"
                                   : "Text bereit – tippen, um zu erklären"
        case "it": body = isImage ? "Foto pronta — tocca per tradurre"
                                   : "Testo pronto — tocca per spiegare"
        case "fr": body = isImage ? "Photo prête — touchez pour traduire"
                                   : "Texte prêt — touchez pour expliquer"
        case "es": body = isImage ? "Foto lista — toca para traducir"
                                   : "Texto listo — toca para explicar"
        default:   body = isImage ? "Photo ready — tap to translate"
                                   : "Text ready — tap to explain"
        }
        return (title, body)
    }
}
