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
    private let model: String          // standard tier (e.g. Sonnet)
    private let fastModel: String      // fast tier (e.g. Haiku) — for simple translation
    private let endpoint: URL
    private let session: URLSession
    private let anthropicVersion = "2023-06-01"
    /// Retries on transient 429/529/5xx with exponential backoff (Anthropic's recommendation).
    private let maxRetries: Int
    private let baseRetryDelay: Double   // seconds
    /// Optional fast-offline probe: if it returns false, we skip the request and throw `.offline` at
    /// once — so `waitsForConnectivity` (below) never strands a truly-offline device on a long wait.
    /// Nil ⇒ no pre-check (the previous behaviour; used by tests). Wired to NWPathMonitor in the app.
    private let isReachable: (@Sendable () -> Bool)?

    public init(
        apiKey: String,
        model: String,
        fastModel: String? = nil,
        baseURL: URL,
        session: URLSession? = nil,
        maxRetries: Int = 3,
        baseRetryDelay: Double = 0.5,
        isReachable: (@Sendable () -> Bool)? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.fastModel = fastModel ?? model   // no fast model configured ⇒ everything on the standard one
        self.endpoint = baseURL.appending(path: "v1/messages")
        // An instance-owned, connectivity-aware session (not the global `.shared`), with explicit
        // timeouts and waits-for-connectivity so brief cellular blips don't kill an in-flight request.
        self.session = session ?? Self.defaultSession()
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
        self.isReachable = isReachable
    }

    private static func defaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        // Flaky cellular (tower handoffs, tunnels, weak signal) drops the path for a second or two,
        // then recovers. `waitsForConnectivity = true` lets URLSession quietly PAUSE and RESUME across
        // those blips instead of failing the instant the path drops — the single biggest lever for
        // "get a result on a bad link". CAVEAT: while waiting for connectivity the per-request
        // timeout does NOT run, so `send` bounds time-to-response-start with its OWN deadline
        // (`withDeadline`) — without it a link that dropped right at send time could sit in
        // "processing" for the full resource timeout. `timeoutIntervalForResource` is the outer
        // ceiling for the whole transfer. A TRULY-offline device is short-circuited before every
        // attempt (the `isReachable` check in `send`), so waiting-for-connectivity never hangs.
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
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
            // Claude's vision API rejects HEIC (the default iPhone format) and oversized images, so
            // normalize to a downscaled JPEG — covers EVERY source (camera, library, share-sheet HEIC).
            // Falls back to the raw bytes + magic-byte media type only if it isn't a decodable image.
            let (bytes, mediaType) = ImageNormalizer.jpegForUpload(imageData)
                .map { ($0, "image/jpeg") } ?? (imageData, Self.mediaType(for: imageData))
            content.append(.image(mediaType: mediaType, base64: bytes.base64EncodedString()))
        }
        content.append(.text(template.userMessage(for: input)))

        // Per-template tuning. None of these tasks need chain-of-thought, so thinking is disabled
        // everywhere — that alone is the big latency win (extended reasoning on a dense photo blew
        // the response out to ~50s+). Short TEXT tasks then run at LOW effort with a tight 30s
        // timeout (fast). The photo translator runs at MEDIUM effort with a larger output budget and
        // a much longer timeout, because OCR-ing + translating a dense page is genuinely a 30–60s job.
        let fast = template.prefersFastResponse
        // Route to the model tier the template asks for: plain translation → fast model (Haiku),
        // everything else → standard (Sonnet). Falls back to the standard model if no fast one is set.
        let modelName = template.modelTier == .fast ? fastModel : model
        // The `effort` knob is only honoured by the reasoning-capable tiers (Opus / Sonnet 4.6+). Haiku
        // 4.5 hard-REJECTS it with HTTP 400 "This model does not support the effort parameter", which
        // would 400 EVERY request routed to the fast model (plain translate defaults to Haiku) — so omit
        // `output_config` entirely whenever the resolved model is Haiku. Locale-independent compare:
        // a machine identifier must match the same way on a Turkish-locale device (dotless-I casing).
        let supportsEffort = !modelName.lowercased().contains("haiku")
        let body = RequestBody(
            model: modelName,
            max_tokens: template.maxOutputTokens,
            system: system,
            messages: [.init(role: "user", content: content)],
            thinking: .init(type: "disabled"),
            output_config: supportsEffort ? .init(effort: fast ? "low" : "medium") : nil
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = fast ? 30 : 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        // Compress the upload when it's big enough to benefit — the photo's base64 image is the win on
        // a slow uplink. Only swap in the gzip body if it's actually SMALLER (tiny text bodies inflate
        // by the gzip envelope). The Anthropic API accepts `Content-Encoding: gzip` request bodies.
        let bodyData = try JSONEncoder().encode(body)
        if bodyData.count >= 1024, let gzipped = bodyData.gzipped(), gzipped.count < bodyData.count {
            request.httpBody = gzipped
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        } else {
            request.httpBody = bodyData
        }

        let message = try await send(request, fast: fast)

        // The model hit its output-token budget and the JSON is truncated mid-stream — surface a
        // clear, actionable error instead of a generic "couldn't parse the response".
        if message.stopReason == "max_tokens" { throw LLMError.responseTooLong }
        let text = message.text
        guard !text.isEmpty else { throw LLMError.invalidOutput("empty model response") }

        // The model can wrap the answer in a preamble before the real object — markdown fences, a
        // restated copy of the schema, or a line of "thinking out loud" (seen on broad inputs). Decode
        // every top-level JSON object found, LAST first (the real answer comes last; an echoed schema
        // or preamble comes first), and return the first that fits the template's type.
        let candidates = Self.jsonObjects(in: text)
        guard !candidates.isEmpty else {
            throw LLMError.invalidOutput("no JSON object in response")
        }
        var lastError: Error = LLMError.invalidOutput("no decodable JSON object in response")
        for candidate in candidates.reversed() {
            do { return try template.decode(candidate) }
            catch { lastError = error }
        }
        throw lastError
    }

    /// The assembled result of one streamed Messages call.
    private struct StreamedMessage {
        let text: String
        let stopReason: String?
    }

    /// Sends the request (streaming) and assembles the response, retrying TRANSIENT failures — both
    /// transport-level (a dropped connection, DNS/host hiccup, TLS reset, a stream cut mid-answer)
    /// and HTTP 429 / 529 / 5xx — with exponential backoff. Mobile networks blip constantly (cell
    /// handoff, weak signal), so a momentary failure recovers silently instead of surfacing as a hard
    /// "Service unavailable"; only a SUSTAINED failure (retries exhausted) is shown.
    private func send(_ request: URLRequest, fast: Bool) async throws -> StreamedMessage {
        var attempt = 0
        while true {
            // Fast-offline, re-checked before EVERY attempt (not just the first): with no network
            // path, fail immediately rather than letting `waitsForConnectivity` wait for a connection
            // that isn't coming — the UI's reconnect auto-retry replays the request when it returns.
            if let isReachable, !isReachable() { throw LLMError.offline }
            // A superseded request cancels its Task; surface that as the dedicated case so callers
            // never show it as a failure (URLError(.cancelled) below covers the in-flight case).
            if Task.isCancelled { throw LLMError.cancelled }
            do {
                // Streaming, with time-to-response-start explicitly bounded. `waitsForConnectivity`
                // SUSPENDS the per-request timeout while (re)establishing a link, so without this
                // deadline a drop right at send time could sit in "processing" for the entire
                // resource timeout (10 min). Once the response starts, chunks arrive continuously and
                // `request.timeoutInterval` bounds the idle gap BETWEEN chunks — so a slow-but-alive
                // generation is never killed for taking long overall (the old non-streaming request
                // counted the whole server-side generation as idle time and timed out healthy calls).
                let session = self.session
                let (bytes, response) = try await Self.withDeadline(seconds: fast ? 30 : 90) {
                    try await session.bytes(for: request)
                }
                guard let http = response as? HTTPURLResponse else {
                    throw LLMError.requestFailed("no HTTP response")
                }
                if (200..<300).contains(http.statusCode) {
                    return try await Self.readStream(bytes)
                }

                // Error status: drain a bounded slice of the body for classification/detail.
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count >= 4096 { break }
                }
                // 401 (missing/invalid key) and 403 (revoked/forbidden key) both mean "fix your key".
                if http.statusCode == 401 || http.statusCode == 403 { throw LLMError.notConfigured }
                let isOverload = http.statusCode == 429 || http.statusCode == 529
                let isRetryable = isOverload || http.statusCode >= 500
                if isRetryable && attempt < maxRetries {
                    attempt += 1
                    try await backoff(attempt: attempt, response: http)
                    continue
                }
                if isOverload { throw LLMError.overloaded }
                // Bound the echoed API error body: it can be large and may contain request content.
                let detail = (String(data: body, encoding: .utf8) ?? "").prefix(200)
                throw LLMError.requestFailed("HTTP \(http.statusCode): \(detail)")
            } catch is CancellationError {
                throw LLMError.cancelled
            } catch let error as LLMError {
                throw error
            } catch let error as URLError {
                if error.code == .cancelled { throw LLMError.cancelled }   // deliberate supersede
                // Retry a transient transport failure before giving up (including a stream that died
                // mid-answer); only map the FINAL one.
                if Self.isRetryableTransport(error.code), attempt < maxRetries {
                    attempt += 1
                    try await backoff(attempt: attempt, response: nil)
                    continue
                }
                if error.code == .timedOut { throw LLMError.timedOut }
                if Self.offlineCodes.contains(error.code) { throw LLMError.offline }
                throw LLMError.requestFailed(error.localizedDescription)
            } catch {
                throw LLMError.requestFailed(error.localizedDescription)
            }
        }
    }

    /// Runs `operation` with a hard wall-clock deadline. Fires `LLMError.timedOut` if the deadline
    /// passes first — used to bound time-to-response-start, which `waitsForConnectivity` otherwise
    /// leaves unbounded (it suspends the per-request timeout while a link is re-established).
    private static func withDeadline<T: Sendable>(
        seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                // A cancelled sleep must NOT masquerade as a deadline hit — checked below.
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            defer { group.cancelAll() }
            guard let first = try await group.next(), let value = first else {
                if Task.isCancelled { throw LLMError.cancelled }   // superseded, not timed out
                throw LLMError.timedOut
            }
            return value
        }
    }

    /// Assembles the streamed SSE response: accumulates `content_block_delta` text and captures the
    /// final `stop_reason`. A server-sent `error` event surfaces as `.requestFailed`.
    private static func readStream(_ bytes: URLSession.AsyncBytes) async throws -> StreamedMessage {
        var text = ""
        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else { continue }
            switch event.type {
            case "content_block_delta":
                if let chunk = event.delta?.text { text += chunk }
            case "message_delta":
                if let reason = event.delta?.stop_reason { stopReason = reason }
            case "error":
                throw LLMError.requestFailed(event.error?.message ?? "stream error")
            default:
                break   // message_start / content_block_start / content_block_stop / ping / message_stop
            }
        }
        return StreamedMessage(text: text, stopReason: stopReason)
    }

    /// Wait before a retry: honor `Retry-After` if present (HTTP retries), else exponential backoff.
    private func backoff(attempt: Int, response: HTTPURLResponse?) async throws {
        let seconds: Double
        if let header = response?.value(forHTTPHeaderField: "Retry-After"), let value = Double(header) {
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

    /// Transient transport failures worth a retry — the connection HAD a path that failed momentarily
    /// (dropped mid-flight, DNS/host hiccup, TLS reset). Deliberately NOT `.timedOut` (the per-request
    /// timeout already gave it a full chance — retrying would double the wait) and NOT the genuine
    /// "no network path" codes in `offlineCodes` (those map straight to `.offline` so the user is told
    /// to check their connection rather than waiting through retries).
    private static func isRetryableTransport(_ code: URLError.Code) -> Bool {
        switch code {
        case .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
             .dnsLookupFailed, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    /// Every top-level, brace-balanced JSON object in `text`, in order of appearance. String-aware —
    /// braces inside string values don't affect nesting — so prose, markdown fences, or a restated
    /// schema surrounding the real object are skipped rather than merged into one unparseable blob (the
    /// old "first `{` … last `}`" did the latter). Returns [] if there is no complete object.
    static func jsonObjects(in text: String) -> [String] {
        var objects: [String] = []
        var depth = 0
        var start: String.Index?
        var inString = false
        var escaped = false
        for i in text.indices {
            let c = text[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
                continue
            }
            switch c {
            case "\"": inString = true
            case "{":
                if depth == 0 { start = i }
                depth += 1
            case "}":
                guard depth > 0 else { break }
                depth -= 1
                if depth == 0, let s = start {
                    objects.append(String(text[s...i]))
                    start = nil
                }
            default: break
            }
        }
        return objects
    }

    /// URLError codes that mean "no usable network path" — all mapped to LLMError.offline so every
    /// consumer can react identically instead of sniffing localized strings.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
    ]

    private static func mediaType(for data: Data) -> String {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"   // PNG magic else JPEG
    }

    // MARK: Wire types
    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        /// Omitted when nil (synthesized `encodeIfPresent`). `{"type":"disabled"}` skips extended
        /// reasoning for fast text tasks; left off for vision so the model can think a little.
        let thinking: Thinking?
        /// Output config — currently just `effort` (low for fast text, medium for vision/long tasks).
        let output_config: OutputConfig?
        /// Always stream: chunks arriving continuously turn the per-request timeout into an
        /// inter-chunk IDLE bound, so a long-but-healthy generation is never killed for total time.
        let stream = true
        struct Message: Encodable { let role: String; let content: [ContentBlock] }
        struct Thinking: Encodable { let type: String }
        struct OutputConfig: Encodable { let effort: String }
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

    /// One SSE event from the streaming Messages API (only the fields we consume).
    private struct StreamEvent: Decodable {
        let type: String
        let delta: Delta?
        let error: APIError?
        struct Delta: Decodable {
            let type: String?
            let text: String?          // content_block_delta (text_delta)
            let stop_reason: String?   // message_delta
        }
        struct APIError: Decodable { let type: String?; let message: String? }
    }
}
