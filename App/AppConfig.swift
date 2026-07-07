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
    public let claudeModel: String       // standard tier (Sonnet) — used for everything but plain translate
    public let claudeFastModel: String   // fast tier (Haiku) — used for plain translation, for speed
    public let claudeBaseURL: URL
    /// TelemetryDeck App ID (NOT a secret — it only routes signals to our dashboard). Lives in the
    /// xcconfig alongside the Claude key for one-place config; nil (absent) just disables analytics.
    public let telemetryDeckAppID: String?

    public static let defaultModel = "claude-sonnet-5"
    public static let defaultFastModel = "claude-haiku-4-5"
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!

    public init(claudeAPIKey: String?, claudeModel: String,
                claudeFastModel: String = defaultFastModel, claudeBaseURL: URL,
                telemetryDeckAppID: String? = nil) {
        self.claudeAPIKey = claudeAPIKey
        self.claudeModel = claudeModel
        self.claudeFastModel = claudeFastModel
        self.claudeBaseURL = claudeBaseURL
        self.telemetryDeckAppID = telemetryDeckAppID
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
            claudeFastModel: string("CLAUDE_FAST_MODEL") ?? defaultFastModel,
            claudeBaseURL: string("CLAUDE_BASE_URL").flatMap(URL.init(string:)) ?? defaultBaseURL,
            telemetryDeckAppID: string("TELEMETRYDECK_APP_ID")
        )
    }
}
