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

**Step 1 — Scaffold: COMPLETE.** Clean-architecture skeleton compiles and launches to a
placeholder screen, entirely on mock adapters.

- ✅ All Domain ports + 4 prompt templates defined; each port has a `Mock*` in Data; DI
  (`AppContainer.bootMock()`) wires the full use-case graph on mocks.
- ✅ `DesignSystem/Tokens.swift` is the single source of truth (extracted in Step 0, committed).
- ✅ `Secrets.xcconfig` gitignored; `Secrets.example.xcconfig` committed; Info.plist usage strings set.
- ✅ Tests: `ForbiddenImportTests` (Domain purity), `DIBootTests` (boots on mocks).

**Next — Step 2 (v1):** implement live adapters (ClaudeLLMClient, Speech/Vision, SwiftData repos,
deck exporter) and the three screens (Voice / Study / Camera), screen by screen. See
`docs/02-v1-development.md`. No feature logic or non-placeholder UI exists yet.
