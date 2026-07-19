//
//  SonioxClient.swift
//  EnglishHelper — Data (live adapter)
//
//  Soniox (soniox.com) speech-to-text REST API. Currently implements only the Settings health
//  probe: the cheapest authenticated call is GET /v1/models (list STT models), which validates both
//  reachability and the API key (401 on a bad key). The online-translation use cases will extend
//  this client.
//

import Foundation
import Domain

public struct SonioxClient: TranscriptionServiceChecking {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession

    public static let defaultBaseURL = URL(string: "https://api.soniox.com")!

    public init(apiKey: String, baseURL: URL = defaultBaseURL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    public func ping() async throws {
        guard !apiKey.isEmpty else { throw TranscriptionServiceError.notConfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw TranscriptionServiceError.cancelled
            case .timedOut: throw TranscriptionServiceError.timedOut
            case _ where Self.offlineCodes.contains(error.code): throw TranscriptionServiceError.offline
            default: throw TranscriptionServiceError.unavailable
            }
        } catch is CancellationError {
            throw TranscriptionServiceError.cancelled
        }

        guard let http = response as? HTTPURLResponse else { throw TranscriptionServiceError.badResponse }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403: throw TranscriptionServiceError.unauthorized
        case 429, 500...: throw TranscriptionServiceError.unavailable
        default: throw TranscriptionServiceError.badResponse
        }
    }

    /// Same "no usable network path" set as ClaudeLLMClient, so both services report offline identically.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
    ]
}
