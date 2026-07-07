# What's New

Release notes for **Gist It** (formerly EnglishHelper), written for the people who use it.

## 1.3.2 — 2026-07-07

**Anonymous usage insights.** Gist It now counts how often its features are used — a translation
finished, a phrase saved, a deck exported — so future updates can focus on what actually gets used.
What you type, say, or photograph is **never** part of it: the app sends bare event names only
("translation completed"), with no text, no photos, and no way to attach them. Analytics run
through [TelemetryDeck](https://telemetrydeck.com), a privacy-first service that keeps no personal
profiles and uses no advertising identifiers — which is why there's no tracking-consent pop-up:
there is simply nothing to consent to.

## 1.3.1 — 2026-07-02

**A new name: Gist It.** EnglishHelper is now **Gist It** — a name that finally fits what the app
does: help you catch the gist of the world around you and say what you mean, in any of its six
languages, not just English. It's the same app underneath — your saved phrases, history, and
settings are untouched; only the name on your Home screen changes.

**Screens keep their state.** Switch tabs freely: every screen now comes back exactly as you left
it — the generated phrases or translation still on screen, the text they were made from, and your
chosen mode (How to say / What to say, Explain / Translate) and tone. Modes now also survive an app
restart, like the tone always has — and only the mode you pick on the screen itself is remembered:
opening something via a widget, the Share sheet, or an "Explain" button doesn't change your saved
choice. If you edited the input but never pressed the button, the edit is dropped when you leave —
so what's in the field always matches the results below it, and a new set is generated only when
you actually ask for one. Leaving a screen mid-dictation now also switches the microphone off.

**Much steadier on a weak mobile signal.** The connection layer was reworked around bad-network
reality: answers now **stream** from the model, so a long answer is never cut off just for taking
its time (previously a slow photo translation could hit a timeout and be retried at full cost); a
connection that drops right as you ask now fails fast with a clear message — no more sitting on
"processing" for minutes — and the app **re-checks the network before every retry** instead of
retrying into a dead link. The moment you're back online, your last request still re-runs itself.

**Faster app start.** The app's storage now opens in the background during launch instead of
blocking the first screen — startup stays instant even as your history and study list grow.

**Model switch respects the cache.** If you change the model for a scenario in Settings, repeated
requests are answered by that model — not by cached results from the previous one.

**Lock Screen widgets.** Add Gist It to your Lock Screen for one-tap access to a scenario — no
unlocking and tapping through tabs. There are six, one per scenario: **See it · Explain**, **See it ·
Translate**, **Get it · Explain**, **Get it · Translate**, **Say it · How to say**, and **Say it ·
What to say**. Tapping one opens the app straight into that scenario with the **camera ready** (See
it) or the **mic already listening** (Get it / Say it). Each carries its own icon — the scenario's
camera / speech-bubble / mic glyph plus a small badge (a lightbulb for Explain and What-to-say, a
globe for Translate and How-to-say) — so the six are easy to tell apart. The look is yours to pick —
**Standard**, **Bordered**, or **Filled** — when you add or edit a widget. To add them: lock the
phone, touch and hold the Lock Screen, tap **Customize**, tap a widget slot, and pick **Gist It**.

**Any photo works now, including HEIC.** A photo shared or picked in **See it** could fail with an
error when it was in iPhone's default HEIC format. Every photo is now converted to a supported format
(and downscaled, so it uploads faster) before it's sent — so recognition and translation work no
matter where the photo came from.

**Walk away during a long request.** When a recognition or explanation takes a while, you no longer
have to keep the app open and wait. Leave it, and you'll get a notification the moment the result is
ready — tap it to come back to the result on the same screen.

**Smarter translation variants.** **Get it → Translate** now gives more than one translation only when
a word or phrase genuinely has different meanings depending on context (like an idiom that's both
literal and figurative), each with a short note on which sense it is — instead of padding the list
with near-synonyms.

**Instant repeat translations.** Translate or ask for phrasings of text you've already done — **Get
it · Translate**, **Say it · How to say**, **Say it · What to say** — and the result now comes
straight from the app instead of the model: instant, and it doesn't use your connection. Asking for
fresh variants ("other options") still goes to the model. A new **Translation cache** section in
**Settings** shows how much is stored and how often it's been reused, with a button to clear it.

**A newer, sharper model.** Everything except plain translation now runs on Anthropic's latest
**Claude Sonnet 5** — so the phrasings in **Say it**, the explanations, and photo translations come
back more natural and more accurate. Plain **Translate** still uses the faster model for speed. And
**Settings → About** now lists that **fast model** next to the main one, so you can see exactly which
models are in play.

**Fixes**

- **Switching Explain ↔ Translate after an error now retries** the same photo or text, instead of
  leaving the screen stuck on the error.
- **Explaining a phrase from a "See it" card** now explains just that phrase on its own, not the whole
  photo it came from.
- **Your per-scenario model choices now take effect** — plain Translate runs on the faster model as
  intended, and long photo translations are no longer cut short.
- **Sharing into the app** is more reliable at bringing Gist It to the front.

## 1.3.0 — 2026-06-21

**Share straight into the app.** EnglishHelper now shows up in the iOS Share sheet, so you can send
things to it from anywhere. **Share a photo** (from Photos, Safari, a chat…) and it opens in
**See it → Explain** — what the picture shows and the local or cultural context behind it. **Share
text** and it opens in **Get it → Explain** — the meaning, tone, and a familiar comparison for that
phrase. No copy-pasting or switching apps.

**Ask "why this one?" on "Say it".** Every phrasing you get now has a lightbulb. Tap it to learn why
that particular wording works — and how it differs from the other options you were given (for
example, "where have you been" vs. "where were you"). It opens the full Explain breakdown.

**Choose the model for each scenario.** A new section in Settings lets you pick which Claude model
powers **Say it**, **Translate**, and **Explain** separately. **Translate** now uses the faster
**Haiku** by default, so plain translations come back quicker; **Say it** and **Explain** stay on
**Sonnet** for depth. Settings also shows the live connection status of both models.

**Steadier on a weak mobile connection.** On a flaky cellular signal the app now rides out brief
drops (tunnels, lifts, tower hand-offs) instead of failing the instant the connection blinks. When
you're genuinely offline you'll see a clear **"No connection — waiting for the network"** banner, and
the moment you're back online the app **retries your last request automatically** — no tapping
required. Photos are also compressed before upload so they go through faster on a slow link.

**One consistent row of actions on every card.** Play, **Explain**, Copy, and Save now sit together
as a single tidy row of icons on every card — across "Say it", "Get it", "See it", "Study", and
History — so the controls are the same everywhere and the Explain shortcut is always within reach.
The icons are a little smaller and card titles are sized to match the text below them, for a calmer,
cleaner look.

## 1.2.5 — 2026-06-07

**German and Italian, everywhere.** You can now pick **German** or **Italian** as your interface
language, your studied language, or your native language — the whole app is translated into both, and
they work as targets for translation, phrase generation, and explanations just like the existing
languages.

**A welcome screen on first launch.** The first time you open the app it greets you and lets you
choose your three languages — interface, studied, and native — before you start. It opens in your
system language (or English) and switches live as you pick.

**Tidier action buttons on every card.** Play, Copy, and Save (and Explain in History) now sit
together in one row at the top of each card — on "Say it", "Get it", and in History — so the controls
are consistent and easy to find. Tapping a phrase still starts and stops playback as before.

**A slightly more compact look.** On-screen text is one point smaller across the app for a denser,
cleaner layout. The tab bar stays as it was.

**Fixes**

- **"What to say" no longer fails with "Couldn't parse the response."** On broad situations the
  service sometimes wrapped its answer in extra text; the app now reads the real result reliably.
  (Same fix protects every other screen.)
- **The Retry button is no longer hidden behind the tab bar** when something goes wrong on "Say it",
  "Get it", or "See it".
- **No more stray "Request cancelled" message** when you change mode or re-run while a request is
  still in flight.

## 1.2.4 — 2026-06-06

**"Say it" now has two modes.** A selector at the top of the screen lets you choose how it works:

- **How to say** — type or say a thought and get **3** natural phrasings of it in the tone you
  picked (as before): "how do I say I agree with them?", "let me through, please", and so on.
- **What to say** (new) — describe a **situation** ("a doctor's appointment", "booking a car
  service") and get the **most useful phrases for it** — anywhere from 3 to 10, depending on how
  many the app finds genuinely helpful — in the same card format and your chosen tone.

The field hint and the on-screen guidance adapt to the selected mode so the difference is clear, and
the tone selector applies to both.

## 1.2.3 — 2026-06-05

**Copy anything, with a clear confirmation.** Every copy button across the app now flips to a
checkmark with a "Copied" confirmation (and a light haptic), so you always know it worked.

**See it: copy both languages.** On a recognized block, Play / Copy / Explain now sit together on
one row (no wrapping), and you can copy either the text in the language you're learning or its
translation.

**History: copy from your past results.** Translation entries now let you copy both the
studied-language text and the translation, right from the detail view.

**Explain: copy the explanation.** The full explanation can be copied with the same one-tap
confirmation.

## 1.2.2 — 2026-06-04

**Explain now handles whole passages.** When you sent a longer, multi-line text to **Explain** —
for example a photo translation from History with several lines — it used to latch onto a single
word or phrase and explain only that. Now Explain covers the entire text as one coherent whole:
the overall meaning, the overall tone, where such text appears, and a familiar comparison — without
dropping the rest.

## 1.2.1 — 2026-06-04

**Explain anything in a photo.** On the "See it" screen, each recognized block now has an **Explain**
button. Tap it and you jump straight to the **Get it** screen in Explain mode for that phrase — with
the photo sent along, so the explanation fits where the text actually appears (a sign, menu,
screenshot, …). You get the full Get-it screen: play it, save it, copy it, or switch to a plain
translation.

**Explain from History too.** Open any past translation and tap **Explain** on the request to get the
same full breakdown on the Get-it screen.

**Copy from photos.** Each recognized block can be copied to the clipboard in the language you're
learning.

**Snap another photo, faster.** After a photo is recognized you can take or pick a new one right
there, without backing out first.

**Easier to read in Light mode.** Cards now have clearly visible edges on a light background (they
were nearly invisible before).

**History, tidied up.** The request and its translation are now visually distinct, and rows show a
single, clean arrow.

**Polish.** Copying an explanation shows a "Copied ✓" confirmation; the main tabs read
**See it / Say it / Get it**; and the "Get it" field now says it expects text in the language you're
learning (matching the microphone).

## 1.2.0 — 2026-06-04

**Learn any of four languages.** EnglishHelper is no longer English-only. In Settings, pick the
language you're **learning** — **English, Russian, French, or Spanish**. Every screen now works in
that language: it's what you see on the cards, save to your list, and hear spoken aloud.

**Your language, your way.** Separately choose your **native language** (English, Russian, French,
or Spanish). All translations and explanations come back in it.

**Bring text in any language.** Type, dictate, or photograph something in *any* language and the app
figures it out:
- **See it** — snap a sign or menu in any language; read it in the language you're learning, with a
  translation you understand.
- **Say it** — say what you mean in any language; get natural phrasings in the language you're
  learning, with notes in your own.
- **Get it** — paste anything; see and hear it in the language you're learning, understand it in
  your own, and (in Explain mode) get the nuance with a familiar comparison.

**App in four languages.** The interface itself is now available in **French** and **Spanish**,
alongside Russian and English — switch any time in Settings and it changes instantly.

## 1.1.0 — 2026-06-03

**Explain any English expression.** The "Get it" screen now has two modes. Keep using
**Translate** to get the meaning in your language — or switch to the new **Explain** mode to
really understand a phrase: what it actually means, how formal, casual, or blunt it sounds,
when and where it's used, and a familiar comparison from your own language. Type it or say it,
and tap to switch modes any time.

**Pick the tone while you practice.** On the "Say it" screen you can now choose the tone —
**Polite**, **Casual**, or **Slang** — right under the button. Change it and you instantly get
fresh phrasings in that tone. (Tone moved out of Settings, so it's always one tap away.)

**Friendlier screen names.** The three main screens are now **Get it**, **Say it**, and
**See it**.

**Clearer Settings.** "Translate to" is now called **Native language** — the language used for
both translations and explanations.
