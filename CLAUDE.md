# EnglishHelper (ships publicly as **Gist It**)

Personal-use iOS app for living in a studied language (six languages, configurable studied/native
pair; originally EN-from-RU). Five tabs: **Say it** (thought → 3 phrasings / situation → phrases),
**Get it** (Translate / Explain / **Online** — a live interpreter that listens to surrounding speech
and translates it in real time via Soniox), **See it** (photo → explain or translate), **Study**
(flat list, exported to AlgoApp/Anki), **History** (every request; live sessions keep their audio;
swipe-to-delete). Curated phrases go into the study list for the external SRS app.

- iOS 26 · Swift 6 · SwiftUI · Xcode 26 · SwiftData (persistence) · async/await + actors.
- Online-first; the LLM is Claude (Sonnet/Haiku) via the Anthropic API; live speech translation is
  Soniox `stt-rt-v5` over WebSocket.
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
`LLMClient`, `SpeechRecognizing`, `SpeechSynthesizing`, `TextRecognizing`, `LiveTranslating`
(live mic→cloud interpreter stream) + `SessionRecordingsManaging` (stored session audio),
`TranscriptionServiceChecking` (Soniox health probe), `ExpressionRepository`, `HistoryRepository`
(append/recent/delete), `TranslationCache`, `DeckExporting`, `AnalyticsTracking`. The media ports
are backend-agnostic (on-device OR cloud) and leak no SDK/transport types.

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
(unit tests only — fast). The XCUI suite is a separate, slow scheme:
`xcodebuild test -scheme EnglishHelperUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Config & secrets
`AppConfig` reads `CLAUDE_API_KEY` + `CLAUDE_MODEL` (+ optional `CLAUDE_FAST_MODEL`,
`SONIOX_API_KEY` — live online translation, `SONIOX_MODEL` — defaults to `stt-rt-v5`,
`TELEMETRYDECK_APP_ID` — analytics) from the app's
Info.plist, populated at build time from `Secrets.xcconfig` (gitignored; layered in via
`Config/Base.xcconfig` with `#include?`). Base URL defaults to `https://api.anthropic.com`.
**An API key embedded in a built app is extractable** — acceptable for this personal/dev app;
a production build would proxy via a backend.

## Current Status

**v1.4.1 — Online translation (live interpreter).** "Get it" gained a third mode, **Online**: a
Listen TOGGLE (pill with a live sound diagram) streams the mic (AVAudioEngine → AVAudioConverter →
16 kHz mono pcm_s16le, ~120 ms binary chunks) to Soniox `stt-rt-v5` over
`wss://stt-rt.soniox.com/transcribe-websocket` with built-in one_way translation into the native
language; the recommended low-latency endpointing config is on. Final tokens append, non-final
tokens REPLACE, and `<end>`/`<fin>` utterance markers start a new PARAGRAPH in both transcripts
(pure `SonioxTokenAccumulator`, unit-tested). Two synced auto-scroll panes
(recognized 4-line pane + translation pane on the remaining height; bottom-stick with pause-on-
scroll-up, proportional cross-sync via `onScrollGeometryChange`/`onScrollPhaseChange`).
Sessions record AAC audio (Application Support/SessionRecordings), keep listening in the background
(`UIBackgroundModes: audio`), auto-stop after 5 min of silence, survive interruptions (call → clean
stop+save), and land in History as `RequestResult.liveTranslation(original:ru:audioFileName:duration:)`
— JSON-blob persistence, so NO schema migration. History: swipe-left delete
(`HistoryRepository.delete` + audio-file cleanup in `RequestHistoryInteractor`; pruning also deletes
orphaned audio) and in-detail playback (`SessionRecordingsManaging`). New Domain ports:
`LiveTranslating`, `SessionRecordingsManaging`; new use case `LiveTranslateInteractor` (saves the
session best-effort, even on a mid-session failure). Soniox key + Settings health row landed in the
same release. 175/175 tests green. **The live streaming path needs on-device verification** (mic +
real WebSocket; the Simulator run only proves UI/wiring).

Historical build log (v1 scaffold → v1.3.3) follows.

**Scaffold (Prompt 1): COMPLETE.** Clean-architecture skeleton, mocks, DI, tests.

**v1 (Prompt 2) — Build order:**
- ✅ **1. Adapters + forbidden-import guardrail.** Live adapters wired; app boots LIVE with a mock
  fallback, builds + launches on iOS 26, 24/24 tests green.
  - `ClaudeLLMClient` (Messages API; fence-strip + typed decode + timeout/malformed/offline paths).
  - `NativeSpeechRecognizer` (`SFSpeechRecognizer`, ru-RU, (text,isFinal) stream, cancel). NB: the
    iOS 26 `SpeechAnalyzer`/`SpeechTranscriber` has NO on-device Russian model on current devices
    (`AssetInventory.status` = `.unsupported`), so we use `SFSpeechRecognizer` — Russian works
    server-backed (needs network). Engine swap was one file (the port is unchanged).
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
- ✅ **6. "История"** (tab **История**). Read-only chronological log of every request; rows show
  kind/input/result snippet/timestamp; tap → detail rendering the full result by kind (howToSay
  variants / translate+photo RU). States loading/empty/loaded/failed. 44/44 tests green.
- ✅ **7. "Настройки"** (gear on every screen → sheet; not a tab). LIVE API health check
  (checking/ok/failed via a cheap `HealthCheckTemplate` round-trip through `ClaudeLLMClient`),
  theme toggle (system/light/dark, persisted in `ThemeStore` → `preferredColorScheme`), and
  app/voice info (version, model, voice). 47/47 tests green.

**v1 COMPLETE.** All 7 build-order steps done; 47 tests green; builds + launches on iOS 26.
Tabs: Изучаю · Текст · Голос (center, default) · Камера · История (+ Settings gear). Final notes:
- **«Текст» = «Голос» без микрофона**: the former EN→RU "Перевод" screen was repurposed — it now
  runs the SAME flow as Voice (RU → 3 register-tagged English variants, play/save/regenerate) but
  text-input only. Both tabs use `VoiceView` (`showsMic:` flag) + a `VoiceViewModel`. The old
  `translateText` use case/template remain in Domain but are no longer surfaced by a screen.
- Navigation: Голос is centered and the default tab; История as a tab, Settings as a gear/sheet.
- The Settings health check makes a real (tiny) Claude call each time it runs — intended.
- Still device-only: live mic→STT and the camera capture path (Simulator hides the camera button).

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
