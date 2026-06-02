//
//  ClaudeLLMClient.swift
//  EnglishHelper — Data (adapter for LLMClient)
//
//  Anthropic Messages API. Executes any PromptTemplate: injects the system prompt + the template's
//  strict JSON schema, sends the input, then strips fences and typed-decodes via the template.
//  Takes plain config (key/model/url) — NOT AppConfig — so Data stays independent of App.
//

import Foundation
import Domain

public final class ClaudeLLMClient: LLMClient {
    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let session: URLSession
    private let anthropicVersion = "2023-06-01"
    private let maxTokens = 2048
    /// Retries on transient 429/529/5xx with exponential backoff (Anthropic's recommendation).
    private let maxRetries: Int
    private let baseRetryDelay: Double   // seconds

    public init(
        apiKey: String,
        model: String,
        baseURL: URL,
        session: URLSession = .shared,
        maxRetries: Int = 2,
        baseRetryDelay: Double = 0.5
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = baseURL.appending(path: "v1/messages")
        self.session = session
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
    }

    public func run<Template: PromptTemplate>(
        _ template: Template,
        input: Template.Input
    ) async throws -> Template.Output {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }

        let system = """
        \(template.systemPrompt)

        Respond with ONLY a single JSON object that satisfies this schema. No prose, no explanation,
        no markdown code fences:
        \(template.outputJSONSchema)
        """
        var content: [ContentBlock] = []
        if let imageData = template.image(for: input) {
            content.append(.image(mediaType: Self.mediaType(for: imageData),
                                   base64: imageData.base64EncodedString()))
        }
        content.append(.text(template.userMessage(for: input)))

        let body = RequestBody(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [.init(role: "user", content: content)]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await send(request)

        let decoded: MessagesResponse
        do {
            decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        } catch {
            throw LLMError.invalidOutput("unparseable API envelope: \(error)")
        }
        let text = decoded.content.compactMap(\.text).joined()
        guard !text.isEmpty else { throw LLMError.invalidOutput("empty model response") }

        return try template.decode(Self.extractJSON(from: text))
    }

    /// Sends the request, retrying transient 429 / 529 / 5xx with exponential backoff.
    private func send(_ request: URLRequest) async throws -> Data {
        var attempt = 0
        while true {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch is CancellationError {
                throw LLMError.cancelled
            } catch let error as URLError where error.code == .timedOut {
                throw LLMError.requestFailed("timed out")
            } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw LLMError.requestFailed("offline")
            } catch {
                throw LLMError.requestFailed(error.localizedDescription)
            }

            guard let http = response as? HTTPURLResponse else {
                throw LLMError.requestFailed("no HTTP response")
            }
            if (200..<300).contains(http.statusCode) { return data }
            if http.statusCode == 401 { throw LLMError.notConfigured }

            let isOverload = http.statusCode == 429 || http.statusCode == 529
            let isRetryable = isOverload || http.statusCode >= 500
            if isRetryable && attempt < maxRetries {
                attempt += 1
                try await backoff(attempt: attempt, response: http)
                continue
            }
            if isOverload { throw LLMError.overloaded }
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.requestFailed("HTTP \(http.statusCode): \(detail)")
        }
    }

    /// Wait before a retry: honor `Retry-After` if present, else exponential backoff.
    private func backoff(attempt: Int, response: HTTPURLResponse) async throws {
        let seconds: Double
        if let header = response.value(forHTTPHeaderField: "Retry-After"), let value = Double(header) {
            seconds = min(value, 10)
        } else {
            seconds = min(baseRetryDelay * pow(2, Double(attempt - 1)), 8)
        }
        do {
            try await Task.sleep(for: .seconds(seconds))
        } catch {
            throw LLMError.cancelled
        }
    }

    /// Strip markdown fences and isolate the outermost JSON object.
    static func extractJSON(from text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let lo = t.firstIndex(of: "{"), let hi = t.lastIndex(of: "}"), lo <= hi {
            return String(t[lo...hi])
        }
        return t
    }

    private static func mediaType(for data: Data) -> String {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"   // PNG magic else JPEG
    }

    // MARK: Wire types
    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        struct Message: Encodable { let role: String; let content: [ContentBlock] }
    }

    private enum ContentBlock: Encodable {
        case text(String)
        case image(mediaType: String, base64: String)

        private enum CodingKeys: String, CodingKey { case type, text, source }
        private struct ImageSource: Encodable {
            let type = "base64"
            let media_type: String
            let data: String
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try c.encode("text", forKey: .type)
                try c.encode(text, forKey: .text)
            case .image(let mediaType, let base64):
                try c.encode("image", forKey: .type)
                try c.encode(ImageSource(media_type: mediaType, data: base64), forKey: .source)
            }
        }
    }

    private struct MessagesResponse: Decodable {
        let content: [Block]
        struct Block: Decodable { let type: String; let text: String? }
    }
}
