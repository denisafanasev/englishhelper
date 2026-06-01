# RUN — launch procedure for EnglishHelper

Run the prompts in order. Do NOT skip a gate. Each step is a separate Claude Code session
(clean context beats dragging the previous step's noise forward).

---

## Prep (once)
- `Secrets.xcconfig` with the Claude API key in place (gitignored). v1 hits the live API on screen 1.
- Design system files present at `design_system/englishhelper/project/`.
- Prompts live in the repo (e.g. `docs/prompts/`) so you can reference them by path.

## Step 0 — Extract tokens
```
Read docs/prompts/00-extract-tokens.md and execute it.
```
GATE: verify the token table by eye (especially scrim.* and register tags) → commit `Tokens.swift`.
The HTML is now archived, not the source of truth.

## Step 1 — Scaffold
```
Read docs/prompts/01-init-scaffold.md and execute it.
```
GATE (all three must pass before Step 2):
1. Compiles and launches to a placeholder. (`xcodebuild -scheme EnglishHelper build` or ⌘B)
2. All ports defined + each has a `Mock*`; DI boots on mocks.
3. `Secrets.xcconfig` gitignored; `Secrets.example.xcconfig` committed; Info.plist usage strings set.
Then: confirm `CLAUDE.md ## Current Status` is filled →
`git commit -m "scaffold: clean architecture skeleton on mocks"`.

## Step 2 — V1 (new session)
```
Read CLAUDE.md to load current state, then read docs/prompts/02-v1-development.md and execute it.
Build it incrementally per the Build order — stop after each screen so I can build and verify.
```
GATE: `xcodebuild test -scheme EnglishHelper` green — forbidden-import, Stub* latency/failure,
history-append, enrich-no-markdown, XML well-formed. Commit after each screen.

---

## Order summary
Step 0 (tokens) → verify → Step 1 (init) → 3 gates + commit → Step 2 (v1, screen by screen).
