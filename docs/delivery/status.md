# Status

**Milestone:** M0 — Foundation.
**State:** local gate green; review passed; remote CI and clean-clone gate pending.
**Date:** 2026-11-15.

## Gate

| Check | Result | Evidence |
|---|---|---|
| `make bootstrap` | pass | tools present/installed, `bootstrap: ok`, packages resolved |
| `make doctor` | pass | `doctor: 0 failure(s), 5 warning(s)` (expected warnings); installed app present |
| `make verify` | pass | SwiftFormat clean; SwiftLint 0 violations; 18 tests pass in 3 suites; app build; default + local packs validated; gitleaks no leaks |
| `make ci` | pass | same as `make verify` (alias), exit 0 |
| `make deploy` opens menu bar app | pass (process/plist) | `installed: ~/Applications/YoChamps.app`; PID running from that bundle; `LSUIElement => true`; ad-hoc signature. Visual menu bar item pending human confirmation |
| Clean clone → bootstrap → verify → deploy | pending | no git repository/remote yet |
| CI on remote | pending | workflow added; no git remote yet |
| Review | pass | full review: 0 critical / 4 important fixed with tests; focused re-review: 0 critical / 0 important, 8 non-blocking suggestions |

## Environment

- macOS 26.5.2 (arm64), Swift 6.3.2, Command Line Tools only (no full Xcode).
- SwiftLint 0.65.1, SwiftFormat 0.64.7, gitleaks 8.30.1, Homebrew present.
- `swift-testing` pinned to 6.2.4 (6.3+ links the Xcode-only `_TestingInterop`).

## Evidence

- `make verify`:
  - `swiftformat --lint`: `0/11 files require formatting`.
  - `swiftlint lint --strict` (with `--disable-sourcekit`, no Xcode):
    `Found 0 violations, 0 serious`.
  - `swift test`: `Test run with 18 tests in 3 suites passed`.
  - `bundle.sh`: `Build of product 'YoChampsMac' complete!`.
  - `mascot-validate`: `ok Resources/Mascots/Default`, `validated 1 pack(s)`
    (also walks `~/Library/Application Support/YoChamps/Mascots/*` when present).
  - `gitleaks`: `no leaks found` (~122 KB scanned).
- `make deploy`: `installed: ~/Applications/YoChamps.app`; process
  `.../YoChamps.app/Contents/MacOS/YoChamps` running; Info.plist
  `CFBundleIdentifier=com.yurioliveira.yochamps`, `LSUIElement=true`;
  `Signature=adhoc`, `TeamIdentifier=not set`.
- The app was left running.

## Gaps and risks

- **No full Xcode:** `xcodebuild`/XCUITest unavailable. M0 uses SwiftPM +
  `scripts/bundle.sh` (ADR 0002); `make test-ui` is blocked until Xcode is
  installed (M1+ dependency to resolve).
- **No git remote:** the CI workflow exists but its remote result cannot be
  observed until the repo is initialized, pushed and Actions runs. Local
  `make ci` (= `make verify`) is the evidence until then. The clean-clone gate
  is blocked for the same reason.
- **Unsigned local builds:** expected for V0; distribution is post-V0.
- **Menu bar visual check:** process and `LSUIElement` are verified; a human
  still needs to confirm the item is visible and Quit works.

## Deferred review suggestions (non-blocking)

1. Local-pack discovery uses `try?`; an unreadable `Mascots` directory would be
   skipped silently instead of failing the gate.
2. `unreadableImage` test throws for every URL, so a missing preview decode
   check would not fail any test.
3. No test for the 512-frame upper bound (only the lower bound is covered).
4. Validator rasterizes the full PNG to read its dimensions; read image
   properties instead for large packs.
5. `make mascot-validate` relies on the Makefile CWD; an explicit
   `cd "$(ROOT)"` would document it.
6. Manifest decode failures collapse to `invalidJSON`; a missing
   `schemaVersion` reports the generic message.
7. File size uses the symlink size, so a symlinked spritesheet can bypass the
   5 MB cap.
8. `docs/product/v0.md` field list omits `schemaVersion` and says the validator
   checks "license" (it enforces non-empty only).

## Rulings

- **M0 app packaging:** SwiftPM executable + `scripts/bundle.sh` instead of an
  XcodeGen project, because the machine has no Xcode. Cost if wrong: M1/M3 must
  add an Xcode project for XCUITest; the bundle script remains useful.
- **Module set at M0:** only `YoChampsCore`, `YoChampsMac` and
  `YoChampsMascotValidator`. `YoChampsProviders` and `YoChampsEvals` arrive with
  M1/M4 to avoid empty targets.
- **Swift Testing source:** use the official `swift-testing` package pinned to
  **6.2.4**; 6.3+ links `_TestingInterop`, which Command Line Tools do not ship.
  `scripts/test.sh` adds the SDK libc++ headers that CLT's stub lacks. Cost if
  wrong: a version pin to revisit and an environment-specific include path.
- **Local SwiftLint:** `scripts/lint.sh` adds `--disable-sourcekit` when
  `xcodebuild` is unavailable, because SwiftLint cannot load sourcekitd from
  CLT. CI (with Xcode) runs the full rule set. Cost if wrong: a
  SourceKit-dependent rule (e.g. `statement_position`) is only enforced in CI.
- **Review fixes:** mascot packs carry `schemaVersion` (rejected when missing),
  file/geometry validation moved into `YoChampsCore` with Swift Testing coverage,
  `make mascot-validate` now includes local packs, and the fetch of local packs
  is part of the same gate. Cost if wrong: packs without `schemaVersion` must be
  regenerated, which is intended from day zero.
