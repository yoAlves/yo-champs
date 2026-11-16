# ADR 0004 — Mascot packs, semantic states and licensing

**Status:** accepted (2026-11-15).
**Covers:** D05, D06, D12.

## Context

The nostalgia is the hook, but Microsoft assets cannot be committed and the LLM
must not control animation or expression directly.

## Decision

- Mascot is an original paperclip character, **Champ**, inspired by the Office
  assistant but with its own silhouette, eyes, colours, lines and animations.
- Packs are data: `manifest.json` + `spritesheet.png` + `preview.png`, with
  required animation ids `idle`, `thinking`, `talking`, `happy`, `confused`,
  `error`.
- `CompanionState` drives animation; the model produces text only.
- Local packs live in `~/Library/Application Support/YoChamps/Mascots/<id>/` and
  are never committed. A real Clippy pack is personal use only.
- Code is MIT; original assets are CC BY 4.0; `ASSETS.md` records provenance;
  README carries the non-affiliation disclaimer.

## Consequences

- Validator + runtime share `MascotManifest`, so validation and loading agree.
- Community packs are possible without shipping Microsoft IP.
- Trademark/App Store questions remain legal, not technical, decisions.
