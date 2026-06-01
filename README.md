# EnglishHelper

Personal-use iOS app for learning English from Russian — Voice ("how do I say…?"), Translate
(EN→RU), and Camera (OCR→RU). Curated phrases go into a flat study list exported to AlgoApp.

iOS 26 · Swift 6 · SwiftUI · SwiftData · Clean Architecture (framework module per layer).
See `CLAUDE.md` for the full architecture map.

## Build & run

```sh
cp Secrets.example.xcconfig Secrets.xcconfig   # first time: fill in CLAUDE_API_KEY
brew install xcodegen                           # if needed
xcodegen generate
open EnglishHelper.xcodeproj                     # ⌘R
```

The `.xcodeproj` is generated from `project.yml` (gitignored). Build/test from the CLI:

```sh
xcodebuild -scheme EnglishHelper -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test -scheme EnglishHelper -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Security note
`AppConfig` reads the Claude key from `Secrets.xcconfig` (gitignored) via the app's Info.plist.
**A key embedded in a built app is extractable** — fine for personal/dev use; production would
proxy Claude through a backend.

## Swapping an engine (one line)

Every backend is wired in exactly one place — the composition root, `App/AppContainer.swift`,
`bootLive(config:)`. The Domain and Presentation layers never learn which backend is wired, so
swapping an engine touches exactly ONE registration line. The current lines:

```swift
speechRecognizer: NativeSpeechRecognizer(),     // ← swap ASR engine here
speechSynthesizer: NativeSpeechSynthesizer(),   // ← swap TTS engine here
textRecognizer:    VisionTextRecognizer(),      // ← swap OCR engine here
```

For example, to move speech recognition to a cloud ASR, change only the first line to
`speechRecognizer: CloudSpeechRecognizer(),` — no other file changes, because `SpeechRecognizing`
already models streaming (text, isFinal) + cancellation backend-agnostically.

The deck **export mapping** (recognition vs production) is likewise a one-line default in
`AlgoAppXMLExporter(mapping:)` — flip `.recognition` → `.production`.

## Testing the cloud path before a cloud backend exists
Each engine port ships a `Mock*` (instant, happy) **and** a `Stub*` (latency + failure) in
`Data/Stubs/`, so slow/flaky cloud behavior is testable today (`StubLLMClient(behavior: .timeout)`,
`StubSpeechRecognizing(behavior: .failure(.permissionDenied))`, etc.).
