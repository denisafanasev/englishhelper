//
//  ClaudeLLMClientTests.swift
//  EnglishHelperTests
//
//  ClaudeLLMClient retry/backoff behavior on transient overload (429/529), via a stub URLProtocol.
//

import Testing
import Foundation
import Domain
import Adapters

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 529
    nonisolated(unsafe) static var callCount = 0
    /// When set, returned as the response body (e.g. a 200 Messages envelope); else a canned error.
    nonisolated(unsafe) static var responseBody: Data? = nil
    /// Captures the LAST outgoing request body (de-streamed) so tests can assert what was sent on the wire.
    nonisolated(unsafe) static var lastBody: Data? = nil
    /// Simulate a transport failure: fail the first `failTimes` attempts with `failCode`, then serve normally.
    nonisolated(unsafe) static var failCode: URLError.Code? = nil
    nonisolated(unsafe) static var failTimes = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    /// URLSession hands the protocol the body as a STREAM (httpBody is nil), so drain the stream.
    static func bodyData(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data()
        let size = 8192
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override func startLoading() {
        StubURLProtocol.lastBody = StubURLProtocol.bodyData(of: request)
        StubURLProtocol.callCount += 1
        if let code = StubURLProtocol.failCode, StubURLProtocol.callCount <= StubURLProtocol.failTimes {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: StubURLProtocol.statusCode,
            httpVersion: "HTTP/1.1", headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body = StubURLProtocol.responseBody
            ?? Data(#"{"type":"error","error":{"type":"overloaded_error"}}"#.utf8)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite(.serialized) struct ClaudeLLMClientTests {

    private func makeClient(maxRetries: Int = 2) -> ClaudeLLMClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return ClaudeLLMClient(
            apiKey: "sk-test", model: "claude-sonnet-4-6",
            baseURL: URL(string: "https://api.anthropic.com")!,
            session: URLSession(configuration: config),
            maxRetries: maxRetries, baseRetryDelay: 0.001
        )
    }

    @Test func retriesThenThrowsOverloadedOn529() async {
        StubURLProtocol.statusCode = 529
        StubURLProtocol.callCount = 0
        let client = makeClient(maxRetries: 2)

        await #expect(throws: LLMError.overloaded) {
            _ = try await client.run(UnderstandTemplate(), input: "hello")
        }
        #expect(StubURLProtocol.callCount == 3)   // 1 initial + 2 retries
    }

    @Test func throwsOverloadedOn429() async {
        StubURLProtocol.statusCode = 429
        StubURLProtocol.callCount = 0
        StubURLProtocol.responseBody = nil
        let client = makeClient(maxRetries: 1)

        await #expect(throws: LLMError.overloaded) {
            _ = try await client.run(UnderstandTemplate(), input: "hello")
        }
        #expect(StubURLProtocol.callCount == 2)   // 1 initial + 1 retry
    }

    /// On broad inputs the model sometimes restates the schema and "thinks out loud" BEFORE the real
    /// JSON object. The client must skip that preamble and decode the actual answer (the last object),
    /// not merge everything between the first "{" and last "}" into one unparseable blob.
    @Test func decodesRealObjectDespiteSchemaEchoAndPreamble() async throws {
        let real = #"{"variants":[{"en":"How much does this cost?","register":"formal","context_ru":"Уточнить цену"},{"en":"Do you accept cards?","register":"formal","context_ru":"Способ оплаты"},{"en":"Could I have a receipt?","register":"formal","context_ru":"Попросить чек"}]}"#
        let schemaEcho = #"{"variants":{"type":"array","minItems":3},"required":["variants"]}"#
        let modelText = "\(schemaEcho)\n\nHmm, \"Покупка\" is very general. Let me list useful phrases.\n\n\(real)"
        let envelope = try JSONSerialization.data(
            withJSONObject: ["content": [["type": "text", "text": modelText]]])

        StubURLProtocol.statusCode = 200
        StubURLProtocol.callCount = 0
        StubURLProtocol.responseBody = envelope
        defer { StubURLProtocol.responseBody = nil; StubURLProtocol.statusCode = 529 }

        let client = makeClient()
        let result = try await client.run(
            WhatToSayTemplate(tone: .formal, studiedLanguage: "English", nativeLanguage: "Russian"),
            input: "Покупка"
        )
        #expect(result.variants.count == 3)
        #expect(result.variants.first?.en == "How much does this cost?")
    }

    /// A transient transport blip (e.g. the connection drops mid-request) must be RETRIED with backoff,
    /// not surfaced immediately — so a momentary mobile-network hiccup recovers silently.
    @Test func retriesTransientTransportErrorThenSucceeds() async throws {
        let envelope = try JSONSerialization.data(
            withJSONObject: ["content": [["type": "text", "text": #"{"ok":true}"#]]])
        StubURLProtocol.statusCode = 200
        StubURLProtocol.callCount = 0
        StubURLProtocol.responseBody = envelope
        StubURLProtocol.failCode = .networkConnectionLost
        StubURLProtocol.failTimes = 2                 // first 2 attempts drop, 3rd succeeds
        defer {
            StubURLProtocol.failCode = nil; StubURLProtocol.failTimes = 0
            StubURLProtocol.responseBody = nil; StubURLProtocol.statusCode = 529
        }

        let client = makeClient(maxRetries: 3)
        let ok = try await client.run(HealthCheckTemplate(), input: ())
        #expect(ok)                                   // recovered after the transient failures
        #expect(StubURLProtocol.callCount == 3)       // 2 failed + 1 success
    }

    /// A SUSTAINED transport failure (every attempt drops) must surface as an error only after the
    /// retries are exhausted — proving the blip is retried, not shown immediately.
    @Test func sustainedTransportErrorSurfacesAfterRetries() async {
        StubURLProtocol.callCount = 0
        StubURLProtocol.failCode = .networkConnectionLost
        StubURLProtocol.failTimes = .max             // never recovers
        defer { StubURLProtocol.failCode = nil; StubURLProtocol.failTimes = 0; StubURLProtocol.statusCode = 529 }

        let client = makeClient(maxRetries: 2)
        await #expect(throws: LLMError.self) {
            _ = try await client.run(HealthCheckTemplate(), input: ())
        }
        #expect(StubURLProtocol.callCount == 3)       // 1 initial + 2 retries, THEN the error
    }

    /// Regression: `output_config.effort` must NOT be sent to Haiku — Haiku 4.5 hard-400s on it ("does
    /// not support the effort parameter"), which would break EVERY request routed to the fast model
    /// (plain translate defaults to Haiku). Sonnet (and other reasoning tiers) still receive it.
    @Test func omitsEffortForHaikuButSendsItForSonnet() async throws {
        let envelope = try JSONSerialization.data(
            withJSONObject: ["content": [["type": "text", "text": #"{"ok":true}"#]]])
        StubURLProtocol.statusCode = 200
        StubURLProtocol.responseBody = envelope
        defer {
            StubURLProtocol.responseBody = nil; StubURLProtocol.statusCode = 529; StubURLProtocol.lastBody = nil
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let client = ClaudeLLMClient(
            apiKey: "sk-test", model: "claude-sonnet-4-6", fastModel: "claude-haiku-4-5",
            baseURL: URL(string: "https://api.anthropic.com")!,
            session: URLSession(configuration: config), maxRetries: 1, baseRetryDelay: 0.001
        )

        // Fast tier → routes to Haiku → output_config OMITTED entirely.
        StubURLProtocol.callCount = 0; StubURLProtocol.lastBody = nil
        _ = try await client.run(HealthCheckTemplate(tier: .fast), input: ())
        let haikuBody = try #require(StubURLProtocol.lastBody)
        let haikuJSON = try #require(try JSONSerialization.jsonObject(with: haikuBody) as? [String: Any])
        #expect(haikuJSON["model"] as? String == "claude-haiku-4-5")   // .fast tier really reached the wire
        #expect(haikuJSON["output_config"] == nil)             // ← the fix: no effort to Haiku

        // Standard tier → routes to Sonnet → output_config.effort present.
        StubURLProtocol.callCount = 0; StubURLProtocol.lastBody = nil
        _ = try await client.run(HealthCheckTemplate(tier: .standard), input: ())
        let sonnetBody = try #require(StubURLProtocol.lastBody)
        let sonnetJSON = try #require(try JSONSerialization.jsonObject(with: sonnetBody) as? [String: Any])
        #expect(sonnetJSON["model"] as? String == "claude-sonnet-4-6")
        let effort = (sonnetJSON["output_config"] as? [String: Any])?["effort"] as? String
        #expect(effort == "low")                               // Sonnet still gets effort
    }

    /// Regression for the same root cause: per-template tuning (`maxOutputTokens` / `prefersFastResponse`)
    /// must reach the wire through the GENERIC client. They were declared only in a protocol extension, so
    /// the client statically dispatched to the defaults (2048 / true) and ignored EVERY override — which
    /// silently capped the photo translator's output budget and forced it to low effort.
    @Test func honorsPerTemplateTuningOverridesThroughClient() async throws {
        let envelope = try JSONSerialization.data(
            withJSONObject: ["content": [["type": "text", "text": #"{"ok":true}"#]]])
        StubURLProtocol.statusCode = 200
        StubURLProtocol.responseBody = envelope
        StubURLProtocol.callCount = 0; StubURLProtocol.lastBody = nil
        defer {
            StubURLProtocol.responseBody = nil; StubURLProtocol.statusCode = 529; StubURLProtocol.lastBody = nil
        }

        let client = makeClient()                              // standard model (Sonnet) → effort applies
        _ = try await client.run(TuningProbeTemplate(), input: ())
        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["max_tokens"] as? Int == 7777)            // override honored (was hard-capped at 2048)
        let effort = (json["output_config"] as? [String: Any])?["effort"] as? String
        #expect(effort == "medium")                            // prefersFastResponse=false honored (was "low")
    }
}

/// Overrides every per-template tuning knob, to prove they survive dispatch through the generic client.
private struct TuningProbeTemplate: PromptTemplate {
    typealias Input = Void
    typealias Output = Bool
    let id = "tuningProbe"
    var systemPrompt: String { "probe" }
    var outputJSONSchema: String { #"{"type":"object","properties":{"ok":{"type":"boolean"}},"required":["ok"]}"# }
    func userMessage(for input: Void) -> String { "ping" }
    func decode(_ rawJSON: String) throws -> Bool { true }
    var maxOutputTokens: Int { 7777 }
    var prefersFastResponse: Bool { false }   // a standard-model template → adapter should choose "medium"
    var modelTier: ModelTier { .standard }
}
