# Prompt 2 — V1 DEVELOPMENT

> Run AFTER the init skeleton compiles. New session: read CLAUDE.md first to load state.
> APP_NAME = EnglishHelper.

---

# Task: build v1 of EnglishHelper on the existing skeleton

Implement all screens + Settings, wiring concrete adapters into the Clean Architecture skeleton.
Production-grade: error handling, edge cases, a11y, tests. Personal-use, online-first, single user.
All components and screens reference `DesignSystem/Tokens.swift` — NEVER raw values.

## Adapters — concrete impls behind Domain ports (ports are STABLE extension points)
Today's impls are the FIRST backend per port. The domain must not know which one is wired.

- `NativeSpeechRecognizer`  : SpeechRecognizing
    iOS 26 SpeechAnalyzer/SpeechTranscriber, RU, on-device.
    Emit transcript via AsyncStream of (text, isFinal) so a streaming cloud ASR fits the SAME
    protocol later. Support cancel().
- `NativeSpeechSynthesizer` : SpeechSynthesizing
    AVSpeechSynthesizer, EN enhanced voice. Report state (idle/loading/playing/finished) +
    stop/interrupt. Port must NOT assume on-device: a streamed-chunk cloud TTS must satisfy it unchanged.
- `VisionTextRecognizer`    : TextRecognizing
    Vision, EN text from photo/library image. Return text WITH bounding boxes (normalized rects) —
    the OCR overlay needs them; a cloud OCR must return the same shape.
- `ClaudeLLMClient`         : LLMClient
    Anthropic Messages API (POST https://api.anthropic.com/v1/messages, `anthropic-version` header,
    Sonnet model from AppConfig). Executes a PromptTemplate: injects system prompt, sends input,
    decodes the template's strict JSON schema. Parse safely (strip fences, typed decode, handle
    malformed/empty/timeout).
- `SwiftDataExpressionRepository` : ExpressionRepository.
- `SwiftDataHistoryRepository`    : HistoryRepository.
- `AlgoAppXMLExporter`            : DeckExporting (see Export below).

## Abstraction guardrails (enforced, not aspirational)
- Domain & Presentation import NOTHING from AVFoundation / Speech / Vision / Anthropic SDK.
  Those imports live ONLY in Data. Add a test/lint check that FAILS on a forbidden import in
  Domain or Presentation.
- DI wires concrete adapters at the composition root only. Swapping any of the three engines must
  touch exactly ONE registration line — prove it in README with the exact line.
- Each of the three ports ships with a `Mock*` AND a `Stub*` simulating latency + failure, so
  cloud-backed behavior is testable before any cloud impl exists.

## Use cases (Domain)
GenerateHowToSay(ru) → 3 variants · RegenerateHowToSay(ru) → fresh 3 variants ·
TranslateText(en) → ru · RecognizeAndTranslateImage(image) → ru (+ EN source + boxes) ·
EnrichExpression(en) → ru/example/synonyms · SaveExpression · DeleteExpression ·
ToggleLearned · FetchHistory · AppendHistory · ExportDeck.
- Every LLM-backed request use case appends a HistoryEntry on success.
- Expression CREATE (save from any flow / manual add / photo) runs EnrichExpression first,
  then stores the enriched entity.

## Screens (built from DesignSystem components) — one screen = one user intent
- "Как сказать" (RU→EN): voice capture (idle/listening/processing/error) OR typed RU input →
  editable transcript → 3 variant cards (EN phrase + register tag + RU context;
  tap=play TTS, toggle=save to list) → "Regenerate" action (replaces current 3; prior set stays
  in history).
- "Перевод" (EN→RU): typed EN text → single RU translation (play EN source, save to list).
- "Фото-перевод" (EN→RU): camera + pick-from-library → OCR overlay on SOLID scrim (no glass under
  text) → RU translation → save.
- "Список": flat study list (add manually / swipe-delete / toggle learned). Export to AlgoApp .xml
  (see Export). Saving here triggers EnrichExpression.
- "История": chronological list of all requests (how-to-say / translate / photo). Tap → review the
  full result. Read-only.
- "Настройки": API connection status (live health check: ok/checking/failed), theme toggle
  (light/dark/system, persisted), app/voice info.

## Export — AlgoApp .xml deck (via DeckExporting port, impl `AlgoAppXMLExporter` in Data)
Export selected/all expressions to an AlgoApp .xml deck file via the system share sheet.

Each card content is rendered DETERMINISTICALLY from stored fields as exactly 4 plain-text
lines (NOT produced by the LLM):
```
line 1: en
line 2: ru
line 3: example
line 4: synonyms joined by " / "
```
AlgoApp schema (official import format):
```xml
<deck name="EnglishHelper Export">
  <cards>
    <card><field name="Front">{line 1}</field><field name="Back">{lines 2-4 joined by newline}</field></card>
    ...
  </cards>
</deck>
```
- Mapping default = recognition: Front = line 1 (en), Back = lines 2-4. Flip to production
  (Front = ru, Back = en+example+synonyms) must be a one-line change.
- Build XML with a real XML serializer that escapes & < > " ' in EVERY field — NOT string concat.
- Validate output parses before sharing.
- No live API / URL scheme exists; user imports the .xml in AlgoApp manually.
- LLMClient / repositories stay unaware of export format — it lives only in AlgoAppXMLExporter
  behind the DeckExporting port (CSV / APKG can be added later without touching screens).

## Mandatory states everywhere
loading · empty · error · offline · permission priming (mic + camera, explained BEFORE system dialog).

## Accessibility
VoiceOver labels/hints (esp. mic + play), Dynamic Type to accessibility sizes, AA contrast (verify
text over scrim), Reduce Motion + Reduce Transparency fallbacks (glass → solid).

## Tests
- Unit-test each use case against a mock LLMClient (incl. malformed-JSON + timeout paths).
- One test proving the dependency rule isn't violated (forbidden-import check).
- One test per ASR/TTS/OCR port against its Stub* (latency + failure paths).
- Test that each LLM request use case appends exactly one HistoryEntry on success, zero on failure.
- Test that enrichCard fields never contain markdown/symbols and synonyms count is 0-3.
- Test that AlgoAppXMLExporter output is well-formed XML and escapes special chars.

## Build order (incremental — stop after each for build + verify)
1. Adapters + forbidden-import guardrail test.
2. "Как сказать" (exercises the full chain: mic → STT → Claude → TTS → save → enrich).
3. "Перевод".
4. "Фото-перевод".
5. "Список" + AlgoApp .xml export.
6. "История".
7. "Настройки".

Update `CLAUDE.md ## Current Status`. Report trade-offs hit — especially Liquid Glass vs readability.
