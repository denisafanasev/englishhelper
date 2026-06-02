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
        return PresentableError(message: "Что-то пошло не так. Попробуйте ещё раз.", isOffline: false)
    }
    switch llm {
    case .notConfigured:
        return PresentableError(message: "Нет ключа Claude API. Добавьте его, чтобы продолжить.", isOffline: true)
    case .overloaded:
        return PresentableError(message: "Сервис перегружен, попробуйте позже.", isOffline: false)
    case .requestFailed(let info) where info.contains("offline"):
        return PresentableError(message: "Нет соединения. Проверьте интернет и попробуйте снова.", isOffline: true)
    case .requestFailed(let info) where info.contains("timed out"):
        return PresentableError(message: "Сервис не ответил вовремя. Попробуйте ещё раз.", isOffline: false)
    case .invalidOutput:
        return PresentableError(message: "Не удалось разобрать ответ. Попробуйте ещё раз.", isOffline: false)
    case .cancelled:
        return PresentableError(message: "Запрос отменён.", isOffline: false)
    case .requestFailed:
        return PresentableError(message: "Сервис недоступен. Попробуйте позже.", isOffline: false)
    }
}
