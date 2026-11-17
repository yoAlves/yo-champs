# M3 Character — design

**Date:** 2026-11-16.
**Binding contract:** `docs/delivery/milestones/M3.md`.
**Status:** draft for approval.

## Intent

Turn Yo Champs from a menu-bar text panel into a desktop companion. M2 left a
working provider, settings and history, but there is no Champ on screen: the
default pack is a one-frame placeholder and the show/hide, hotkey and drag
deliverables of M3 are still open. The user wants Champ **constantly visible**;
"closing" it **hides/minimizes** it without quitting the process.

## Goals

- Global hotkey with a recorder UI; a safe default is chosen and conflicts are
  detected when the user sets it.
- A floating, borderless, transparent, always-on-top character window.
- `MascotRenderer` maps the six `CompanionState` values to pack animations; the
  LLM never chooses an animation keyword.
- Drag with position persisted across restarts and safe placement across screens.
- Default Champ pack replaced by original art and local packs loadable.
- `make test-ui` becomes a real XCUITest run; `make verify`, `make deploy` and
  `make restart` stay green.

## Non-goals

- No pack marketplace, editor, remote downloads or signed distribution.
- No OCR, transcription, calendar, tools or MCP.
- No CI migration of XCUITest in this milestone — see Deferred.

## Anti-goals

- Enabling a fake `make test-ui` that reports success without running XCUITest.
- Copying any Microsoft asset or using the Clippy name/branding.
- A character that reacts to LLM prose instead of semantic engine events.
- A renderer that animates continuously while idle, burning CPU.

## Constraints

- `main` is protected: work lands via branch → PR → merge commit, checks green.
- Dependency direction `YoChampsMac → YoChampsCore → Foundation`; Core stays
  AppKit-free, vendor-name-free and testable on Linux.
- Secrets stay in the Keychain; no new credential is needed for M3.
- Local toolchain: macOS 26.7.3, Xcode 27.2 / Swift 6.4.2. CI macOS uses
  `macos-15-intel` (Xcode 26.x, Swift 6.2–6.3). Toolchain drift must be watched.
- M3 exit criteria require `make test-ui` green; without it the gate stays open.

## Approaches considered

### Hotkey/panel stack

1. **`KeyboardShortcuts` package + `NSPanel` (chosen).** The library already
   provides recording, conflict detection and persistence for global hotkeys;
   the app already uses an `NSPanel` for Ask. Cost: a new SwiftPM dependency.
2. Carbon event hotkey registration by hand — no dependency, but reimplements
   recording, conflict checking and persistence badly. Rejected.
3. Launcher-only invocation (as in M1) — no in-app hotkey, contradicts M3.
   Rejected.

### XCUITest project

1. **XcodeGen-generated `.xcodeproj` with app + UI test target (chosen).**
   `project.yml` stays reviewable; `xcodegen` is a small Homebrew tool. The
   existing SwiftPM package is referenced as a local package, so source files
   are not duplicated. Cost: one more tool and a generated project file.
2. Hand-written `project.pbxproj` — no tool, but unmaintainable and easy to
   break. Rejected.
3. Run XCUITest only in CI — possible (the macOS runner already has Xcode),
   but local `make test-ui` would remain unusable; deferred, not rejected.

### Champ art

1. **Programmatic original art (chosen).** `scripts/gen-champ-pack.py` draws a
   silver paperclip with an expressive face at 4x and downsamples into 64px
   frames. Reproducible, no external assets, already validates.
2. AI image generation — attempted, failed with `Invalid credential` in this
   session. Not available; no asset was produced.
3. Keep the M0 placeholder — contradicts the M3 deliverable.

## Decisions

### Made by the user

- Champ stays visible constantly; "close" hides/minimizes it and keeps the
  process running.
- Install Xcode locally so `make test-ui` runs on this machine.
- Moving XCUITest into CI is an open TODO, not part of this milestone.
- Generate art for a cute original placeholder (no Microsoft references).

### My calls (review these)

- **Hotkey default:** `⌥⌘Y`, validated at set time by `KeyboardShortcuts`'s
  recorder; if it conflicts, the recorder surfaces it and the user picks
  another. Rationale: unlikely to collide with Spotlight/Raycast defaults.
- **Close semantics:** hiding the window also stops an in-flight turn, keeping
  the M1 fix (a dismissed turn must not keep streaming and be persisted). The
  app process, engine and history remain alive.
- **Panel geometry:** borderless `NSPanel`, transparent background,
  `.floating` level, `canJoinAllSpaces`, draggable by its body, ignored by
  mouse events only while hidden. Position stored in `UserDefaults` under
  `com.yurioliveira.yochamps`, clamped to the union of visible screen frames on
  launch and after drag.
- **Renderer:** explicit `CompanionState → animation id` table (`streaming →
  talking`). One timer per active state, fired at the manifest's `fps`, using
  the manifest's `frames`/`loop`; no timer for a one-frame resting state;
  suspended while hidden. State changes swap frames without re-creating the
  window.
- **Window layout:** Champ lives in its own panel; the existing Ask bubble
  stays a separate panel and is positioned near Champ when opened, clamped to
  the same screen. Hiding or moving Champ does not destroy the bubble; if Champ
  is hidden, the bubble opens at its last known position. Only Champ's frame is
  persisted.
- **Animation frames:** `idle` stays a single static frame with **no timer**;
  `thinking` gets 2 frames (eye shift), `talking` 3 (mouth movement), `happy`
  2, `confused` 2, `error` 2. This keeps "animate" literal where it matters
  without burning CPU while idle. Manifest stays `schemaVersion 1`; the
  spritesheet becomes a horizontal strip of all frames.
- **Gate boundary:** `make test-ui` is a **standalone local gate**, not a
  dependency of `verify`/`ci` (CI migration is deferred). Evidence goes into
  `docs/delivery/status.md` alongside the green local run.
- **UI test scope:** hotkey/Ask, Esc, show/hide and one drag/persistence check,
  driven through accessibility identifiers on the panel controls. Animations
  themselves are covered by renderer unit tests and manual evidence.
- **Manifest fps:** 6 for idle/thinking, 8 elsewhere; `version` bumped to 0.2.0.

## Decisions from the builder check (user answers)

1. **`confused` is reachable from the engine.** Core is in scope: an
   empty/unparseable assistant answer produces `confused` instead of falling
   back to a resting state. This makes the "six states from real engine events"
   criterion literally true and addresses the known M1 gap where an answer with
   no deltas was persisted as happy. Add a Core test for the trigger.
2. **Local packs are auto-discovered.** At load time, scan
   `~/Library/Application Support/YoChamps/Mascots/<id>/` and use a single
   valid pack; with none, use the default Champ. If several valid packs exist
   or the pack is invalid, surface a clear, user-facing error in Settings and
   keep the default. Reuse `MascotManifest` and the validator's rules so a pack
   that validates cannot fail to decode at runtime. No picker UI in M3.

## Left to the builder

- Task breakdown and TDD order (invoke `writing-plans` after approval).
- Exact `KeyboardShortcuts` version pin compatible with Swift 6.2 CI.
- `project.yml` details and the `make test-ui` command wiring (`xcodegen generate`
  + `xcodebuild test` with a named scheme/destination).
- Whether the Xcode project file is committed or regenerated in CI — decide so
  the gate is reproducible.

## Deferred

- Move XCUITest into the `app + gates (macos)` CI job once the local flow is
  green and the toolchain drift (Swift 6.4 local vs CI 26.x) is understood.
- Pin SwiftFormat / SwiftLint / gitleaks versions in CI.
