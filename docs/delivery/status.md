# Status

## M1 — Conversation loop

**State:** implementation complete; local gate green; awaiting review and PR.
**Date:** 2026-11-16.
**Branch:** `feature/m1-loop` (local, 6 commits ahead of `main`; not pushed yet).

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make test` | pass | 45 tests / 9 suites, 0 failures (3 consecutive runs for MockProvider; twice at final gate) |
| `make lint` | pass | SwiftFormat 0/30 need formatting; SwiftLint 0 violations in 28 files |
| `make verify` | pass | exit 0: lint + 45 tests + app build + 1 pack + gitleaks no leaks |
| `make demo` | pass | exit 0; debug bundle launched with `--demo`; PID observed; fixture question auto-asked |
| URL scheme + lifecycle | pass | `yochamps://open` registered in Info.plist; log `url open schemes=yochamps`; log `launch demo=true` |
| Core vendor-free | pass | case-insensitive grep for mock/vendor names in `Sources/YoChampsCore`: no matches |
| PR + CI + review | pending | push/PR require owner approval; never push to main |

### Evidence

- `make verify` (exit 0, run twice):
  - `0/30 files require formatting, 34 files skipped.`
  - `Done linting! Found 0 violations, 0 serious in 28 files.`
  - `✔ Test run with 45 tests in 9 suites passed after 0.006 seconds.`
  - `Build of product 'YoChampsMac' complete! (0.42s)`
  - `ok .../Resources/Mascots/Default`, `validated 1 pack(s)`
  - `no leaks found` (~193 KB scanned)
- Cancellation is tested end to end: engine turns are dropped on cancel, and a
  consumer abandoning the stream cancels the provider (two tests verified by
  mutation — removing the guards made exactly those two fail).
- Lifecycle log via `/usr/bin/log show --info --predicate ...`:
  `launch demo=true`, `url open schemes=yochamps`.
- Full milestone contract: `milestones/M1.md`.

### Gaps and risks

- No full Xcode → no `test-ui`, no automated screenshot of panel streaming.
  Manual visual confirmation of bubble streaming and Esc is still owed; engine
  behaviour is covered by tests.
- `main` is protected; push/PR/merge require owner approval.

## M0 — Foundation (baseline)

**Milestone:** M0 — Foundation.
**State:** complete — local gate, review, clean clone, CI and deploy green.
**Date:** 2026-11-16.

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make bootstrap` | pass | tools present/installed, `bootstrap: ok`, packages resolved |
| `make doctor` | pass | `doctor: 0 failure(s), 5 warning(s)` (expected warnings); installed app present |
| `make verify` | pass | SwiftFormat clean; SwiftLint 0 violations; 18 tests pass in 3 suites; app build; default + local packs validated; gitleaks no leaks |
| `make ci` | pass | same as `make verify` (alias), exit 0 |
| `make deploy` opens menu bar app | pass | `installed: ~/Applications/YoChamps.app`; PID running; `LSUIElement => true`; ad-hoc signature; menu bar item visibly confirmed by the owner |
| Git baseline + pre-commit hook | pass | commits `e121360`/`946c42b` on `main`; hook ran gitleaks + lint; `.build/` and `.specs/` ignored |
| Clean clone → bootstrap → verify | pass | local clone 764 KB (no `.build`/`.specs`); `make verify` green; clean tree |
| CI on remote | pass | [run 43857030588](https://github.com/yoAlves/yo-champs/actions/runs/43857030588): `core (linux)` and `app + gates (macos)` green |
| Public release | pass | prerelease `v0.0.0-m0` with notes in `docs/delivery/releases/M0.md` |
| Review | pass | full review: 0 critical / 4 important fixed with tests; focused re-review: 0 critical / 0 important, 8 non-blocking suggestions |

### Environment

- macOS 26.5.2 (arm64), Swift 6.3.2, Command Line Tools only (no full Xcode).
- SwiftLint 0.65.1, SwiftFormat 0.64.7, gitleaks 8.30.1, Homebrew present.
- `swift-testing` pinned to 6.2.4 (6.3+ links the Xcode-only `_TestingInterop`).
- Git repo with `main` only, public remote
  `https://github.com/yoAlves/yo-champs`; baseline `e121360`; pre-commit hook
  installed.
- `main` is protected (PR required, 0 approvals, strict up-to-date, checks
  `core (linux)`/`app + gates (macos)`, admins enforced, no force push/deletion,
  conversation resolution). Short-lived `develop` was removed; flow is PR → main
  (ADR 0011).

### Evidence (M0)

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
  `Signature=adhoc`, `TeamIdentifier=not set`; menu bar item confirmed by the
  owner in a screenshot.
- Clean clone: `git clone` of `e121360` (764 KB, no `.build`/`.specs`);
  `make bootstrap` resolved from `Package.resolved`; `make verify` green with
  18 tests, 1 pack, no leaks; clone working tree clean.
- Pre-commit hook: gitleaks `no leaks found` + SwiftFormat/SwiftLint clean on the
  `e121360` commit.
- The app was left running.

### Gaps and risks (M0)

- **No full Xcode:** `xcodebuild`/XCUITest unavailable. M0 uses SwiftPM +
  `scripts/bundle.sh` (ADR 0002); `make test-ui` is blocked until Xcode is
  installed (M1+ dependency to resolve).
- **CI runner capacity:** one macOS job was cancelled while queued (no steps
  ever started) for commit `8e2cbcd`; linux passed. This is runner capacity, not
  a code failure — rerun the job (`gh run rerun <id> --failed`) when it happens.
  The green run cited above (`43857030588`) had both jobs complete.
- **Pre-policy history:** M0 commits predate branch protection and are kept as
  the baseline (ADR 0010 → superseded by 0011); this is not a precedent for
  direct pushes.
- **Unsigned local builds:** expected for V0; distribution is post-V0.

### Deferred review suggestions (non-blocking)

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

### Rulings (M0)

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
