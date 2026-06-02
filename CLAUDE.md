# EnglishHelper

Personal-use iOS app (single user) for learning English from Russian. Three input modes:
**Voice** ("how do I say…?"), **Translate** (EN→RU), and **Camera** (OCR→RU). Curated phrases go
into a flat study list that's exported to an external SRS app (AlgoApp).

- iOS 26 · Swift 6 · SwiftUI · Xcode 26 · SwiftData (persistence) · async/await + actors.
- Online-first; the LLM is Claude (Sonnet) via the Anthropic API.
- Monochrome "Liquid Glass" design system; system colors are functional signals only.

## Architecture — Clean Architecture, dependency rule strictly inward

Each layer is a **separate framework module**, so the compiler enforces the dependency rule
(Domain literally cannot import an outer layer):

```
            ┌───────────────┐
            │     App       │  composition root · DI · @main · AppConfig
            └──────┬────────┘
        ┌──────────┼───────────┬──────────────┐
        ▼          ▼           ▼              ▼
   Presentation   Data    DesignSystem     (Domain)
        │          │           │
        ├──► Domain ◄──────────┘ (Presentation→Domain, Data→Domain)
        └──► DesignSystem
```

- **Domain** — entities, port protocols, prompt-template definitions, use cases. Foundation ONLY;
  zero platform/UI/transport frameworks (enforced by `ForbiddenImportTests`).
- **Data** — adapters implementing Domain ports. Currently `Mock*` only; live adapters land in v1.
  Folder is `Data/`; the **Swift module is named `Adapters`** (a module named `Data` would shadow
  `Foundation.Data` in every consumer) — so import it as `import Adapters`.
- **DesignSystem** — `Tokens.swift` (single source of truth) + components built on it. No Domain dep.
- **Presentation** — SwiftUI views + MVVM view models. Consumes **use cases** only.
- **App** — the only place that knows concrete adapters; wires the graph and injects use cases.

### Ports (Domain) → adapters (Data)
`LLMClient`, `SpeechRecognizing`, `SpeechSynthesizing`, `TextRecognizing`, `ExpressionRepository`,
`HistoryRepository`, `DeckExporting`. The three media ports are backend-agnostic (on-device OR
cloud) and leak no SDK/transport types.

### Prompt templates (Domain)
`PromptTemplate` owns a system prompt + output JSON schema + typed decoder. v1 templates:
`howToSay` (3 variants), `translateText`, `photoTranslate`, `enrichCard`. Adding a use case = adding
a template; the LLM adapter never changes.

## Folder layout

```
Domain/          Entities · Ports · Prompts · UseCases · DomainErrors
Data/Mocks/      Mock* impl for every port   (compiled as the `Adapters` module)
DesignSystem/    Tokens.swift · Components/
Presentation/    Root/ (RootView, RootViewModel) · Placeholder/
App/             EnglishHelperApp · AppContainer (DI) · AppConfig · Info.plist · Assets.xcassets
Tests/           ForbiddenImportTests · DIBootTests
Config/Base.xcconfig   project.yml   Secrets.example.xcconfig
design_system/   archived design handoff bundle (HTML/CSS/JSX) — NO LONGER the source of truth
docs/            RUN.md + prompts 00–02
```

## Build & run

The Xcode project is generated from `project.yml` (it is gitignored).

```sh
cp Secrets.example.xcconfig Secrets.xcconfig   # then fill in CLAUDE_API_KEY (first time only)
brew install xcodegen                          # if needed
xcodegen generate
xcodebuild -scheme EnglishHelper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
open EnglishHelper.xcodeproj                    # or ⌘R in Xcode
```

Tests: `xcodebuild test -scheme EnglishHelper -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Config & secrets
`AppConfig` reads `CLAUDE_API_KEY` + `CLAUDE_MODEL` from the app's Info.plist, populated at build
time from `Secrets.xcconfig` (gitignored; layered in via `Config/Base.xcconfig` with `#include?`).
Base URL defaults to `https://api.anthropic.com`. **An API key embedded in a built app is
extractable** — acceptable for this personal/dev app; a production build would proxy via a backend.

## Current Status

**Scaffold (Prompt 1): COMPLETE.** Clean-architecture skeleton, mocks, DI, tests.

**v1 (Prompt 2) — Build order:**
- ✅ **1. Adapters + forbidden-import guardrail.** Live adapters wired; app boots LIVE with a mock
  fallback, builds + launches on iOS 26, 24/24 tests green.
  - `ClaudeLLMClient` (Messages API; fence-strip + typed decode + timeout/malformed/offline paths).
  - `NativeSpeechRecognizer` (iOS 26 `SpeechAnalyzer`/`SpeechTranscriber`, ru-RU on-device, (text,isFinal) stream, cancel).
  - `NativeSpeechSynthesizer` (`AVSpeechSynthesizer`, EN, state + stop).
  - `VisionTextRecognizer` (`RecognizeTextRequest` → text + normalized top-left boxes).
  - `SwiftDataExpressionRepository` / `SwiftDataHistoryRepository` (`@ModelActor`) + `@Model` types.
  - `AlgoAppXMLExporter` (deterministic 4-line cards → escaped XML, validated by `XMLParser`).
  - OCR port evolved: `TextRecognizing` now returns `RecognizedText` (text + boxes).
  - `Stub*` (latency + failure) for LLM/ASR/TTS/OCR alongside `Mock*`.
  - Engine swap = ONE line in `AppContainer.bootLive` (see README).
- ✅ **2. "Как сказать"** (Voice: mic→STT→Claude→TTS→save→enrich). Root screen = `VoiceView`.
  - Voice OR typed RU → editable transcript → 3 register-tagged variants (tap = play TTS,
    bookmark = save). "Другие варианты" = regenerate (prior set stays in history).
  - States: idle / listening / processing / results / error / offline + API-key banner.
  - Mic permission PRIMING sheet before the system dialog (`didPrimeMic` in UserDefaults).
  - New use cases: `RegenerateHowToSay`, `SaveExpression` (enrich-then-store), `VoiceCapture`,
    `PlayPronunciation`. New DS components: `MicButton`, `PhraseVariantCard`, `EHButton`,
    `GlassField`, `StatusView`/`LoadingView`, `glassPanel` (Reduce-Transparency→solid).
  - 29/29 tests green; builds + launches.
- ✅ **3. "Перевод"** (EN→RU). Typed English → single Russian translation; play EN source; save
  (enrich-then-store, toggle). States idle/processing/result/error/offline + API-key banner.
  Introduced the app shell: native `TabView` (Liquid-Glass tab bar) with **Голос** + **Перевод**
  tabs (grows each step). `AppContainer.makeTranslateViewModel`; shared `presentableError` mapper.
  32/32 tests green; builds + launches.
- ✅ **4. "Фото-перевод"** (EN→RU). Camera (UIKit `UIImagePickerController`, guarded by
  `isSourceTypeAvailable` — hidden on Simulator) + library (`PhotosPicker`, no permission needed)
  → OCR (+ boxes) → RU translation. Boxes drawn over the photo; translation panel sits on a
  **SOLID scrim** (white text, AA contrast — never glass under text). Play source / save.
  Camera permission priming before the system dialog. New tab **Камера**. 35/35 tests green.
- ✅ **5. "Список" + AlgoApp export** (tab **Изучаю**). Flat study list of `Expression`s: manual
  add (enrich-then-store), swipe-delete, leading swipe toggle-learned, glass rows. Export via
  `ExportDeck` → `AlgoAppXMLExporter` → temp .xml file → system share sheet (`UIActivityViewController`).
  States loading/empty/loaded/failed. 42/42 tests green.
- ⏳ 6. "История" · 7. "Настройки".

**Notes / trade-offs so far:**
- **Liquid Glass vs readability:** all glass goes through `glassPanel`, which swaps to a SOLID
  surface under Reduce Transparency; `MicButton` rings/`symbolEffect` disable under Reduce Motion.
- **Iconography:** using SF Symbols (the design's icon names were SF-Symbol-style) for native
  Dynamic Type + VoiceOver + variable-color effects, rather than porting the custom thin-line set.
- **Save = sticky toggle in Voice:** bookmark saves (enrich→store) / unsaves (delete); no per-card
  spinner during the enrich call yet.
- `NativeSpeechRecognizer` compiles against the real iOS 26 API but its live mic→STT path needs
  on-device verification (no mic in CI); the stream contract is covered by `Stub*`.
- `XMLDocument` is macOS-only → the exporter uses a dedicated escaping `XMLWriter` + `XMLParser` validation.
- SDK name collisions handled by qualification: `Domain.Expression` vs `Foundation.Expression`,
  `Domain.RecognizedText`/`NormalizedRect` vs Vision's; Data layer module is `Adapters` (not `Data`).
