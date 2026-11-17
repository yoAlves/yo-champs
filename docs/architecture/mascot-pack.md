# Mascot pack format

A pack is a directory with three files:

```
<id>/
  manifest.json
  spritesheet.png
  preview.png
```

Packs live in:

- default: `Resources/Mascots/Default/` (committed, original art);
- local: `~/Library/Application Support/YoChamps/Mascots/<id>/` (never committed).

## manifest.json

```json
{
  "schemaVersion": 1,
  "id": "champ",
  "name": "Champ",
  "version": "0.2.0",
  "author": "Yo Champs",
  "license": "CC-BY-4.0",
  "frameSize": { "width": 64, "height": 64 },
  "scale": 2.0,
  "anchor": { "x": 0.5, "y": 1.0 },
  "animations": {
    "idle":     { "frames": 1, "fps": 6, "loop": true },
    "thinking": { "frames": 2, "fps": 6, "loop": true },
    "talking":  { "frames": 3, "fps": 8, "loop": true },
    "happy":    { "frames": 2, "fps": 8, "loop": false },
    "confused": { "frames": 2, "fps": 8, "loop": false },
    "error":    { "frames": 2, "fps": 8, "loop": false }
  }
}
```

| Field | Rule |
|---|---|
| `schemaVersion` | integer ≥ 1; missing or older values are rejected, not guessed |
| `id`, `name`, `version`, `author`, `license` | non-empty strings (`license` is recorded, not validated against a list) |
| `frameSize.width/height` | integers 1…4096 (pixels) |
| `scale` | positive finite number (display multiplier) |
| `anchor.x/y` | normalized 0…1; `(0.5, 1.0)` = bottom-centre |
| `animations.<id>.frames` | integer 1…512 |
| `animations.<id>.fps` | positive finite number |
| `animations.<id>.loop` | boolean |

Required animation ids: `idle`, `thinking`, `talking`, `happy`, `confused`,
`error`. Extra animations are allowed and rendered after the required ones,
sorted by id.

`CompanionState` maps to animation ids explicitly:

| State | Animation |
|---|---|
| `idle` | `idle` |
| `thinking` | `thinking` |
| `streaming` | `talking` |
| `happy` | `happy` |
| `confused` | `confused` |
| `error` | `error` |

## spritesheet.png

- A **horizontal strip** of frames, transparent background.
- Every frame is exactly `frameSize.width × frameSize.height`.
- Frame order: required animations in the order above, then extras sorted by id;
  each animation contributes `frames` consecutive frames.
- `spritesheet.png` width must equal `totalFrames × frameSize.width`; height
  must equal `frameSize.height`. No padding, no gaps.

## preview.png

- A still preview for pack pickers and docs.
- Any size; must be a readable PNG.

## Limits

| File | Limit |
|---|---|
| `manifest.json` | 64 KB |
| `spritesheet.png` | 5 MB |
| `preview.png` | 2 MB |

## Validation

`make mascot-validate` runs `YoChampsMascotValidator`, which checks the
manifest schema, required animations, sprite geometry, preview readability and
size limits for the default pack and every local pack. Failures print the pack
path and a user-facing reason and exit non-zero.

The validator is the gate for US7. Runtime loading reuses the same
`MascotManifest` types, so a pack that validates cannot fail decoding later.

## Generating the placeholder

The default M0 art is generated from code and committed as a placeholder:

```sh
swift scripts/gen-placeholder-pack.swift Resources/Mascots/Default
```

The M3 character pack replaces it. Provenance and license are in `ASSETS.md`.
