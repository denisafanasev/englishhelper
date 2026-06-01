# Prompt 1 — INIT / SCAFFOLD

> Run AFTER Prompt 0 (token extraction) is committed. Produces a compilable skeleton only — no feature logic.
> APP_NAME = EnglishHelper.

---

# Task: scaffold the iOS project EnglishHelper — skeleton only, NO feature logic

You are a staff iOS engineer. Set up a clean, compilable project skeleton. Do NOT implement
features yet — establish architecture, boundaries, and DI so v1 can be built on top.
Personal-use app, single user.

## Target
- iOS 26, Swift 6, SwiftUI, Xcode 26. Min deployment iOS 26.0.
- Concurrency: async/await + actors. Persistence: SwiftData. Online-first (network assumed).

## Architecture — Clean Architecture, dependency rule strictly inward
Separate folders/modules:
- `Domain`        — entities + use-case protocols + port protocols + prompt-template definitions.
                    ZERO framework imports.
- `Data`          — adapters implementing Domain ports (LLM, speech, OCR, repositories, exporter).
- `Presentation`  — SwiftUI views + view models (MVVM), consumes use cases only.
- `DesignSystem`  — components built on `DesignSystem/Tokens.swift` (extracted in Prompt 0).
- `App`           — composition root, DI container, AppConfig, entry point.

## Design system
- Design tokens ALREADY exist at `DesignSystem/Tokens.swift` (extracted from the design system).
  Treat them as the single source of truth. Build DesignSystem components on top of them.
  Do NOT regenerate, rename, or reinterpret tokens. Components and screens must reference these
  tokens, NEVER raw values. If a needed token is missing, ask — do not invent placeholder values.

## Domain entities
- `Expression`   — curated study-list item:
                   `{ en, ru, example, synonyms: [String], context, learned, createdAt }`.
                   FLAT — no SRS, no intervals, no review state. This list is a staging area
                   exported to an external app (AlgoApp).
- `HistoryEntry` — every request made: `{ kind, inputText, result, createdAt }`, where
                   kind ∈ { howToSay, translate, photoTranslate }. result is a typed enum payload.

## Ports to define in Domain (protocols only, no impl)
- `LLMClient`            — execute a prompt template with input → typed structured result.
- `SpeechRecognizing`    — RU audio → transcript stream.
- `SpeechSynthesizing`   — EN text → playback (state-reporting).
- `TextRecognizing`      — image → recognized EN text (OCR).
- `ExpressionRepository` — CRUD for study-list items.
- `HistoryRepository`    — append + fetch request history.
- `DeckExporting`        — export expressions → a shareable deck file (format-agnostic).

## Prompt-template layer (domain concept, NOT strings in the adapter)
Define a `PromptTemplate` abstraction: each use case owns its own system prompt + strict output
schema + decoder. v1 templates:
- `howToSay`        : RU intent → `{ "variants": [ { "en", "register":formal|neutral|casual|slang,
                      "context_ru" } ] }` (exactly 3 variants).
- `translateText`   : EN text → `{ "ru" }` (pure translation, no commentary).
- `photoTranslate`  : EN OCR text → `{ "ru" }` (same pure-translation schema as translateText).
- `enrichCard`      : `{ en }` (+ optional ru) → `{ "ru", "example", "synonyms": [str] }` (2-3 synonyms).
                      Rules baked into the system prompt:
                        - example: ONE natural English sentence using the expression.
                        - synonyms: 2-3 English near-equivalents; fewer if none fit — do NOT invent bad ones.
                        - all string values plain text ONLY: no markdown, bold, italic, emoji,
                          quotes, or decorative symbols inside any field.
Adding a 4th use case = adding a template, without touching ClaudeLLMClient.

## Port design contract (SpeechRecognizing / SpeechSynthesizing / TextRecognizing)
These three are long-lived extension points. Each port MUST:
- express ONLY domain intent; zero leakage of backend types/SDK enums/transport — no AVFoundation /
  Speech / Vision / URLSession types in signatures.
- be satisfiable by BOTH an on-device AND a network/cloud impl without changing the protocol.
  If a signature fits only one, it leaks — redesign it.
- model async + cancellation + failure as first-class (async throws / AsyncStream + domain Error enum).
- carry a one-line comment naming a hypothetical 2nd backend it must support
  (e.g. SpeechSynthesizing → "AVSpeech today, ElevenLabs cloud tomorrow").

## Config
- `AppConfig` reads Claude API key + model (Sonnet) + base URL from a gitignored `Secrets.xcconfig`.
  Commit a `Secrets.example.xcconfig` template.
- README flag: an Anthropic key inside a distributed app is extractable — fine for personal/dev
  use, production would need a backend proxy.

## Info.plist
Configure usage description strings up front (the app crashes at runtime without them):
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

## Deliverable for THIS step
- Project compiles and launches to a placeholder screen.
- All Domain ports + prompt templates defined; each port has a `Mock*` impl in Data so the app
  builds and DI wires up.
- DI container in `App` injecting mocks.
- `git init`, sensible `.gitignore` (incl. Secrets.xcconfig, build artifacts).
- Seed `CLAUDE.md`: overview, architecture map, folder layout, `## Current Status`.
- Output a short tree of what you created and confirm it builds.

Constraints: no business logic, no UI beyond placeholder, no third-party deps unless a native API
genuinely doesn't exist. Justify any dependency in one line.
