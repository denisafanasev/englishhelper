//
//  PresentableError.swift
//  EnglishHelper — Presentation
//
//  Maps domain errors to a user-facing message + offline flag, shared by the request screens.
//

import Foundation
import Domain

struct PresentableError {
    let message: String
    let isOffline: Bool
}

func presentableError(_ error: Error) -> PresentableError {
    guard let llm = error as? LLMError else {
        return PresentableError(message: Loc.t("Что-то пошло не так. Попробуйте ещё раз.",
                                               "Something went wrong. Try again."), isOffline: false)
    }
    switch llm {
    case .notConfigured:
        return PresentableError(message: Loc.t("Нет ключа Claude API. Добавьте его, чтобы продолжить.",
                                               "No Claude API key. Add one to continue."), isOffline: true)
    case .overloaded:
        return PresentableError(message: Loc.t("Сервис перегружен, попробуйте позже.",
                                               "Service is overloaded — try later."), isOffline: false)
    case .offline:
        return PresentableError(message: Loc.t("Нет соединения. Проверьте интернет и попробуйте снова.",
                                               "No connection. Check the internet and try again."), isOffline: true)
    case .timedOut:
        return PresentableError(message: Loc.t("Сервис не ответил вовремя. Попробуйте ещё раз.",
                                               "The service didn't respond in time. Try again."), isOffline: false)
    case .responseTooLong:
        return PresentableError(message: Loc.t("Слишком много текста для одного запроса. Попробуйте часть поменьше.",
                                               "Too much text to handle at once. Try a smaller part."), isOffline: false)
    case .invalidOutput:
        return PresentableError(message: Loc.t("Не удалось разобрать ответ. Попробуйте ещё раз.",
                                               "Couldn't parse the response. Try again."), isOffline: false)
    case .cancelled:
        return PresentableError(message: Loc.t("Запрос отменён.", "Request cancelled."), isOffline: false)
    case .requestFailed:
        return PresentableError(message: Loc.t("Сервис недоступен. Попробуйте позже.",
                                               "Service unavailable. Try later."), isOffline: false)
    }
}
