# EnglishHelper

A personal-use iOS app for learning a language from your own — capture phrases by **voice**,
**text**, or **camera**, get natural phrasings, translations, and plain-language explanations from
Claude, and collect the keepers into a flat study list you export to an external SRS app (AlgoApp).

Built originally for learning **English from Russian**; the studied and native languages are now
configurable, so it works between any pair of the supported languages.

- **Platform:** iOS 26 · Swift 6 · SwiftUI · SwiftData · async/await + actors · Xcode 26
- **Online-first.** The LLM is **Claude** (via the Anthropic Messages API).
- **Design:** monochrome "Liquid Glass"; system colors are functional signals only (success / error / warning).

See `CLAUDE.md` for the full architecture map and `CHANGELOG.md` for release history.

---

## What it does

On first launch a short **onboarding** screen lets you pick three languages — **interface**,
**studied** (the one you're learning), and **native** (the one explanations and translations come in).
All three are changeable later in Settings. After that the app opens on five tabs:

| Tab | What it's for |
|---|---|
| **Сказать / Say it** *(center, default)* | Speak or type a thought in your native language → get **3** natural phrasings ("How to say"), or describe a **situation** → get the 3–10 most useful phrases for it ("What to say"). Pick a tone (Polite / Casual / Slang); tap a card to hear it; bookmark to save. |
| **Понять / Get it** | Type or dictate an expression in the studied language. **Translate** gives a faithful meaning; **Explain** breaks down what it means, how formal or blunt it sounds, where it's used, and a familiar comparison. |
| **Смотреть / See it** | Point the camera (or pick a photo) at a sign, menu, or page → on-device OCR → translation drawn over the image. |
| **Изучаю / Study** | Your flat study list. Add manually, mark learned, swipe to delete, and **export to AlgoApp** via the system share sheet. |
| **История / History** | A chronological log of every request; tap an entry to see the full result, replay it, copy, or explain. |

A **Settings** sheet (gear, top-right of every screen) covers a live Claude connection check, the
three language pickers, the appearance theme, and app/model info.

### Supported languages

Russian · English · French · Spanish · German · Italian — available for the **interface**, as the
**studied** language, and as the **native** language (translations / generation / explanations / speech).

---

## Architecture — Clean Architecture

Each layer is a **separate Swift framework module**, so the compiler enforces the dependency rule
(the dependency arrow only ever points inward):

```
            ┌───────────────┐
            │     App       │  composition root · DI · @main · AppConfig
            └──────┬────────┘
        ┌──────────┼───────────┬──────────────┐
        ▼          ▼           ▼              ▼
   Presentation   Data    DesignSystem     (Domain)
        │          │           │
        ├──► Domain ◄──────────┘   (Presentation→Domain, Data→Domain)
        └──► DesignSystem
```

- **Domain** — entities, port protocols, prompt templates, use cases. Foundation only; no platform/UI/transport frameworks (enforced by `ForbiddenImportTests`).
- **Data** — adapters implementing the Domain ports (`ClaudeLLMClient`, native Speech/Vision adapters, SwiftData repositories, AlgoApp exporter). Compiled as the **`Adapters`** module (a module named `Data` would shadow `Foundation.Data`).
- **DesignSystem** — `Tokens.swift` (single source of truth) + components built on it; also hosts the runtime localizer (`Loc` / `LocCatalog`).
- **Presentation** — SwiftUI views + MVVM view models; consumes **use cases** only.
- **App** — the only place that knows the concrete adapters; wires the graph and injects use cases.

Each LLM use case is a **prompt template** in Domain (system prompt + strict output JSON schema +
typed decoder), so adding a feature means adding a template — the LLM adapter never changes.

---

## Build & run

The Xcode project is generated from `project.yml` (the `.xcodeproj` is gitignored).

```sh
cp Secrets.example.xcconfig Secrets.xcconfig   # first time only — then fill in CLAUDE_API_KEY
brew install xcodegen                           # if needed
xcodegen generate
open EnglishHelper.xcodeproj                     # or ⌘R in Xcode
```

Build / test from the CLI:

```sh
xcodebuild -scheme EnglishHelper -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test  -scheme EnglishHelper -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

> The live mic→speech path and the camera capture path are **device-only** (no mic/camera on the
> Simulator; the camera button is hidden there).

### Security note

`AppConfig` reads `CLAUDE_API_KEY` and `CLAUDE_MODEL` from the app's Info.plist, populated at build
time from `Secrets.xcconfig` (gitignored; layered in via `Config/Base.xcconfig` with `#include?`).
The base URL defaults to `https://api.anthropic.com`; the model defaults to `claude-sonnet-4-6`.
**A key embedded in a built app is extractable** — fine for personal/dev use; production would proxy
Claude through a backend.

---

## Swapping an engine (one line)

Every backend is wired in exactly one place — the composition root, `App/AppContainer.swift`,
`bootLive(config:)`. The Domain and Presentation layers never learn which backend is wired, so
swapping an engine touches exactly ONE registration line:

```swift
speechRecognizer:  NativeSpeechRecognizer(localeProvider: …),   // ← swap ASR engine here
speechSynthesizer: NativeSpeechSynthesizer(localeProvider: …),  // ← swap TTS engine here
textRecognizer:    VisionTextRecognizer(),                      // ← swap OCR engine here
```

To move speech recognition to a cloud ASR, change only the first line — no other file changes,
because `SpeechRecognizing` already models streaming `(text, isFinal)` + cancellation
backend-agnostically. The deck **export mapping** (recognition vs production) is likewise a one-line
default in `AlgoAppXMLExporter(mapping:)`.

## Testing the cloud path before a cloud backend exists

Each engine port ships a `Mock*` (instant, happy) **and** a `Stub*` (latency + failure) in
`Data/Stubs/`, so slow/flaky cloud behavior is testable today —
`StubLLMClient(behavior: .timeout)`, `StubSpeechRecognizing(behavior: .failure(.permissionDenied))`,
etc.

---

## Project layout

```
Domain/          Entities · Ports · Prompts · UseCases · DomainErrors
Data/            Adapters (live) + Mocks/ + Stubs/   (compiled as the `Adapters` module)
DesignSystem/    Tokens.swift · Loc.swift · LocCatalog.swift · Components/
Presentation/    Root · Onboarding · Voice (Say it) · In (Get it) · Photo (See it) · Library (Study) · History · Settings · Support
App/             EnglishHelperApp · AppContainer (DI) · AppConfig · Info.plist · Assets
Tests/           ForbiddenImportTests · DIBootTests · use-case / view-model / adapter tests
Config/          Base.xcconfig · Secrets.example.xcconfig
docs/            RUN.md + build-order notes
CHANGELOG.md     user-facing release notes
```

---

## Status

**v1.2.5** — six interface/studied/native languages (RU · EN · FR · ES · DE · IT), first-launch
language onboarding, unified card action rows, and a denser type scale. 71 tests green; builds and
runs on iOS 26.
