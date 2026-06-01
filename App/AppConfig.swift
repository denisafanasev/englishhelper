//
//  AppConfig.swift
//  EnglishHelper — App
//
//  Reads the Claude API key + model from the app's Info.plist, which is populated at build time
//  from `Secrets.xcconfig` (gitignored). See `Secrets.example.xcconfig`.
//
//  SECURITY NOTE: an Anthropic key embedded in a distributed app IS extractable. That is fine for
//  this personal/dev, single-user app; a production build would route requests through a backend proxy.
//

import Foundation

public struct AppConfig: Sendable {
    public let claudeAPIKey: String?
    public let claudeModel: String
    public let claudeBaseURL: URL

    public static let defaultModel = "claude-sonnet-4-6"
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!

    public init(claudeAPIKey: String?, claudeModel: String, claudeBaseURL: URL) {
        self.claudeAPIKey = claudeAPIKey
        self.claudeModel = claudeModel
        self.claudeBaseURL = claudeBaseURL
    }

    /// `true` when a non-empty API key is present (the live LLM adapter can run).
    public var isClaudeConfigured: Bool { (claudeAPIKey?.isEmpty == false) }

    public static func load(bundle: Bundle = .main) -> AppConfig {
        let info = bundle.infoDictionary
        func string(_ key: String) -> String? {
            guard let value = info?[key] as? String, !value.isEmpty else { return nil }
            return value
        }
        return AppConfig(
            claudeAPIKey: string("CLAUDE_API_KEY"),
            claudeModel: string("CLAUDE_MODEL") ?? defaultModel,
            claudeBaseURL: string("CLAUDE_BASE_URL").flatMap(URL.init(string:)) ?? defaultBaseURL
        )
    }
}
