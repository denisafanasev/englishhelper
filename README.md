# Gist It

**Not just a translator — a companion for actually living in another language.**

A word-for-word translator answers one narrow question: *what does this mean?* But being dropped into
a language — as a traveller, an expat, or anyone studying in an immersion setting — throws harder
questions at you all day: *What is this sign telling me? Did I understand that correctly? How do I say
this without sounding like a phrasebook?* Gist It turns your phone into a quiet assistant for
exactly those moments. It **reads the world around you**, **explains what things really mean** (not
just their dictionary gloss), and **hands you natural ways to say what you want** — then quietly
remembers the phrases worth keeping, so the language you meet in the wild becomes the language you
actually learn.

Built originally for learning **English from Russian**; the studied and native languages are now
configurable, so it works between any pair of the six supported languages.

- **Platform:** iOS 26 · Swift 6 · SwiftUI · SwiftData · async/await + actors · Xcode 26
- **Powered by Claude** (Anthropic Messages API) — online-first.
- **Design:** monochrome "Liquid Glass"; color is reserved for functional signals (success / error / warning).

See `CLAUDE.md` for the full architecture map and `CHANGELOG.md` for release history.

---

## Why it's more than a translator

Living in a language is three problems, not one — and the app is built around exactly those three.
Each is a tab, and each works whether you're online at a café or you just need a quick answer on the
street:

- 👁️ **See it — read the world.** You can *see* the words but not understand them. Point the camera
  (or pick a photo) at a **sign, menu, label, or page**; the text is recognised and the translation is
  drawn right over the image, where it is. Tap any phrase to have it **explained** in plain language,
  or saved.
- 🧠 **Get it — understand what reached you.** You *heard* or *read* something and want to be sure.
  Type it, or **dictate** it in the language you're learning. **Translate** gives a faithful meaning;
  **Explain** tells you what it *really* says — how formal or blunt it sounds, when people actually use
  it, and a familiar comparison so it clicks.
- 💬 **Say it — put words in your mouth.** You need to *speak*. Say or type the thought in your own
  language and get **three natural phrasings** to choose from. Or describe the **situation** —
  "ordering coffee", "apologising for being late", "haggling at a market" — and get the handful of
  phrases that situation actually calls for. Pick a **tone** (Polite / Casual / Slang) to match the room.

Every result can be **spoken aloud** in the language you're studying — so you can hear it before you
say it — and any phrase worth keeping is **one tap** from your personal study list.

---

## What it does

On first launch a short **onboarding** lets you pick three languages — **interface**, **studied** (the
one you're learning), and **native** (the one translations and explanations come in). All three are
changeable later in Settings. Then the app opens on five tabs:

| Tab | What it's for |
|---|---|
| **Сказать / Say it** *(center, default)* | Speak or type a thought in your native language → get **3** natural phrasings ("How to say"), or describe a **situation** → get the 3–10 most useful phrases for it ("What to say"). Pick a tone (Polite / Casual / Slang); tap a card to hear it; bookmark to save. |
| **Понять / Get it** | Type or dictate an expression in the studied language. **Translate** gives a faithful meaning; **Explain** breaks down what it means, how formal or blunt it sounds, where it's used, and a familiar comparison. |
| **Смотреть / See it** | Point the camera (or pick a photo) at a sign, menu, or page → on-device text recognition → translation drawn over the image. Explain or save any phrase from the result. |
| **Изучаю / Study** | Your flat study list. Add manually, mark learned, swipe to delete, and **export to AlgoApp** (your SRS app) via the system share sheet. |
| **История / History** | A chronological log of every request; tap an entry to see the full result, replay it, copy, or explain. |

A **Settings** sheet (gear, top-right of every screen) covers a live Claude connection check, the
three language pickers, the appearance theme, and app/model info.

### Little things that make it feel like an assistant

- **Hear it before you say it.** Every phrase plays back in the studied language with one tap.
- **Save the keepers.** Bookmark any card; it lands in **Study** and exports to your SRS app.
- **Walk away during a long request.** Leave the app mid-recognition or mid-explanation and get a
  **notification** the moment the result is ready.
- **Instant, offline repeats.** Ask for the same translation or phrasing again and it comes straight
  from an on-device **cache** — no wait, no connection needed. (Asking for *fresh* variants still
  goes to Claude.)
- **One tap from the Lock Screen.** Six **widgets**, one per scenario, deep-link straight into the app
  with the **camera ready** (See it) or the **mic already listening** (Get it / Say it).
- **Share a photo straight in.** Send an image to Gist It from Photos or any app to translate it.
- **Light / dark / system** theme, and a live check that Claude is reachable.

### Supported languages

Russian · English · French · Spanish · German · Italian — available for the **interface**, as the
**studied** language, and as the **native** language (translations / generation / explanations / speech).

### Under the hood

Language work runs on **Claude Sonnet 5** for everything but plain translation, which uses the faster
**Claude Haiku** tier for speed; you can override the model per scenario in Settings. Text recognition
(**See it**) and speech both run **on-device**. The app is online-first — it needs a connection to
reach Claude — but cached translations and saved phrases stay available offline.

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

> **Public vs. internal name.** The app ships publicly as **Gist It** (its display name / App Store name).
> The Xcode project, scheme, module, and bundle identifier keep the original internal name
> **EnglishHelper** — so the commands below and the paths in *Project layout* still reference `EnglishHelper`.

```sh
cp Secrets.example.xcconfig Secrets.xcconfig   # first time only — then fill in CLAUDE_API_KEY
brew install xcodegen                           # if needed
xcodegen generate
open EnglishHelper.xcodeproj                     # or ⌘R in Xcode
```

Build / test from the CLI:

```sh
xcodebuild -scheme EnglishHelper -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test  -scheme EnglishHelper        -destination 'platform=iOS Simulator,name=iPhone 17 Pro'  # unit tests (fast)
xcodebuild test  -scheme EnglishHelperUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'  # XCUI suite (slow; drives the real app on stubs)
```

> The live mic→speech path and the camera capture path are **device-only** (no mic/camera on the
> Simulator; the camera button is hidden there).

### Security note

`AppConfig` reads `CLAUDE_API_KEY` and `CLAUDE_MODEL` from the app's Info.plist, populated at build
time from `Secrets.xcconfig` (gitignored; layered in via `Config/Base.xcconfig` with `#include?`).
The base URL defaults to `https://api.anthropic.com`; the model defaults to `claude-sonnet-5`.
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

**v1.3.3 (build 11)** — voice input is now **push-to-talk**: capture runs while the mic button is
held (press haptic + the standard iOS record chimes around the actual recording, sequenced in the
speech adapter so the beep is never captured); a deliberate release stops and submits, while a
SYSTEM touch-cancel (call / permission alert / scroll steal / backgrounding) stops WITHOUT firing a
request. The widget deep-link flow keeps its hands-free auto-listen; VoiceOver degrades to a
tap-toggle. The Get it action button also doubles as **Paste** while the field is empty and the
clipboard holds text (metadata-only check; the clipboard is read solely on the explicit tap).
Previously, in v1.3.2: **anonymous product analytics** via TelemetryDeck behind a Domain
`AnalyticsTracking` port (closed no-payload event enum — no PII by construction; SDK confined to
the Adapters module and off entirely when no App ID is configured). In v1.3.1:
the app now ships publicly as **Gist It** (renamed from EnglishHelper);
Lock Screen widgets (one per scenario, deep-linking straight into the camera or a live mic), an
offline translation cache with reuse stats, per-scenario model choice, the standard tier upgraded
to **Claude Sonnet 5**, and per-screen state preservation across tab switches (results, input,
mode, tone — covered by an XCUITest suite). The LLM path now **streams** (bounded time-to-first-byte
+ idle-bounded chunks, per-attempt reachability re-checks), the SwiftData store opens **off the main
thread** behind the launch screen, and routed actions (widgets / Share sheet / "Explain" buttons)
never overwrite the user's saved screen modes. Builds and runs on iOS 26.
