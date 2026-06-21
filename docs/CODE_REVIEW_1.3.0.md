# Code review — EnglishHelper (ветка release/1.3.0)

_Многоагентный обзор: 13 ревью-юнитов → адверсариальная верификация каждой находки → синтез. Итог: **71 находок → 58 подтверждено**, 13 отклонено как ложные. Плюс 6 находки критика полноты._

## Общая оценка

The codebase is a well-structured Clean Architecture iOS app, but the review surfaces one systemic, recurring weakness: cross-cutting failure signals (cancellation, offline/timeout, save errors, persistence-boot failures) are encoded as fragile strings or swallowed, so they either get misclassified, silently lost, or shown to the user incorrectly. The single highest-impact issue is silent data loss: a live-boot/SwiftData failure falls back to in-memory mocks with no signal, and no schema migration plan exists. A tightly-coupled cluster around LLMError — URLError(.cancelled) never mapping to LLMError.cancelled, offline detection gaps, and English-substring sniffing of requestFailed across three modules — drives multiple downstream user-facing bugs (spurious cancellation/"Service unavailable" errors). The Data adapter layer also leaks raw/un-localized prose and under-handles error categories, while Domain decoders are intolerant of the non-deterministic LLM (register decode aborts the whole batch). Presentation has a recurring "error message set but never rendered outside .failed" pattern, and DesignSystem has systemic Dynamic Type / Reduce-Motion accessibility gaps plus token/single-source-of-truth drift. Most findings are individually low severity for a single-user app, but they cluster into a handful of clear root-cause themes worth fixing together.

## Сквозные темы

1. Silent data loss & missing persistence-migration safety net (live-boot falls back to empty mocks; no SchemaMigrationPlan; corrupt-row drops swallowed)
2. LLMError modeled as fragile English strings instead of typed cases — drives misclassification of cancellation, offline, and timeout across adapter, use cases, and presentation
3. Cancellation is mishandled end-to-end: URLError(.cancelled) is never mapped, so superseded requests surface spurious error states
4. Adapters leak raw / un-localized / under-categorized errors instead of typed cases the Presentation layer can localize
5. Save/export/import failures are set but never surfaced to the user (error UI only renders in .failed phase)
6. Domain decoders are too strict or too loose for a non-deterministic LLM (register decode aborts whole batch; whatToSay lower bound unenforced; PlainText over-strips)
7. No content-level dedupe of saved expressions across screens/launches → duplicate study rows and duplicate exported cards
8. Systemic accessibility gaps in DesignSystem (no Dynamic Type scaling; Reduce-Motion not gated on PhraseVariantCard; decorative motif read by VoiceOver)
9. Single-source-of-truth / token drift in DesignSystem and DI (glass fallback, hairline width, copy-state logic duplicated; model list and schema enumerated twice)
10. Dead / misleading code & docs (textRecognizer wired but unused; kindRaw persisted but never read; stale RU/EN comments; AppLanguage.stored unused)


## 🟠 HIGH (1)

### H1. Live-boot failure silently falls back to mocks with no signal — effective data loss, no schema migration plan
- **Файл:**  — EnglishHelperApp.swift:15-22; AppContainer.swift:96-97
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** If ModelContainer init throws in bootLive (the only throwing call there — a SwiftData store/migration failure, corrupted store, or disk/sandbox error), `try? AppContainer.bootLive` discards the error and the app boots the FULL mock graph (MockLLMClient/Repositories/Exporter). The user sees a normal-looking app where every Claude response is canned, saved study cards and history are written to in-memory mocks and DISAPPEAR on relaunch, and export produces mock output — with no banner, no log, and `isConfigured` still reporting true so even the API-key banner stays hidden. Compounding this, ModelContainer(for: ExpressionModel.self, HistoryModel.self) is created with no VersionedSchema/SchemaMigrationPlan, and both models carry @Attribute(.unique), so any future non-lightweight schema change makes the initializer throw — directly triggering the silent downgrade to empty in-memory storage. For a persistence app this is effectively silent, permanent data loss the user never learns about.
- **Фикс:** Do NOT mask a persistence-init failure by falling back to mocks. Capture and log the error (do/catch with os_log) and surface the degraded state to the UI (e.g. a `usingFallback` flag on AppContainer → persistent warning banner in RootView), since running on mocks means nothing persists. Introduce a VersionedSchema + SchemaMigrationPlan for [ExpressionModel, HistoryModel] now while the schema is trivial, and consider attempting a recovery (delete & recreate the store) before downgrading. The live LLM/speech mock-fallback is reasonable; the ModelContainer fallback is not.


## 🟡 MEDIUM (9)

### M1. URLSession cancellation throws URLError(.cancelled), never mapped to LLMError.cancelled — superseded requests surface spurious errors
- **Файл:**  — ClaudeLLMClient.swift:108-118; PhotoTranslateViewModel.swift:99-110
- **Категория:** concurrency · **уверенность:** high
- **Проблема:** The whole app relies on the adapter mapping Swift-Task cancellation to LLMError.cancelled (VoiceViewModel's comment is explicit about this). But when a Task running the request is cancelled (requestTask?.cancel() on supersede in VoiceViewModel/PhotoTranslateViewModel), the in-flight URLSession.data(for:) throws URLError(.cancelled), NOT Swift's CancellationError. The `catch is CancellationError` branch does not match it, and no URLError-code branch handles .cancelled, so it falls through to the generic catch → LLMError.requestFailed(error.localizedDescription) (e.g. "cancelled"/"отменено") → the `.requestFailed` default → user sees a spurious "Service unavailable. Try later." for a request they deliberately superseded. This is exactly the class of bug commit 8690bf9 fixed in VoiceViewModel (which now has BOTH `catch is CancellationError` AND `catch LLMError.cancelled`) — but the fix was never applied to PhotoTranslateViewModel, which only has `catch is CancellationError` + generic, so picking a second photo while the first is processing flashes a bogus cancellation error and drops the new processing state.
- **Фикс:** Fix at the source: add an explicit `catch let error as URLError where error.code == .cancelled { throw LLMError.cancelled }` before the generic catch in ClaudeLLMClient (and optionally `if Task.isCancelled { throw LLMError.cancelled }` at loop top, since localizedDescription strings are locale-dependent). Then mirror the VoiceViewModel fix in PhotoTranslateViewModel by adding `catch LLMError.cancelled { /* superseded — never surface */ }` between the CancellationError and generic catches.

### M2. LLMError offline/timeout encoded as English magic strings and re-parsed via substring matching across three modules
- **Файл:**  — ClaudeLLMClient.swift:113-117; ConnectionUseCase.swift:37-39; PresentableError.swift:28,31; VoiceViewModel.swift:279,283
- **Категория:** architecture · **уверенность:** high
- **Проблема:** The adapter encodes semantic failure categories as magic English strings: LLMError.requestFailed("offline") / requestFailed("timed out"). Three separate consumers re-parse these via info.contains("offline")/info.contains("timed out"): ConnectionUseCase, PresentableError, and VoiceViewModel. It works today only because ClaudeLLMClient produces exactly those substrings — but the same `.requestFailed` case is also thrown with error.localizedDescription for all other URLErrors and with "HTTP <code>: <detail>" for HTTP failures. A localized system-error string or an HTTP error body that happens to contain 'offline' or 'timed out' (e.g. a 503 body, a localized 'connection timed out' that isn't URLError.timedOut) is misclassified, and any wording change in the adapter silently breaks classification across all three files. This is cross-module string coupling with no compiler or test enforcement.
- **Фикс:** Introduce first-class LLMError.offline and LLMError.timedOut cases in Domain/DomainErrors.swift, thrown by the adapter, and switch all consumers (ConnectionUseCase, PresentableError, VoiceViewModel) to match the case instead of substring-sniffing requestFailed. This keeps the adapter the single source of classification and removes the string contract entirely. (This case also resolves the offline-coverage and cancellation findings cleanly.)

### M3. Speech recognizer never emits noSpeechDetected/.unavailable and leaks raw/Russian-only error prose
- **Файл:**  — 73-78, 124-127 (also 74,77,90,97,113)
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** Two coupled problems in the recognizer's error path. (1) Dead typed cases: DomainErrors defines SpeechRecognitionError.noSpeechDetected and .unavailable, and VoiceViewModel.captureFailed has dedicated, well-localized branches for both — but this adapter NEVER produces either case. The 'recognizer not available' path throws .underlying(...) and the no-speech/timeout path from SFSpeech (kAFAssistantErrorDomain codes 1110/1101) is funneled through .underlying(error.localizedDescription), so the user gets the raw, often English/locale-mismatched Apple string verbatim instead of the curated localized message. (2) The .underlying strings are HARDCODED Russian prose ('распознаватель … не создан', 'распознавание сейчас недоступно — проверьте интернет', 'аудиосессия:', 'микрофон недоступен …', 'аудиодвижок:'), which VoiceViewModel interpolates verbatim into its otherwise-localized template, so a French/German/etc. user sees a Russian fragment. Adapters should map to typed cases the Presentation layer localizes, not emit user-facing prose.
- **Фикс:** Throw SpeechRecognitionError.unavailable for the !isAvailable case; inspect the NSError domain/code in the task callback to map kAFAssistantErrorDomain no-speech codes to .noSpeechDetected (and cancellation codes to a clean finish), falling back to .underlying only for truly-unknown errors and carrying ONLY non-prose technical detail. This lights up the localized branches already implemented in captureFailed and removes the Russian-only strings.

### M4. Register decode has no fallback — one off-schema register tag fails the entire howToSay/whatToSay request
- **Файл:**  — 16-21
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** Register is the typed decoder for the LLM's `register` field (PhraseVariant decodes it via try c.decode(Register.self)). As a plain String-raw-value enum with no custom init(from:), decoding throws DecodingError.dataCorrupted for ANY value not exactly formal/neutral/casual/slang. The LLM is non-deterministic and can return 'Formal' (capitalized), a synonym ('informal'/'polite'), or a localized word despite the schema's enum constraint (schema enums are soft hints, not hard guarantees). One off-schema register on one of the 3 variants makes the whole decode throw → surfaces as invalidOutput → the entire result is lost even though en/contextRU were fine. ClaudeLLMClient does fence-stripping but no register normalization.
- **Фикс:** Add a tolerant custom init(from:) that lowercases/trims the raw string and falls back to .neutral for unknown values: `self = Register(rawValue: raw.trimmingCharacters(in: .whitespaces).lowercased()) ?? .neutral`. This keeps a usable variant instead of discarding the whole batch on a single off-schema tag.

### M5. SaveExpression and the repository never dedupe — same phrase from different screens/launches creates duplicate study rows
- **Файл:**  — LibraryUseCases.swift:50-61; SwiftDataRepositories.swift:22-25
- **Категория:** correctness · **уверенность:** high
- **Проблема:** SaveExpressionInteractor.callAsFunction enriches then calls repository.add() unconditionally, and the SwiftData repo's add() does modelContext.insert(...) with no fetch/predicate, so every save inserts a new ExpressionModel (the only uniqueness is @Attribute(.unique) on a freshly-minted UUID id). The only de-duplication that exists is per-screen view-model dictionaries (VoiceViewModel.savedExpressionIDs/savedVariantIDs), which are per-instance and not persisted. So saving the same `en` from Voice and again from Photo/History, or saving the same variant after a relaunch (where savedVariantIDs resets), produces duplicate study-list entries — which all get exported to AlgoApp as duplicate cards. The review's focus explicitly names dedupe; every CREATE path funnels through this use case, so it is the natural place. It is also wasteful: it runs the paid enrich LLM call before any duplicate check.
- **Фикс:** Before add(), fetch existing expressions (or add a repository.find(en:) port) and short-circuit on a case-insensitive match on normalized `en` — return the existing Expression or upsert in place. Do the dedupe check BEFORE enrich to avoid the wasted paid call. Enforce in the use case and/or the repository so all screens behave consistently.

### M6. Raw control characters in any field abort the entire AlgoApp XML export
- **Файл:**  — 97-103, 50-52
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** escape() handles &,<,>,",' but does NOT strip XML 1.0 illegal control characters (U+0000–U+0008, U+000B, U+000C, U+000E–U+001F), which are illegal in XML 1.0 even when numeric-escaped, so XMLParser rejects the document. Because isWellFormed validates the ENTIRE deck and export() throws ExportError.encodingFailed on failure, a single bad character in any one card's en/ru/example/synonyms (OCR output and pasted clipboard text routinely contain control chars) makes the WHOLE export fail with an opaque 'produced XML failed validation' — the user cannot export their study list at all. Reproduced: a field containing \u{1} or \u{B} yields XMLParser.parse() == false.
- **Фикс:** In escape(), before applying entity replacements, filter to only XML-1.0-legal scalars: keep U+0009, U+000A, U+000D, U+0020–U+D7FF, U+E000–U+FFFD, and U+10000+. This makes export robust instead of all-or-nothing.

### M7. Background save failure is set on errorMessage but never rendered while results are shown (swallowed from the user)
- **Файл:**  — VoiceViewModel.swift:345-349; InViewModel.swift:332-336; VoiceView.swift:197-208,219-220; InView.swift:159; PhotoTranslate toggleSave
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** When the enrich-then-store background save fails, toggleSave reverts the optimistic bookmark and sets errorMessage but does NOT change phase. The screen is in .results/.result, and the views only render error UI in the .failed branch (VoiceView line 197 / InView line 159, keyed on phase). So errorMessage is written but never displayed — the bookmark silently pops back off with no explanation, across Voice, In, and Photo. HistoryDetailView is the only screen that surfaces this correctly (a dedicated .alert bound to errorBinding).
- **Фикс:** Surface save failures independent of phase — add a dedicated transient saveError property shown as a toast/inline banner in the .results/.result content (or an .alert, as HistoryDetailView already does), and have the views read it outside .failed. Do NOT flip to .failed (that would hide the results).

### M8. Image downscale/JPEG re-encode runs on the main thread, hitching the UI during camera dismissal
- **Файл:**  — 40, 44-53, 264-276
- **Категория:** performance · **уверенность:** high
- **Проблема:** PhotoTranslateView is a SwiftUI View and implicitly @MainActor-isolated, so prepareImageData(_:) runs on the main actor. It is invoked synchronously in the camera path (onImage: { model.didCapture(prepareImageData($0) ?? $0) }) and inside the library Task (inheriting the View's MainActor isolation). prepareImageData decodes the image, renders it via UIGraphicsImageRenderer up to 1536px, and JPEG-encodes at 0.8 — all synchronous CPU-heavy work on the main thread. For a full-resolution camera photo this stalls the UI (frozen tap/scroll, a noticeable hitch) right as the camera sheet dismisses.
- **Фикс:** Move prepareImageData off the main actor: make it a nonisolated static/free function and await it from a detached/background Task before calling the MainActor-bound model.didCapture/didPickFromLibrary, e.g. `let prepared = await Task.detached { Self.prepareImageData(data) }.value`.

### M9. Design-system typography ignores Dynamic Type — app text never scales with accessibility text size
- **Файл:**  — 220-224, 229-252
- **Категория:** accessibility · **уверенность:** high
- **Проблема:** Every typography token resolves to a FIXED point size via `.system(size:weight:)` with no relativeTo: text style, no @ScaledMetric, and no Dynamic Type opt-in anywhere in DesignSystem (0 uses of ScaledMetric/dynamicTypeSize/relativeTo; all component .system(size:) calls are fixed). Because textStyle(_:) drives ALL app copy through token.font, the entire app's text is frozen at design point sizes and does not respond to Larger Text. Combined with fixed-height frames (EHButton 50, RegisterTag 22, CopyButton 12), low-vision users get no enlargement — a systemic accessibility regression for a learning app the owner may use at large text sizes.
- **Фикс:** Map tokens to scalable fonts: store a paired Font.TextStyle per token and build via UIFontMetrics/relativeTo, or use @ScaledMetric for the size, then apply the weight. Also relax fixed component heights to minHeight so they grow with text.


## ⚪ LOW (41)

### L1. Offline detection misses common URLError codes (DNS, host, data-not-allowed, secure-connection, roaming)
- **Файл:**  — 114
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** Offline is detected only for .notConnectedToInternet and .networkConnectionLost. On real devices many no-connectivity situations surface as different URLError codes: .cannotFindHost / .cannotConnectToHost / .dnsLookupFailed (captive wifi, DNS down), .dataNotAllowed (cellular off / low-data mode), .internationalRoamingOff, .secureConnectionFailed. All fall through to the generic catch → requestFailed(error.localizedDescription), which does NOT contain the substring "offline", so presentableError()/ConnectionUseCase classify them as generic "Service unavailable" instead of the offline state that drives the isOffline banner. The user is offline but the app won't tell them to check their connection.
- **Фикс:** Broaden the set: `case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .secureConnectionFailed:` → offline. Best done together with the dedicated LLMError.offline case so downstream classification stops relying on substring matching.

### L2. 401 maps to notConfigured but 403 / authentication_error are not — revoked key misreads as 'Service unavailable'
- **Файл:**  — 124-135
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** Only HTTP 401 maps to LLMError.notConfigured (the 'fix your key' path driving the API-key banner). Anthropic also returns 403 (permission_error) and sometimes 400 with authentication_error; these fall through to requestFailed("HTTP 403: ...") and surface as the generic "Service unavailable" rather than prompting the user to fix the key. Minor for a single-user app, but a revoked/insufficient key would mislead.
- **Фикс:** Treat 403 (and ideally a parsed body with type=="authentication_error") as notConfigured: `if http.statusCode == 401 || http.statusCode == 403 { throw LLMError.notConfigured }`.

### L3. Raw API error body embedded verbatim into the requestFailed string (unbounded; may echo request content)
- **Файл:**  — 134-135
- **Категория:** security · **уверенность:** high
- **Проблема:** On non-retryable, non-401 failures the full response body is decoded and concatenated into the error message. PresentableError doesn't show the raw string today, but the provider body can echo request fragments and is unbounded; if any path ever logs or surfaces the associated value, it leaks API-side detail. Low given documented personal-use scope.
- **Фикс:** Truncate detail to a small bound (e.g. prefix(500)) and/or parse only the structured error.message field from Anthropic's JSON error envelope instead of dumping the whole body.

### L4. Per-request JSONEncoder/JSONDecoder allocation and no shared/connectivity-aware URLSession config
- **Файл:**  — 73,79
- **Категория:** performance · **уверенность:** high
- **Проблема:** JSONEncoder() and JSONDecoder() are freshly allocated on every request (negligible but trivially hoisted). More notably, the client uses URLSession.shared with no custom configuration: timeoutInterval=30 is set but there is no waitsForConnectivity policy, so offline-vs-timeout behavior is left to URLSession.shared defaults and the (gap-prone) URLError-code mapping.
- **Фикс:** Store one immutable JSONEncoder and one JSONDecoder as let properties. Inject a URLSessionConfiguration with explicit timeoutIntervalForRequest/Resource and waitsForConnectivity=false so offline fails fast and predictably.

### L5. All OCR failures except cancellation collapse into unsupportedImage, masking real/transient errors
- **Файл:**  — 27-33
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** The catch-all maps every non-cancellation error from request.perform to TextRecognitionError.unsupportedImage. A transient Vision/system error, memory-pressure failure, or unsupported-language configuration are all reported as 'unsupported image', which is misleading and non-actionable. The .underlying(String) case exists precisely to carry diagnostic detail but is never used here.
- **Фикс:** Reserve .unsupportedImage for clearly image-format errors; map the general catch to TextRecognitionError.underlying(error.localizedDescription) so genuinely transient/unknown failures are distinguishable and can be logged or surfaced accurately.

### L6. WhatToSay decoder contradicts its own schema — accepts 1–2 phrases though schema/prompt require ≥3
- **Файл:**  — 206-229
- **Категория:** correctness · **уверенность:** high
- **Проблема:** The whatToSay output schema declares minItems:3 and the prompt says 'AT LEAST 3 and AT MOST 10', but the decoder only guards `!clamped.isEmpty`, so a reply with 1 or 2 phrases is accepted silently. The documented 3–10 contract is not enforced on the lower bound; the howToSay sibling correctly enforces count == 3. A degenerate 1-phrase result passes through to UI/history as valid.
- **Фикс:** Pick one source of truth: either drop minItems:3 from schema/prompt to match the decoder, or enforce `guard clamped.count >= 3 else { throw LLMError.invalidOutput(...) }` so schema, prompt, and decoder agree.

### L7. PlainText.clean blanket-deletes >, |, ~, _, #, * — mutilates legitimate translated/explained text
- **Файл:**  — 13-26
- **Категория:** correctness · **уверенность:** high
- **Проблема:** Every decoded string field runs through PlainText.clean, which unconditionally deletes the literal characters >, |, ~, _, #, *, backtick anywhere in the string. These are not always markdown: a translation/explanation containing '5 > 3', '#1 priority', 'C#'/'F#', hashtags, or 'a|b' is silently corrupted ('#1'→'1', 'C#'→'C', 'a > b'→'a  b'). Because clean() is applied to free-prose fields (meaning/register/context/analogy) written by the model, false positives are realistic and corrupt user-facing study content with no recourse.
- **Фикс:** Restrict deletion to true markdown structure rather than single-character class members. At minimum drop >, |, ~, # from the unconditional list, or only strip them in markdown patterns (leading # headings, leading > blockquotes, paired ~~/**/__). Single-char */_/#/> should not be blanket-deleted from prose.

### L8. JSON wire keys hardcoded to ru/en/context_ru are misleading and fragile for the 5 non-RU/EN language pairs
- **Файл:**  — 116-138
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** Schema/wire keys are language-frozen ('en', 'ru', 'context_ru') while the app supports 6 studied/native pairs. The prompt instructs that 'en' is actually studiedLanguage and 'context_ru'/'ru' are nativeLanguage; it works because the prompt explains the mapping, but a field literally named context_ru that must hold German/Italian (and 'en' holding French/Spanish) is self-misdescribing and invites weaker model turns to emit English/Russian for those keys despite the studied/native parameters.
- **Фикс:** Rename wire keys to language-neutral ones ('studied'/'phrase', 'note'/'native') as already done for Understanding/Explanation, updating PhraseVariant/TranslatedBlock CodingKeys. If wire compatibility must stay, add an explicit prompt line clarifying the value language regardless of the legacy key name.

### L9. TranslatedBlock assigns a random id on decode while Equatable/Hashable include it — round-trip yields non-equal value
- **Файл:**  — 10-29
- **Категория:** correctness · **уверенность:** high
- **Проблема:** TranslatedBlock is Equatable/Hashable/Identifiable with id in the synthesized conformance, yet init(from:) assigns self.id = UUID() (not decoded) while encode(to:) omits id. A decode→encode→decode cycle yields a non-equal value and a different identity each time. Lower impact than PhraseVariant because TranslatedBlock is currently produced inline (not round-tripped through SwiftData), but it is the same latent inconsistency: Equatable claims structural equality the decoder cannot honor.
- **Фикс:** Exclude id from Equatable/Hashable, or compute a deterministic id from (en, ru), so equality and identity survive a Codable round-trip.

### L10. RequestResult translate vs photoTranslate are distinguished only by the auto-synthesized case key — no test locks it
- **Файл:**  — 17-52
- **Категория:** state-machine · **уверенность:** high
- **Проблема:** HistoryEntry derives kind from result.kind at construction (always agreeing), and persistence's separate kindRaw is safely ignored on reconstruct. But the auto-synthesized Codable for RequestResult encodes the case name as the key, so .translate(ru:) and .photoTranslate(ru:) (identical ru:String payloads) are distinguished ONLY by that case key. This works, but the two same-shape cases are fragile to any manual/abbreviated coding-key change: a refactor unifying their payload representation would make them indistinguishable on decode and collapse photoTranslate history into translate. Nothing guards this.
- **Фикс:** Add a round-trip unit test for each RequestResult case (encode→decode→assert same kind/payload) to lock the auto-synthesized enum coding against accidental case-key changes that would conflate translate/photoTranslate.

### L11. History append errors (including cancellation) are silently swallowed via try? across all request use cases
- **Файл:**  — 41-43, 81-83, 124-126, 149-151, 183-184, 241, 277
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** Every request interactor records history with `try? await history.append(...)`. The non-fatal intent is reasonable (the result returns regardless of logging), but try? also discards a CancellationError thrown by append — if the surrounding Task was cancelled exactly during append, the use case still returns a value as if it completed normally instead of propagating cancellation — and a RepositoryError.persistenceFailed is lost with no telemetry, so a broken history repo is undetectable.
- **Фикс:** Keep the non-fatal intent but distinguish causes: surface persistence errors through a logger/diagnostic hook rather than try?, and check Task.isCancelled (or rethrow CancellationError) instead of blanket-swallowing so a cancelled request doesn't return a 'successful' result.

### L12. recent(limit:) silently drops history rows whose stored result fails to decode
- **Файл:**  — 84-90
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** recent() maps with compactMap { try? $0.toDomain() }, so any HistoryModel whose JSON resultData fails to decode (RequestResult schema drift, a future-added/removed enum case, or partially-written data) is silently swallowed — the user just sees shorter history with no error and no log. This is inconsistent with the rest of the layer (toDomain()/init deliberately throw RepositoryError.persistenceFailed; append() propagates), and defeats those typed errors precisely in the read path where a decode mismatch is most likely, masking the very schema-evolution bug testing would otherwise catch.
- **Фикс:** Either map with try so a corrupt row surfaces (and the VM shows its .failed state), or if best-effort is intentional, log the decode error (assertionFailure in DEBUG) before dropping so silent data loss is observable. Document that drops are intentional and tie RequestResult Codable to a stable coding-key contract.

### L13. HistoryModel.kindRaw is persisted on every insert but never read — dead storage that compounds the silent-drop bug
- **Файл:**  — 49, 57, 67-74
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** kindRaw is written on every insert (entry.kind.rawValue) but is never read anywhere — toDomain() recomputes kind from the decoded RequestResult and never consults kindRaw, and no fetch predicate filters on it. Pure dead storage, and a latent trap: because kind is only recoverable by fully decoding resultData, a row whose result JSON fails to decode loses its kind entirely (compounding the recent() silent-drop finding) even though a perfectly good kindRaw is sitting right there.
- **Фикс:** Either drop kindRaw to avoid dead schema, or actually leverage it — store AND use it to render/group history and to recover the kind when resultData can't decode, reducing total dependence on JSON decode succeeding.

### L14. History prune cap (100) is half the read limit (200) — the VM's requested capacity is unreachable
- **Файл:**  — 60, 73-82
- **Категория:** correctness · **уверенность:** high
- **Проблема:** SwiftDataHistoryRepository prunes everything beyond maxEntries=100 on every append, but the only caller (HistoryViewModel) requests recent(limit: 200). The store therefore never holds more than 100 entries, so the screen silently shows at most half of what its code asks for. A confusing inconsistency: whoever set limit=200 expected up to 200 to exist.
- **Фикс:** Make the two numbers agree — raise maxEntries to match/exceed 200 or lower the VM limit to 100 — and ideally expose maxEntries as a shared constant the read limit derives from.

### L15. append() reports failure to the caller when only the post-insert prune failed (insert actually succeeded)
- **Файл:**  — 62-70
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** append() saves the new entry then calls pruneBeyondLimit() inside the SAME do/catch. If insert+first save succeeds but the prune's fetch or second save throws, append() throws RepositoryError.persistenceFailed even though the request WAS logged. Harmless today (call sites use try?), but the contract is wrong: a non-fatal housekeeping failure is reported as an append failure, so a future caller that surfaces append errors would show a spurious error after a successful log.
- **Фикс:** Wrap only insert+save in the throwing path; run pruneBeyondLimit() best-effort in its own do/catch that logs but does not rethrow, so a pruning hiccup never masks a successful append.

### L16. Optimistic save can be silently deleted when results are regenerated mid-save
- **Файл:**  — 334-344
- **Категория:** concurrency · **уверенность:** high
- **Проблема:** toggleSave starts a background enrich+store Task and, on completion, keeps the stored id only `if self.savedVariantIDs.contains(id)`, else deletes it as 'unsaved while saving'. But run() clears savedVariantIDs = [] whenever a new result set arrives. If the user taps save and then regenerates / changes tone or mode before the store completes, the completion sees the cleared set and deletes a perfectly valid, just-persisted Expression — silently. Variant IDs also differ across regenerate (PhraseVariant.id is freshly minted on decode), so the new set can never re-match.
- **Фикс:** Distinguish 'user explicitly unsaved this id' from 'the result set was replaced': track an explicit pending-cancellation set or capture a generation token at save time, and only delete-on-supersede when the user actually toggled it off — not merely because savedVariantIDs was reset by new results.

### L17. Switching mode in the .failed phase leaves a stale error on screen with a Retry that re-runs the new mode
- **Файл:**  — InViewModel.swift:238-249; VoiceViewModel.swift:220-230
- **Категория:** state-machine · **уверенность:** high
- **Проблема:** selectMode only re-runs or resets when phase is .result/.processing (In) or .results/.processing (Voice). In the .failed phase with input present, switching the segment changes mode but never resets phase: InViewModel clears result fields but only does `if phase == .result { phase = .idle }` (so .failed persists), and VoiceViewModel runs neither branch for .failed. The screen keeps showing the old error StatusView (old errorMessage/isOffline) even though the user changed mode, and the now-stale Retry re-runs in the new mode.
- **Фикс:** Treat .failed like the no-input case: on a mode switch, if canSubmit re-run submit(); otherwise clear results AND reset to .idle for any non-active phase (phase == .result || phase == .failed), also clearing errorMessage/isOffline so the stale error disappears.

### L18. InViewModel.mode is publicly settable, bypassing the re-run/reset logic VoiceViewModel deliberately enforces
- **Файл:**  — 33
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** `public var mode: Mode = .explain` is fully public-set, unlike VoiceViewModel which makes it `public private(set) var mode` with the note 'only selectMode mutates, preserving its re-run logic.' Any caller writing vm.mode = .translate directly would silently skip selectMode's re-run/clear logic, leaving results from the other mode on screen. startExplain writes mode internally (fine), but the public setter invites the same bug from outside.
- **Фикс:** Make it `public private(set) var mode: Mode = .explain` to match VoiceViewModel; startExplain and selectMode (both inside the type) can still assign it, enforcing that mode changes always go through the re-run/clear logic.

### L19. Add sheet retains stale text and error after Cancel / successful dismiss
- **Файл:**  — StudyListViewModel.swift:83-103; StudyListView.swift:153
- **Категория:** ux · **уверенность:** high
- **Проблема:** newEnglish/newContext/addError are cleared only inside the SUCCESS branch of add(). Tapping Cancel (StudyListView sets showAddSheet=false) leaves newEnglish, newContext, and any prior addError populated, with no onDisappear/onChange reset. Reopening the add sheet (or opening after a failed add) shows the previously-typed text and the stale red error — an old error can appear over fresh valid input. The isAdding flag is also not reset on cancel.
- **Фикс:** Add a resetAddForm() (clears newEnglish/newContext/addError) and call it when the sheet is dismissed — in the Cancel action and/or via .onChange(of: showAddSheet) when it becomes false — so each open starts clean.

### L20. Export silently does nothing when the temp-file write fails
- **Файл:**  — 48-53, 166-174
- **Категория:** error-handling · **уверенность:** high
- **Проблема:** On Export, the VM produces an ExportedDeck and onChange(of: model.exportedDeck) writes it to a temp file. writeTemp returns nil on a write failure and the guard `if let deck, let url = writeTemp(deck)` falls through: no share sheet, clearExport() is NOT called (so exportedDeck stays non-nil and onChange won't re-fire for an identical retry), and no error alert. The user taps Export and nothing happens. The model has an exportError channel for 'nothing to export' but this filesystem failure bypasses it.
- **Фикс:** Handle the nil branch: on write failure set an export error and clearExport() so the existing .alert surfaces, e.g. `if let deck { if let url = writeTemp(deck) { shareItem = ... } else { model.reportExportWriteFailure() }; model.clearExport() }`.

### L21. Library photo import failure is silently swallowed (loadTransferable/prepare errors discarded)
- **Файл:**  — 44-53
- **Категория:** ux · **уверенность:** high
- **Проблема:** The library flow is driven by .onChange(of: libraryItem) and resets libraryItem=nil after loading. If loadTransferable throws or prepareImageData rejects the data, libraryItem is still cleared via `try?` and no error is shown — a failed pick looks identical to no action, so the user gets no feedback on a library load/prepare failure.
- **Фикс:** On the failure branch (loadTransferable throws or prepareImageData returns nil) set a user-visible error so a failed import isn't silently swallowed; the try? currently discards the thrown error entirely.

### L22. Action button keeps the 'Find phrasings' label/icon while it actually regenerates
- **Файл:**  — 82-85, 100-102
- **Категория:** ux · **уверенность:** high
- **Проблема:** The primary EHButton always shows actionTitle ('Find phrasings'/'Suggest phrases') with the 'sparkles' icon and calls model.pick(). Once phase == .results, pick() routes to regenerate() (a different variant set), but the text/icon never change to communicate 'More options'/'Try again'. canPick stays true in .results, so the user sees an unchanged button that silently replaces the current results — a discoverability/UX gap with no visible 'regenerate' affordance.
- **Фикс:** Switch the label/icon when phase == .results (e.g. 'Другие варианты'/'More options' with arrow.triangle.2.circlepath) so the action matches what the button says.

### L23. Switching interface language mid-flow can drop transient view-local state (pending export share)
- **Файл:**  — 50-70
- **Категория:** state-machine · **уверенность:** high
- **Проблема:** The TabView carries .id(language.language), so changing interface language tears down and recreates every tab's view tree. View-model @State survives (models held by RootView), but each screen's view-local @State resets: PhotoTranslateView.libraryItem, StudyListView.shareItem, @FocusState, scroll positions. Changing language from Settings while a share sheet or just-resolved exportedDeck is pending in StudyListView resets shareItem and loses the export UI. An accepted trade-off for live language switching, but an edge-case state loss worth noting.
- **Фикс:** If it matters, hoist genuinely transient cross-language state (pending share item) into a model held by RootView, or guard/debounce language switches while a share/export is in flight; otherwise document the reset.

### L24. PhraseVariantCard speaker animation is not gated on Reduce Motion (MicButton is) — inconsistent
- **Файл:**  — 46
- **Категория:** accessibility · **уверенность:** high
- **Проблема:** While playing, the speaker glyph runs a continuous .variableColor.iterative symbol animation with isActive: isPlaying and NO Reduce Motion check. MicButton deliberately gates the identical effect with isActive: !reduceMotion (MicButton line 77), so a user with Reduce Motion enabled still gets a perpetually pulsing icon here — exactly the repeating motion Reduce Motion is meant to suppress.
- **Фикс:** Read @Environment(\.accessibilityReduceMotion) and gate it: `.symbolEffect(.variableColor.iterative, isActive: isPlaying && !reduceMotion)`, mirroring MicButton.

### L25. PhraseVariantCard VoiceOver label hardcodes the English register word regardless of interface language
- **Файл:**  — 87
- **Категория:** localization · **уверенность:** high
- **Проблема:** The combined VoiceOver label interpolates register.rawValue — the raw enum string 'formal'/'casual'/'slang' (always English) — into a sentence otherwise built from localized content. A Russian/French/etc. VoiceOver user hears the register tier read out in English mid-phrase. (The visible RegisterTagView chip is also English-only, but it is a stylized monochrome chip; the spoken label is where the lack of localization is most jarring.)
- **Фикс:** Add a localized spoken name to RegisterLevel (e.g. var spokenName via DSLoc.t) and use it in the accessibilityLabel instead of rawValue.

### L26. Decorative language-code motif (RU EN FR ES DE IT) is read out by VoiceOver as six separate elements
- **Файл:**  — 126-138
- **Категория:** accessibility · **уверенность:** high
- **Проблема:** The hero's decorative language-code capsules are purely visual ('Decorative motif reinforcing the multilingual theme') but are plain Text views with no accessibilityHidden(true). VoiceOver stops on and announces each of the six codes as standalone elements before the user reaches the meaningful Welcome / Choose-your-languages content and the pickers, adding noise to the first-launch screen.
- **Фикс:** Add .accessibilityHidden(true) to the decorative HStack so assistive tech skips the motif.

### L27. EHButton uses .buttonStyle(.plain) so .disabled() does not dim it — silent dead buttons
- **Файл:**  — 48
- **Категория:** ux · **уверенность:** high
- **Проблема:** .buttonStyle(.plain) disables the system's default disabled appearance and EHButton applies no opacity treatment of its own, so EHButton(...).disabled(true) yields a button that looks fully tappable but is non-interactive. The only disabling call site (VoiceView 86-87) has to manually add `.opacity(canPick ? 1 : 0.5)`. Any future caller that forgets the manual opacity ships a button that looks enabled but does nothing — a UX trap baked into a shared component.
- **Фикс:** Make the component own its disabled state: read @Environment(\.isEnabled) and apply `.opacity(isEnabled ? 1 : 0.5)` (and skip the action) inside EHButton, so .disabled() Just Works and call sites can drop the manual opacity.

### L28. CopyButton's copied-state lockout + timing diverge from PhraseVariantCard's duplicated inline copy logic
- **Файл:**  — 52-57, 94-102
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** PhraseVariantCard reimplements CopyButton's copy-with-confirmation inline instead of reusing CopyButton, and the two have drifted: CopyButton adds .allowsHitTesting(!copied) (CopyButton line 50) so rapid double-taps can't re-fire the haptic and spawn overlapping reset Tasks, and uses a 1.6s window; PhraseVariantCard has no lockout and a 1.5s window, so double-tapping fires a second success haptic and a second Task.sleep whose earlier completion flips the check back early. Minor, but classic copy-paste drift.
- **Фикс:** Reuse CopyButton(english, style: .icon, ...) in PhraseVariantCard's action row, or extract the confirm-state machine into one shared helper so the lockout/timing live in a single place.

### L29. EHButton.glass re-implements the Reduce-Transparency glass fallback instead of going through glassPanel
- **Файл:**  — 61, 68-81
- **Категория:** architecture · **уверенность:** high
- **Проблема:** CLAUDE.md states 'all glass goes through glassPanel' so the solid Reduce-Transparency fallback stays consistent. EHButton's .glass kind instead uses a private CapsuleGlass ViewModifier that re-implements the accessibilityReduceTransparency ? solid : material branch. Correct today, but a second source of truth: if the canonical GlassPanel logic changes (material tier, stroke), this capsule variant silently won't.
- **Фикс:** Drive the glass background through the canonical path — parameterize GlassPanel's shape to support a capsule, or apply .glassPanel(cornerRadius: Tokens.Radius.pill) and clip to a Capsule — so the fallback lives in exactly one place.

### L30. RegisterTagView strokes its border at hardcoded 1pt instead of Tokens.Hairline.width
- **Файл:**  — 42
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** The tag outline uses lineWidth: 1, bypassing the single-source-of-truth hairline token Tokens.Hairline.width (0.5pt) used elsewhere (EHButton line 44, GlassPanel line 29). The slang tag is outline-only, so this is the most visible border in the component, rendering at double the kit's hairline weight — off-spec and not centrally tunable.
- **Фикс:** Use lineWidth: Tokens.Hairline.width (or a dedicated register-border token) so the border matches the rest of the system and stays a single source of truth.

### L31. bootLive hardcodes the SwiftData model list instead of using PersistenceSchema.models (SSOT defeated)
- **Файл:**  — 97
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** The Data layer exposes PersistenceSchema.models documented as 'the model types the app's ModelContainer must register,' but bootLive ignores it and writes ModelContainer(for: ExpressionModel.self, HistoryModel.self) literally — two places now enumerate the persisted @Model types. When a third @Model is added (the app is explicitly growing), a developer who updates the obviously-named SSOT won't change behavior, because container creation here won't see the new type, so it silently fails to persist/fetch with no compiler error pointing here. This is exactly the drift PersistenceSchema was created to prevent.
- **Фикс:** Drive the container from the SSOT: `let modelContainer = try ModelContainer(for: Schema(PersistenceSchema.models))`, so adding a model is a one-line edit in PersistenceSchema and the composition root stays correct automatically.

### L32. VisionTextRecognizer / textRecognizer port is wired and instantiated but never consumed (dead DI, contradicts docs)
- **Файл:**  — 24, 65, 113
- **Категория:** architecture · **уверенность:** high
- **Проблема:** The container declares `public let textRecognizer: any TextRecognizing`, takes it in init, stores it, and bootLive constructs a real VisionTextRecognizer() — but the property is never read by any use-case constructor or VM factory: PhotoTranslateInteractor is built with llm + history only (line 74 comment: 'LLM vision (no local OCR)'). So the OCR adapter is allocated for nothing on every live boot, the wiring misleads readers into thinking photo translation routes through TextRecognizing, and the '← swap OCR engine here' comment promises a swap point that affects nothing. This also contradicts CLAUDE.md/README, which describe the photo flow as 'OCR (+ boxes) → RU translation' and list TextRecognizing as an active port, while the screen actually sends the image straight to Claude vision.
- **Фикс:** Either remove textRecognizer/TextRecognizing from the container/init/bootLive/bootMock entirely (and drop the unused VisionTextRecognizer), or actually route PhotoTranslateInteractor through it if local OCR is intended. Update CLAUDE.md/README so docs and wiring agree that photo translation uses Claude vision.

### L33. LanguageStore.locale reads UserDefaults instead of the @Observable-tracked language property
- **Файл:**  — 141
- **Категория:** correctness · **уверенность:** high
- **Проблема:** locale is derived from AppLanguage.effective, which re-reads UserDefaults via AppLocale.currentCode(), NOT from the @Observable-tracked self.language. It works today only because RootView applies .environment(\.locale, language.locale) on the same view as .id(language.language) — the sibling .id reads the tracked property so the whole body re-runs on change, and the setter's didSet persists synchronously first. But computing locale from UserDefaults registers NO @Observable dependency on language; any future view binding language.locale without also touching language.language would see the environment locale silently stop updating, and it can diverge from self.language for any in-memory-only change.
- **Фикс:** Derive from the tracked property so observation works and the value can't drift: `public var locale: Locale { Locale(identifier: language.rawValue) }`.

### L34. AppLanguage.stored is dead public API overlapping confusingly with AppLanguage.effective
- **Файл:**  — 122-124
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** AppLanguage.stored (explicit-choice-or-nil) is declared public but is referenced nowhere in Presentation/App/Tests. It duplicates resolution logic that already lives in AppLocale and can drift from it; unused public surface invites a future caller to use stored (raw UserDefaults of interfaceLanguage) and get behavior subtly different from effective/AppLocale.currentCode() (which also consults the system default).
- **Фикс:** Remove stored, or make it internal and add a test, so the resolution path stays centralized in AppLocale.

### L35. AppLocale.currentCode() reads UserDefaults on every Loc.t call (no cache)
- **Файл:**  — 34-39, 46, 58
- **Категория:** performance · **уверенность:** high
- **Проблема:** Both DSLoc.t overloads call AppLocale.currentCode() on every invocation, doing a fresh UserDefaults.standard.string(forKey:) lookup plus a supported.contains() linear scan. With 274 Loc.t/DSLoc.t call sites all evaluated inside SwiftUI view bodies (re-run on every state change/redraw), this fires the UserDefaults read thousands of times during scrolling/typing — cheap individually but synchronized and non-trivial at volume, for a value that only changes on language switch. No caching layer.
- **Фикс:** Cache the resolved code (a static stored property invalidated when the language picker writes the new value, or read UserDefaults once into a process-lifetime cache reset from the Settings write path). Hook cache invalidation into the existing language-change refresh path.

### L36. Stale 'RU / EN' MARK comments mislabel sections that now support six languages
- **Файл:**  — 112, 155, 217
- **Категория:** maintainability · **уверенность:** high
- **Проблема:** Section headers still describe two-language behavior after the move to six: '// MARK: - Interface language (RU / EN, default: system)', '// MARK: - Target language for "In" translation (RU / EN, default: RU)', and the studied header '(RU/EN/FR/ES, default: English)'. The actual enums each have six cases (ru/en/fr/es/de/it), so these comments mislead a future maintainer about the supported set and default-resolution rules.
- **Фикс:** Update the three MARK comments to '(RU/EN/FR/ES/DE/IT, default: system)' / '(…, default: RU)' / '(…, default: English)' to match the enums and the documented six-language support.

### L37. ConnectionHealth: requestFailed reason inferred by fragile substring matching; cancelled mapped to a spurious 'Connection error'
- **Файл:**  — 37-41
- **Категория:** error-handling · **уверенность:** medium
- **Проблема:** The use case classifies offline/timeout via info.contains("offline")/info.contains("timed out") on LLMError.requestFailed's free-form string — the same brittle cross-module coupling described in the LLMError-typing finding, with no compiler/test enforcement. Separately, callAsFunction() catches LLMError.cancelled and returns .failed(.unknown), which SettingsViewModel.check() renders as 'Connection error'. If the health round-trip is cancelled (Settings sheet dismissed and its Task torn down, or a structured-concurrency parent cancels), the user — if the view is still alive — sees a false connection failure. Cancellation is not a connectivity fault. check() also assigns state with no Task.isCancelled guard, so the cancelled branch can still set state.
- **Фикс:** Switch on dedicated LLMError.offline/.timedOut cases instead of substring-sniffing requestFailed. Treat cancellation as non-terminal: return a dedicated .cancelled health state (or rethrow) that check() maps to leaving the prior status unchanged, and guard `if Task.isCancelled { return }` before assigning `health` on the cancelled path.

### L38. Speech synthesizer: nil voice can hang the stream forever, and the .playback session is never deactivated
- **Файл:**  — 34-51, 75-81
- **Категория:** error-handling · **уверенность:** medium
- **Проблема:** Two lifecycle defects. (1) If AVSpeechSynthesisVoice(language:) returns nil for both the studied language and the 'en-US' fallback (uncommon tag with no installed voice, or a malformed locale from localeProvider), utterance.voice is nil; on configurations where speak() then silently does nothing, no didStart/didFinish/didCancel fires, so the stream stays in .preparing forever — never yielding .finished, never throwing — and the consuming playTask (`for try await state in pronounce(...) where state == .finished`) hangs until the next play cancels it. There is no timeout or guard that speak actually began. (2) speak() activates the shared AVAudioSession with .playback/.duckOthers but never deactivates it; onTermination only stops speaking and didFinish/didCancel only finish the stream, so after every pronunciation .duckOthers stays active, ducking background audio (music) indefinitely. A user who only plays TTS (History/StudyList) leaves background audio ducked permanently.
- **Фикс:** After resolving the voice, if still nil throw SpeechSynthesisError.unavailable/.underlying immediately (and consider defensively yielding .finished if no didStart arrives within a short window). Deactivate/restore the audio session when playback ends — in didFinish/didCancel AND onTermination — e.g. setActive(false, options: .notifyOthersOnDeactivation), guarded so it doesn't fight the recognizer.

### L39. Recognizer teardown hops to MainActor via a detached Task — async, unordered, can tear down a freshly-started session
- **Файл:**  — 37, 131-141
- **Категория:** concurrency · **уверенность:** medium
- **Проблема:** onTermination calls session.stop(), which schedules a NEW @MainActor Task to perform teardown (cancel task, endAudio, engine.stop, removeTap, deactivate session). stop() returns immediately and teardown is enqueued, so there is no ordering guarantee teardown completes before the next transcribe() begins. transcribe() creates a fresh RecognitionSession with its own AVAudioEngine, but all sessions share the one AVAudioSession and physical input. A rapid stop→start (cancel capture then immediately re-listen) can interleave: the new session activates the audio session and installs its tap while the old session's queued teardown then runs removeTap/engine.stop/setActive(false), tearing down the just-started capture. The realtime tap append on the OLD engine could still be firing during the hop.
- **Фикс:** Make teardown synchronous and ordered: remove the tap and stop the engine immediately in onTermination (marshalled once if needed), and serialize begin()/stop() so a new session cannot activate audio before the previous one's teardown finishes.

### L40. Cancelled capture stream can overwrite the input field after the user stops listening
- **Файл:**  — VoiceViewModel.swift:129-148; InViewModel.swift:131-150
- **Категория:** concurrency · **уверенность:** medium
- **Проблема:** The capture Task writes self.intent = transcript.text (Voice) / self.source = transcript.text (In) on every yielded value. stopListening() cancels the task and immediately calls submit(), which snapshots the current text. But cancellation is cooperative: if a transcript value was already buffered/in-flight in the for-await loop, the loop body may run once more and overwrite intent AFTER the user's stop — so the visible field and the submitted text can momentarily diverge. Low impact (a final partial transcript) but an await-after-state-change ordering hazard.
- **Фикс:** Guard the stream writes on phase: `for try await transcript in self.voiceCapture() { guard self.phase == .listening else { break }; self.intent = transcript.text }`, so a late value cannot mutate the field once the user has left the listening state.

### L41. loadSavedState races against user bookmark toggles in HistoryDetailViewModel
- **Файл:**  — 52-73
- **Категория:** concurrency · **уверенность:** medium
- **Проблема:** loadSavedState() awaits studyList.list() then unconditionally mutates savedKeys/savedIDs. If the user taps a bookmark during that await (toggle() runs on the same MainActor while loadSavedState is suspended), loadSavedState resumes and overwrites state without checking current values: for a just-UN-saved key, insert(key)+savedIDs[key]=id re-marks it saved and points at a list row toggle's delete may already be removing (phantom bookmark whose stored ID is being deleted); for a just-SAVED key, it overwrites savedIDs[key] with the old list's ID, so a later un-save deletes the wrong row and orphans the freshly-enriched one. toggle()'s optimistic pattern guards its own reordering but loadSavedState does not coordinate with it.
- **Фикс:** Only seed keys not already touched by the user: guard each insertion with `if !savedKeys.contains(key) && savedIDs[key] == nil`. Better, capture a monotonically-increasing token before the await and bail the seeding if a user toggle bumped it during the await.


## 🔎 Находки критика полноты (6)

### C1. [MEDIUM/localization] Photo screen navigation title shows the wrong word in FR/ES/DE/IT (uses the camera-tab key "See it")
- **Файл:**  — 36
- **Проблема:** The localization catalog (DesignSystem/LocCatalog.swift) is keyed by the EXACT English string passed to Loc.t. The photo screen's navigation title is built with `Loc.t("Фото-перевод", "See it")` — Russian = "Фото-перевод" (Photo translation) but the English key = "See it". "See it" is the camera TAB label (RootView.swift:54 `Tab(Loc.t("Смотреть", "See it"), ...)`), and the catalog maps the key "See it" to the tab word: fr "Voir", es "Ver", de "Sehen", it "Vedere". So for a French/Spanish/German/Italian user the screen's navigation title reads "Voir"/"Ver"/"Sehen"/"Vedere" (the verb "see") instead of "Photo translation" — even though the catalog HAS the correct separate key "Photo translation" (fr "Traduction photo", de "Foto-Übersetzung") used elsewhere (HistoryView.swift:285). RU and EN are unaffected because they're inline; only the four catalog languages get the wrong title. The intent is two distinct strings (RU distinguishes them: title "Фото-перевод" vs tab "Смотреть"), but the shared English key collapses them.
- **Фикс:** Pass the English key that matches the intended title: `Loc.t("Фото-перевод", "Photo translation")` (that key already exists in LocCatalog for all four languages). More generally, add a build/test check that flags any English key used at call sites with differing Russian companions (grep already finds `Say it`->{"Как сказать","Сказать"} and `See it`->{"Фото-перевод","Смотреть"}).

### C2. [LOW/localization] Navigation title "Say it" key also reused for the Voice tab — FR/ES/DE/IT title and tab collapse to one word
- **Файл:**  — 38
- **Проблема:** Same catalog-key-collision class as the Photo title. VoiceView's navigation title is `Loc.t("Как сказать", "Say it")` (RU "Как сказать" = "How to say") but the English key "Say it" is the Voice TAB label (RootView.swift:57 `Tab(Loc.t("Сказать", "Say it"), ...)`, RU "Сказать"). For the four catalog languages, the key "Say it" resolves to one shared word (fr "Dire", es "Decir", de "Sagen", it "Dire"), so the screen title and the tab label read identically — losing the RU/EN distinction where the title is the fuller "Как сказать"/"How to say". Less jarring than the Photo case (both are about speaking), but it is the same unintended key reuse, and the catalog has a separate "How to say" key (fr "Comment dire") the title should use.
- **Фикс:** Use a key matching the intended title, e.g. `Loc.t("Как сказать", "How to say")` (already in the catalog), so the four non-RU/EN languages get the descriptive title rather than the short tab verb. Same root fix as the Photo-title finding.

### C3. [LOW/correctness] Studied language and native language can be set to the SAME language — degenerate translate/explain into itself
- **Файл:**  — 142-182
- **Проблема:** Both the Studied (`StudiedLanguage.allCases`) and Native/Target (`TargetLanguage.allCases`) pickers expose all six languages independently with no mutual-exclusion or validation, in BOTH Settings (studiedCard/targetCard) and Onboarding (OnboardingView.swift:61-80). Nothing prevents studied == native (e.g. both Russian). InViewModel.submit() then calls `understand(text, studiedLanguage: studiedLang, nativeLanguage: nativeLang)` / `explain(... studiedLanguage:nativeLanguage:)` with two equal language names (StudiedLanguage.current.promptName / TargetLanguage.current.promptName), asking Claude to render the input in language X and also translate/explain it into the same language X — a degenerate prompt that produces a redundant or confusing result, and the saved study card's front (studied) and gloss (native) are then in the same language. The same applies to the Voice/'Say it' source language. It is reachable purely through the UI with no guard or warning.
- **Фикс:** Either prevent the collision (disable the matching chip in the other picker, or auto-adjust the other selection) or surface a non-blocking warning. At minimum, guard in InViewModel.submit()/the use cases so studied==native short-circuits to a plain pass-through instead of issuing a self-translation prompt.

### C4. [LOW/correctness] AnkiExporter: a card whose front begins with '#' becomes an Anki directive/comment line and is dropped on import
- **Файл:**  — 27-45
- **Проблема:** The Anki export writes directive lines that start with '#' (#separator, #html, #deck, #columns), and modern Anki treats any line beginning with '#' as a comment/directive during text import. Each card row is written as `\(front)\t\(back)` where front = field(e.en). field() neutralizes tab/CR/LF but does NOT escape or guard a leading '#'. So a study expression whose English text starts with '#' (e.g. "#1 priority", "#blessed", a hashtag captured via OCR/clipboard) produces a data line like `#1 priority\t...` that Anki parses as a directive/comment and silently skips — the card vanishes from the imported deck with no error. This is the Anki analogue of the AlgoApp control-char export finding, and it is reachable because AnkiExporter is live-wired (AppContainer.swift:80, surfaced via StudyListViewModel.ExportFormat.anki).
- **Фикс:** Prevent a leading '#' on a data row: wrap fields in HTML (the #html:true header is already set) so the front never starts with a literal '#', or escape/prefix a leading '#'. Emitting the front inside a `<div>` keeps every card importable.

### C5. [LOW/error-handling] Failed study-list delete is swallowed and never reverted; row silently reappears on next load
- **Файл:**  — 105-123
- **Проблема:** delete() optimistically removes the row from `expressions` (and may set phase=.empty), then fires `try? await self.studyList.delete(id:)` discarding any RepositoryError.persistenceFailed. If the SwiftData delete throws, the UI shows the item gone but the store still has it, so the next load() (returning to the tab, or after an add) repopulates the row — it 'comes back from the dead' with no explanation, and an export in between omits a card that is actually still saved. The same swallow exists in toggleLearned() (line 119-122): a failed setLearned leaves the toggle visually flipped but the persisted value unchanged, diverging until the next load reverts it. Unlike the add path, no errorMessage is surfaced for either.
- **Фикс:** On a thrown delete/setLearned, re-insert/re-flip the optimistic change and surface a transient error (mirroring the add path's addError), so the visible list can't silently diverge from the persisted store.

### C6. [LOW/ux] Inconsistent naming of the comprehension screen across onboarding, settings, and hints
- **Файл:**  — 166-175
- **Проблема:** The Native-language helper text says the language is used 'on the Get it screen' (RU «Понять»; catalog fr 'l'écran Comprendre'), but the actual tab is labelled with the key 'Get it' rendered as the tab word 'Понять'/'Get'/'Comprendre' (RootView.swift:60 `Tab(Loc.t("Понять", "Get it"), ...)`). Several strings drift between 'Get'/'Get it'/'Understand' for the same screen (the catalog has both 'Get':'Comprendre' and 'Get it':'Comprendre'; the empty-study hint references «Понять»/'Understand'). The user-facing name of this one screen is inconsistent across the onboarding subtitle, the settings subtitle, and the empty-state hint, which is confusing for a feature whose point is clarity.
- **Фикс:** Pick one canonical name for the comprehension screen and use it verbatim everywhere (tab, both subtitles, the empty-state hint) in every language, so the helper text names the screen exactly as its tab shows it.


## Приложение: отклонённые находки (ложные срабатывания, 13)

_Верификаторы прочитали реальный код и опровергли эти находки — оставлены для прозрачности._

- **PhraseVariant synthesizes a fresh random id on every decode, breaking value-equality and identity stability across persistence round-trips** ()
- **RecognizableImage is Equatable over raw image Data, causing full-buffer byte comparison** ()
- **PhotoBlocks empty-array result silently selected as the answer under prose-wrapped output** ()
- **enrichCard userMessage treats whitespace-only known_ru as a real gloss** ()
- **Single-field decoders rely on extra-key tolerance and can decode the wrong (echoed) candidate** ()
- **Speech recognizer maps a successful final result's trailing error into a spurious failure** ()
- **AVAudioSession deactivated unconditionally on stop, stealing/duckings shared with the synthesizer and other audio** ()
- **Vision boundingBox vertical flip uses rect origin without accounting for height — top-left y is off by box height** ()
- **Settings health check: overlapping check() calls can let a stale result win** ()
- **Studied/Native/Tone language changes are propagated only via UserDefaults with no observable notification — stale generation if read before didSet persists or if read off-MainActor concurrently** ()
- **Interface-language change is not observed by Loc.t; views may show stale language until a full redraw** ()
- **GlassField uses a vertical-axis TextField with .submitLabel(.go)/.onSubmit, which inserts a newline rather than submitting on iOS** ()