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
    /// Simulate a transport failure: fail the first `failTimes` attempts with `failCode`, then serve normally.
    nonisolated(unsafe) static var failCode: URLError.Code? = nil
    nonisolated(unsafe) static var failTimes = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
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
}
