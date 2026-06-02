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

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        StubURLProtocol.callCount += 1
        let response = HTTPURLResponse(
            url: request.url!, statusCode: StubURLProtocol.statusCode,
            httpVersion: "HTTP/1.1", headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"type":"error","error":{"type":"overloaded_error"}}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite struct ClaudeLLMClientTests {

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
            _ = try await client.run(TranslateTextTemplate(), input: "hello")
        }
        #expect(StubURLProtocol.callCount == 3)   // 1 initial + 2 retries
    }

    @Test func throwsOverloadedOn429() async {
        StubURLProtocol.statusCode = 429
        StubURLProtocol.callCount = 0
        let client = makeClient(maxRetries: 1)

        await #expect(throws: LLMError.overloaded) {
            _ = try await client.run(TranslateTextTemplate(), input: "hello")
        }
        #expect(StubURLProtocol.callCount == 2)   // 1 initial + 1 retry
    }
}
