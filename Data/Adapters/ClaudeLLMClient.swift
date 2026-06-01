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
    private let maxTokens = 1024

    public init(apiKey: String, model: String, baseURL: URL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = baseURL.appending(path: "v1/messages")
        self.session = session
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
        let body = RequestBody(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [.init(role: "user", content: template.userMessage(for: input))]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

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
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 { throw LLMError.notConfigured }
            throw LLMError.requestFailed("HTTP \(http.statusCode): \(detail)")
        }

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

    // MARK: Wire types
    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        struct Message: Encodable { let role: String; let content: String }
    }
    private struct MessagesResponse: Decodable {
        let content: [Block]
        struct Block: Decodable { let type: String; let text: String? }
    }
}
