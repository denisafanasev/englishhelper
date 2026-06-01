# Prompt 0 — EXTRACT DESIGN TOKENS

> Run this FIRST, in its own Claude Code session, before init.
> One-time extraction of the design system into Swift tokens. Verify the output table before moving on.

---

Read `design_system/englishhelper/project/EnglishHelper Design System.html`.
Extract every design token defined in it — colors (light + dark), typography scale,
spacing, radii, motion/springs — into a single Swift file: `DesignSystem/Tokens.swift`,
as semantic named constants.

Rules:
- This is a ONE-TIME extraction. The HTML is the design artifact; `Tokens.swift` becomes
  the single source of truth from now on. After this, the HTML is archived, not referenced.
- Map raw values to SEMANTIC names (`surface`, `surface.glass`, `content.primary/secondary`,
  `accent`, `success/warning/error`, `scrim.solid`, `scrim.blur`, register tags
  formal/neutral/casual/slang, etc.) — not raw hex.
- Tie color tokens to system materials where the design implies Liquid Glass
  (`.regularMaterial` / `.thickMaterial` / `.ultraThinMaterial`).
- Output a verification table: token name → light value → dark value → source line in the HTML,
  so the values can be checked against the canvas. Do not invent or drop anything.
- If a token is referenced visually but has no explicit value, FLAG it — do not guess.

After extraction: verify the table by eye (especially `scrim.*` and register tags), then commit
`Tokens.swift`. The HTML is no longer the source of truth.
