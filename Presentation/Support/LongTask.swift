//
//  LongTask.swift
//  EnglishHelper — Presentation
//
//  Lets a slow LLM operation keep running briefly after the app is backgrounded and post a "result
//  ready" notification when it finishes in the background — so the user can leave the app during a long
//  recognition / explanation and tap back in to the SAME screen, where the retained view model already
//  shows the result. The platform work (background-task assertion + notification) lives in the App layer
//  behind `LongTaskCoordinating`; this file is Foundation-only so Presentation keeps its no-platform rule.
//

import Foundation

/// Which long operation completed — drives the notification copy.
public enum LongTaskKind: String, Sendable, CaseIterable {
    case photoTranslate, photoExplain, explanation, translation

    /// Localized (title, body) for the completion notification. `language` is the app interface language.
    public func notification(language: String) -> (title: String, body: String) {
        let title = "EnglishHelper"
        let isTranslate = (self == .photoTranslate || self == .translation)
        let body: String
        switch language {
        case "ru": body = isTranslate ? "Перевод готов — откройте, чтобы посмотреть"
                                       : "Объяснение готово — откройте, чтобы посмотреть"
        case "de": body = isTranslate ? "Übersetzung fertig – zum Ansehen öffnen"
                                       : "Erklärung fertig – zum Ansehen öffnen"
        case "it": body = isTranslate ? "Traduzione pronta — apri per vedere"
                                       : "Spiegazione pronta — apri per vedere"
        case "fr": body = isTranslate ? "Traduction prête — ouvrez pour voir"
                                       : "Explication prête — ouvrez pour voir"
        case "es": body = isTranslate ? "Traducción lista — abre para ver"
                                       : "Explicación lista — abre para ver"
        default:   body = isTranslate ? "Translation ready — open to view"
                                       : "Explanation ready — open to view"
        }
        return (title, body)
    }
}

/// Implemented in the App layer (it needs UIKit + UserNotifications). Keeps the app alive briefly after
/// it backgrounds while a long op runs, and posts a completion notification if the op finishes while the
/// app is in the background (when it's foreground the user already sees the result, so nothing is posted).
@MainActor public protocol LongTaskCoordinating: AnyObject {
    /// Begin tracking a long op (starts a background-task assertion). Returns a token to pass to `end`.
    func begin(_ kind: LongTaskKind) -> Int
    /// End the op. If `success` AND the app is currently backgrounded, post the completion notification.
    func end(_ token: Int, success: Bool)
}

/// Run `operation` under a background-task assertion + completion notification (when a coordinator is
/// injected). On ANY throw — including cancellation (a superseded request) — the op ends WITHOUT
/// notifying. A nil coordinator (tests / previews) makes this a transparent pass-through.
@MainActor
public func withBackgroundCompletion<T>(
    _ coordinator: (any LongTaskCoordinating)?,
    _ kind: LongTaskKind,
    _ operation: () async throws -> T
) async throws -> T {
    let token = coordinator?.begin(kind)
    do {
        let result = try await operation()
        if let token { coordinator?.end(token, success: true) }
        return result
    } catch {
        if let token { coordinator?.end(token, success: false) }
        throw error
    }
}
