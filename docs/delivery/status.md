# Status

## Current state (2026-11-19)

**Version:** 0.1.2 — release cut on `feature/provider-reasoning-effort`; tag
`v0.1.2` follows the merge. The previous release is `v0.1.1` on `fdbda00`.
**Milestones:** M0–M3 complete and merged. M4 hardening is an open
post-release backlog (release ruling in `milestones/M4.md`).
**App:** functional V0 loop — menu bar, ⌥⌘K, streaming Markdown answers with
copy on select, multi-turn persisted context (the visible transcript starts
fresh), embedded Champ with the avatar in the header, Settings/Keychain,
resizable Ask window.
**Gate:** `make verify` and `make test-ui` green on `main` (evidence below).
**Open points:** tracked with severity and size in
[`open-points.md`](open-points.md); no `Critical` points remain — the cross-host
redirect guard landed in PR [#28](https://github.com/yoAlves/yo-champs/pull/28)
(`71442d7`), covered by `RedirectPolicyTests` and `make provider-check`; O2–O8
plus O16/O17 are the next refinement round.
**Open:** evals, injection fixtures, performance report, `make release-dry-run`,
recorded demo, public checklist. V0.1 features stay out of this release.

## v0.1.2 — provider reasoning effort (2026-11-19)

**State:** release cut on `feature/provider-reasoning-effort`; merge and tag pending.
**Release notes:** `releases/v0.1.2.md`.
**Gate:** `make verify` and `make provider-check` green on the branch.

## v0.1.1 — post-v0.1.0 hardening (2026-11-19)

**State:** merged on `main`; tag `v0.1.1` on the merge commit.
**Release notes:** `releases/v0.1.1.md`.
**Plan:** Ask UI, local data & CI hardening (2026-11-19).

| PR | Scope | Merge commit |
|---|---|---|
| [#17](https://github.com/yoAlves/yo-champs/pull/17) | 2 MB history cap; `0700`/`0600` modes | `92fa1a5` |
| [#18](https://github.com/yoAlves/yo-champs/pull/18) | HTTPS outside loopback; Settings "Test connection" key guard; payload boundary test; ADR 0013 + privacy docs | `4671e14` |
| [#19](https://github.com/yoAlves/yo-champs/pull/19) | Markdown parser, selectable text with copy on select, new Ask header, demo answer, 4 new XCUITest cases | `9b58bba` |
| [#20](https://github.com/yoAlves/yo-champs/pull/20) | Non-blocking `ui` workflow and the gate docs that govern it | `b1b87d7` |
| [#21](https://github.com/yoAlves/yo-champs/pull/21) | Bounded `pr-checks` watcher and its deterministic suite in `make ci` | `e931955` |
| [#22](https://github.com/yoAlves/yo-champs/pull/22) | Closeout docs: evidence, changelog, roadmap, zero drift | `d9bba73` |
| [#25](https://github.com/yoAlves/yo-champs/pull/25) | Disclaimer footer removed; input row and Ask button 3 px lower | `8d38de8` |
| [#26](https://github.com/yoAlves/yo-champs/pull/26) | Doc cleanup for the removed footer | `a8e511b` |

PRs [#23](https://github.com/yoAlves/yo-champs/pull/23) and
[#24](https://github.com/yoAlves/yo-champs/pull/24) tuned the footer spacing and
are superseded by #25.

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make verify` | pass | exit 0; SwiftFormat 0/71 need formatting; SwiftLint 0 violations in 69 files; 171 tests / 25 suites (91 core + 62 providers + 18 Mac); app build; 1 pack; gitleaks `no leaks found` |
| `make test-ui` | pass | 10 cases, 0 failures, `** TEST SUCCEEDED **` (~75 s) |
| CI (PRs #17–#26) | pass | `core (linux)` and `app + gates (macos)` green on every merge |
| `ui` workflow (run [44534215571](https://github.com/yoAlves/yo-champs/actions/runs/44534215571)) | pass | `workflow_dispatch` on `main`: `make test-ui` on `macos-15-intel`, 5m18s |
| Review | pass | per-PR `@reviewer`; focused re-reviews on #19, #20 and #21; 0 critical/important open |

### Rulings and deviations

- Transcript text stays at 12 pt (macOS `.callout`) instead of the component default 13 pt, per the owner's "same size as before" request.
- Copy on select runs after `super.mouseDown` returns: `NSTextView` consumes the mouse-up inside its own tracking loop.
- The Settings "Test connection" cleartext-key hole was fixed inside PR #18 as an added task (3b) rather than deferred.
- Changelog entries are written once here (PR5) instead of per PR, to keep the append-only union-merge file single-writer.
- The PR lanes ran sequentially instead of in parallel worktrees; `test-ui`/`run` serialize on one app instance anyway.
- The disclaimer footer was removed (owner decision for a personal project) and the input row sits 3 px lower; #23/#24 tuned spacings that #25 superseded.

### Gaps and risks

Tracked with severity, size and evidence in [`open-points.md`](open-points.md).
Release-specific:

- **O1 — closed in PR [#28](https://github.com/yoAlves/yo-champs/pull/28)** (`71442d7`): redirects are limited to the configured origin (scheme, host, port), covered by `RedirectPolicyTests` and `make provider-check`.
- History is plaintext for same-user processes (O14); FileVault is the at-rest dependency.
- The `ui` workflow is a signal; XCUITest needs full Xcode and `make stop` first.

## v0.1.0 — functional V0 (2026-11-17)

**Branch:** `release/v0.1.0` → PR #15 → `main`. **Tag:** `v0.1.0` (pushed
2026-11-17, on merge commit `aec7452`).
**Release notes:** `releases/v0.1.0.md`.

### What changed

- Documentation reconciliation with the shipped product: ADR 0012 (Champ
  embedded in Ask), product v1.4, milestone statuses, architecture, security
  and README.
- Version `0.1.0` in `App/Info.plist`; the menu reads the bundle version.
- Removed dead code: the unused `MascotImageView` and the retired
  `gen-placeholder-pack.swift`; the menu item is now “Show/Hide Ask”.
- Changelog cut for `0.1.0`; release notes added.

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make verify` | pass | exit 0: SwiftFormat 0/62 need formatting (44 skipped); SwiftLint 0 violations in 60 files; 50 provider + 5 Mac + 69 core = **124 tests / 19 suites**; app + validator builds; 1 pack; gitleaks ~805 KB, `no leaks found` |
| `make test-ui` | pass | exit 0; 7 XCUITest cases, 0 failures in 51.592 s; `** TEST SUCCEEDED **` |
| `make mascot-validate` | pass | `ok .../Resources/Mascots/Default`, `validated 1 pack(s)` (inside `make verify`) |
| CI (PR #15) | pass | `core (linux)` 1m12s; `app + gates (macos)` 6m48s; run 44170891785 |
| Review | pass | `@reviewer`: 0 critical / 2 important (fixed) / 6 suggestions; focused re-review `APPROVE_WITH_NOTES`, no critical/important remaining |

### Ruling

`v0.1.0` was cut on the V0 definition of done instead of waiting for M4
hardening. M0–M3 gates were green and merged; M4 remains an open backlog. The
scoped exception is recorded in `docs/delivery/gates.md` and `milestones/M4.md`.

### Gaps and risks

- `make test-ui` is order-sensitive; stop an installed instance (`make stop`)
  before running it.
- UI tests launch with `--demo` (MockProvider); the real Keychain/provider path
  is manual.
- The visible transcript is not repopulated on relaunch; `history.json` is
  loaded as model context only.
- M4 hardening (evals, injection, performance, release dry-run, demo) is open.
- The tag is unsigned/local-only; distribution is post-V0.

## History

The sections below are dated gate records. They are kept as evidence of the
state at the time; where a decision was later superseded, the ADR is referenced.

## Embedded mascot (post-M3) — `feature/embedded-mascot` (PR #9)

**State:** merged 2026-11-17 (PR #9); the final product shape is the chat panel
from PR #13 (ADR 0012). The paragraphs below are the historical gate record.
**Date:** 2026-11-17.
**Branch:** `feature/embedded-mascot`, rebased onto the PR #8 merge `ca05b28`
(which carries the SwiftPM resource-bundle fix), +6 commits vs `origin/main`.

### Product decision

Champ is now embedded in the Ask window. The floating mascot panel, its drag and
position persistence were removed. The original "Show/Hide Champ" item (now
"Show/Hide Ask") toggles the Ask window. The global hotkey default is ⌘⌥K (the `KeyboardShortcuts` default),
customizable in Settings, and reopens Ask.

### Gate (evidence run 2026-11-17, 10:13–10:17 -03)

The chain `make verify && make mascot-validate && make test-ui && make deploy &&
make restart` was run with per-command exit codes captured and short-circuit
`&&` semantics. `test-ui` was retried 3 times after its first failure (4 attempts
total). No test or gate was weakened and no pass was faked.

| Check | Exit | Result | Evidence |
|---|---|---|---|
| `make verify` | 0 | pass | SwiftFormat 0/62 need formatting (38 skipped); SwiftLint 0 violations in 59 files; 50 provider + 69 core = **119 tests / 18 suites**; app + validator builds; 1 pack; gitleaks ~587 KB, `no leaks found` |
| `make mascot-validate` | 0 | pass | `ok .../Resources/Mascots/Default`, `validated 1 pack(s)` |
| `make test-ui` | 2 (`make`) / 65 (`xcodebuild`) | **FAIL — 0/4 attempts green** | see breakdown below; hotkey, Esc and the new embedded-mascot case passed every attempt; only `testShowHideKeepsProcessAlive` failed |
| `make deploy` | 0 | pass | `installed: ~/Applications/YoChamps.app` (unsigned local build); app launches with the resource bundle present |
| `make restart` | 0 | pass | `stop` + `open`; installed app reopened |

### `make test-ui` breakdown (all four attempts)

Each attempt ran four XCUITest cases. `testEmbeddedMascotDoesNotOverlapLongAnswer`,
`testEscapeClosesAsk` and `testHotkeyOpensAsk` passed in **all 4/4** attempts.
`testShowHideKeepsProcessAlive` failed in **4/4** attempts with the same error:

```
UITests/YoChampsUITests.swift:188: error:
-[YoChampsUITests.YoChampsUITests testShowHideKeepsProcessAlive] :
Element StatusItem, {{906.0, -27.0}, {33.5, 24.0}}, title: 'Attachements' is not hittable
```

The status item sits at y = -27 (off-screen in the test runner's display), so
XCUITest cannot synthesize a click on it. `Executed 4 tests, with 1 failure`,
`** TEST FAILED **`, xcresult e.g.
`Test-YoChampsUITests-2026.11.17_10-16-32--0300.xcresult`. This is the known
intermittent XCUITest hotkey/status-item event-synthesis flake recorded for this
branch (an earlier, separate run was a clean 4/4 green; in earlier repeats the
hotkey case failed 3/4 full and 1/3 isolated runs while the status item was
intermittently off-screen). The new embedded-mascot case and Esc have passed every
run. The hotkey was verified working in the real deployed app; see "Hotkey
visibility fix and default ⌥⌘K" below for the later root cause and evidence.

### Root cause of the reported "hotkey does nothing"

The feature branch predated PR #8 (`ca05b28`), so its local bundle lacked the
`KeyboardShortcuts_KeyboardShortcuts` resource — the installed app aborted at
launch. Rebasing `feature/embedded-mascot` onto `ca05b28` fixed it; a fresh
`make deploy` succeeds and the app launches with `launch demo=false`.

### Hotkey visibility fix and default ⌥⌘K (2026-11-17, same PR)

The bundle fix above was necessary but not sufficient: the hotkey fired while the
Ask panel stayed invisible. Root cause: `AskPanel` is an `NSPanel`, whose
`hidesOnDeactivate` defaults to `true`, so the window was removed from the screen
whenever the app was inactive. `NSApp.activate()` is a cooperative request on
macOS 14+ and lands about 0.5 s after the hotkey, so the panel stayed invisible
until activation. The panel now sets `hidesOnDeactivate = false`: the floating
window is ordered on screen immediately, and activation only makes it key. This
also keeps the panel visible when the user switches apps while it is open.

⌥⌘Y was retested with the fixed bundle and fires; the original report did not
reproduce as a key conflict. The product default is now **⌥⌘K** (requested by the
owner) and remains customizable in Settings; a machine-local `defaults` override
used during debugging was removed so the new default applies. ⌥⌘K was checked
with a Carbon registration probe (`RegisterEventHotKey` returned 0) and no
enabled system symbolic hotkey uses it; `testHotkeyOpensAsk` exercises it too.

End-to-end evidence on the installed release build (automation: System Events key
events + `CGWindowListCopyWindowInfo`, app inactive unless noted):

| Check | Result |
|---|---|
| Launch with another app frontmost | Ask window `onscreen=true`, app inactive |
| Switch to another app | Ask window stays `onscreen=true` |
| ⌥⌘K from another app | app active, Ask `onscreen=true` |
| Esc | Ask hidden, process alive |
| ⌥⌘K again | Ask `onscreen=true` |
| Terminal in fullscreen, ⌥⌘K | Ask appears above the fullscreen app, app active |
| Manual ask with a personal key | HTTP 200 reply; the Keychain prompt is local ad-hoc-build behavior, not an app bug |
| Typing after ⌥⌘K, no click | text landed in the Ask field (AX value of the SwiftUI text field) |

### Gate after the hotkey fix (2026-11-17, later run)

`make verify` exit 0: SwiftFormat 0/62 files need formatting; SwiftLint 0
violations in 59 files; 50 provider + 69 core = 119 tests / 18 suites; app +
validator builds; 1 pack; gitleaks `no leaks found` (~776 KB).

`make test-ui` exit 0: `Executed 5 tests, with 0 failures (0 unexpected) in
37.943 seconds`, `** TEST SUCCEEDED **`:
`testAskStaysOnScreenWhenAnotherAppIsActive` 5.9 s (new regression guard for
`hidesOnDeactivate`), `testEmbeddedMascotDoesNotOverlapLongAnswer` 8.1 s,
`testEscapeClosesAsk` 4.3 s, `testHotkeyOpensAsk` 6.7 s (now ⌥⌘K),
`testShowHideKeepsProcessAlive` 13.0 s.

Mutation check: setting `hidesOnDeactivate` back to `true` makes the new test
fail with `Ask left the screen when another app became active`; with the fix
restored it passes. The test is not vacuous.

`make deploy` exit 0: `installed: ~/Applications/YoChamps.app` (release, ad-hoc
signature); the deploy check confirmed the process stayed alive, and `make open`
relaunched the same installed build after the UI gate.

Attempts in this session surfaced three different suite flakes: the documented
status-item click, one `testEmbeddedMascot…` snapshot error, and a menu-open
timeout in `testShowHideKeepsProcessAlive`. One `testEmbeddedMascot…` failure
("element disabled") was a real ordering issue: a case now leaves Finder active,
so `launchApp()` had to wait for the app to become frontmost before querying AX.
After that fix the suite passed 5/5 in two consecutive runs. The clean run also
requires no installed instance with the same bundle id (`make stop` first).

### Gaps and risks

- `make test-ui` is order-sensitive: an earlier run flaked (status item at
  y = -27 not hittable, plus one AX snapshot error) while the installed app was
  running with the same bundle id. The clean rerun after `make stop` passed 5/5.
- UI tests use `--demo` (MockProvider). The manual end-to-end check used the
  owner's own provider and key (HTTP 200); no key material appears in docs, logs
  or fixtures.
- The status-item-click and hotkey-event paths still rely on XCUITest event
  synthesis; there is no non-XCUITest automated coverage for them.

## M3 — Character

**State:** complete — merged via PR [#7](https://github.com/yoAlves/yo-champs/pull/7); the separate floating panel and drag were superseded by ADR 0012.
**Date:** 2026-11-17.
**Branch:** `feature/m3-character` (PR #7, merged 2026-11-17).

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make verify` | pass | exit 0: SwiftFormat 0/62 files need formatting, SwiftLint 0 violations in 59 files, 119 tests / 18 suites (50 provider + 69 core), app + validator builds, 1 pack, gitleaks no leaks (~726 KB) |
| `make mascot-validate` | pass | exit 0; `ok .../Resources/Mascots/Default`, `validated 1 pack(s)` |
| `make test-ui` | pass | exit 0; `** TEST SUCCEEDED **` — 4 XCUITest cases, 0 failures (hotkey → Ask, Esc, show/hide, drag + relaunch) |
| `make deploy` | pass (see correction) | exit 0; installed `~/Applications/YoChamps.app` (unsigned local build). **Correction:** at the M3 gate this check was green even though the app aborted at launch — the bundled `KeyboardShortcuts` resource was missing. Fixed in PR #8. |
| `make restart` | pass | exit 0; `stop` + `open`, installed app reopened |
| `core (linux)` (CI) | pass | PR #7 required check green, ~1m on `macos-15-intel` runner set |
| `app + gates (macos)` (CI) | pass | PR #7 required check green, ~4–5m |
| Whole-branch review | pass | 0 critical / 1 important (fixed); scoped re-review clean, no new breakage |

### Evidence

- Full chain `make verify && make mascot-validate && make test-ui && make deploy && make restart` run on 2026-11-17: all five commands exit 0 (`CHAIN_EXIT=0`), each with short-circuit `&&` semantics and per-command exit codes captured.
- `make verify` (exit 0):
  - `0/62 files require formatting, 36 files skipped.`
  - `Done linting! Found 0 violations, 0 serious in 59 files.`
  - `✔ Test run with 50 tests in 5 suites passed after 0.110 seconds.` (provider)
  - `✔ Test run with 69 tests in 13 suites passed after 0.010 seconds.` (core) — 119 Swift Testing tests total.
  - `Build complete!` for the app bundle and the mascot validator.
  - `ok .../Resources/Mascots/Default`, `validated 1 pack(s)`
  - `no leaks found` (~726324 bytes / 726.32 KB scanned).
- `make mascot-validate` (exit 0): `ok .../Resources/Mascots/Default`, `validated 1 pack(s)`.
- `make test-ui` (exit 0): xcodebuild `test -project YoChamps.xcodeproj -scheme YoChampsUITests -destination platform=macOS`; four cases, all passed:
  - `testHotkeyOpensAsk` passed (6.300 s) — ⌘⌥Y reopens Ask after Esc (default at the time).
  - `testEscapeClosesAsk` passed (3.949 s).
  - `testShowHideKeepsProcessAlive` passed (13.774 s).
  - `testDragThenRelaunchRestoresPosition` passed (8.624 s).
  - `Executed 4 tests, with 0 failures (0 unexpected) in 32.647 (32.652) seconds`; `** TEST SUCCEEDED **`; xcresult `Test-YoChampsUITests-2026.11.17_00-02-35--0300.xcresult`.
- `make deploy` (exit 0): `stopped YoChamps (if it was running)`, `installed: /Users/yurioliveiraalves/Applications/YoChamps.app`, `note: local build only — unsigned, not notarized, not published`.
- `make restart` (exit 0): `stopped YoChamps (if it was running)`; the `open` prerequisite relaunches the installed app.

- **M3 deploy evidence correction (PR #8):** `make deploy` exited 0 during the M3 gate, but the installed app aborted immediately at launch with `Fatal error: unable to find bundle named KeyboardShortcuts_KeyboardShortcuts`. The minimal `.app` built by `scripts/bundle.sh` copied the binary, plist and mascot pack but not the SwiftPM resource bundles. The gate missed it because `open` returns 0 even when the app dies. PR #8 makes `bundle.sh` copy `*.bundle` into `Contents/Resources` (failing clearly if the required one is absent) and makes `deploy.sh` verify the process is alive after launch. Verified locally: `make verify` exit 0 (119 tests), `make deploy` exit 0 with the app process alive.
- PR CI: `core (linux)` and `app + gates (macos)` both green on the PR head. No run id or head hash is pinned here — the branch head moves with evidence commits, so pinning would drift (the M2 pattern).
- Whole-branch review over `18ebded..218967e`: 0 critical, 1 important — an unreadable local-pack directory could drop Champ and misreport the cause. Fixed in `11fd196`; scoped re-review `218967e..11fd196` verdict: all findings ADDRESSED, no new Critical/Important breakage.
- Post-review CI compatibility commits: `9818165` (`redundantSelf` flag difference between local and CI SwiftFormat) and `ef83da9` (`isolated deinit` unsupported by CI's Swift 6.2–6.3). `make verify` remained exit 0 (119 tests) after both; CI went green on `ef83da9`.

### Gaps and risks

- No hash is pinned in the gate rows above: pinning the evidence commit would drift as the branch head moves (the M2 pattern).
- No real-endpoint Q&A in this gate: UI tests launch with `--demo` (MockProvider), so no personal Keychain key is used.
- The `.unreadable` local-pack fallback path has no automated Mac-side unit test (no Mac unit-test target); covered by the scoped review, not by a test.
- Deferred non-blocking review minors: PIF warning noise; whitespace-only `confused` test; `max(0,…)` clamp inconsistency; selector dead fallback; two Task 5 message/styling details; same-state frame replay and origin-persist-on-show; duplicate `mascotPanel` identifier; two status wording nits.

## M2 — Real providers

**State:** complete — merged to `main` via PR [#5](https://github.com/yoAlves/yo-champs/pull/5) (merge commit `1dc305c`).
**Date:** 2026-11-16.
**Gate evidence:** final green CI run 43947073489 on the merged branch head.

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make verify` | pass | exit 0: format 0/54, SwiftLint 0 violations in 52 files, 105 tests / 16 suites, app + validator builds, 1 pack, gitleaks no leaks |
| `make provider-check` | pass | exit 0; real `OpenAICompatibleProvider` against local Python SSE stub → `provider-check: OK` |
| Core vendor-free | pass | case-insensitive grep for vendor names over `Sources/YoChampsCore`: zero matches |
| Typed errors | pass | `LLMError` cases for key/model/timeout/rate/server + Settings display + cancellation |
| Persistence | pass | `FileConversationStore` restart/clear/schema tests (JSON `history.json`, schemaVersion 1) |
| `core (linux)` (CI) | pass | [run 43947073489](https://github.com/yoAlves/yo-champs/actions/runs/43947073489), 1m5s |
| `app + gates (macos)` (CI) | pass | same run, 8m29s on `macos-15-intel` |

### Evidence

- `make verify` (exit 0):
  - `0/54 files require formatting, 34 files skipped.`
  - `Done linting! Found 0 violations, 0 serious in 52 files.`
  - `✔ Test run with 105 tests in 16 suites passed after 0.111 seconds.`
  - `Build of product 'YoChampsMac' complete!`, `Build of product 'YoChampsMascotValidator' complete!`
  - `ok  .../Resources/Mascots/Default`, `validated 1 pack(s)`
  - `no leaks found` (~311 KB scanned)
- `make provider-check` (exit 0): stub on 127.0.0.1, ephemeral `URLSession` transport,
  real SSE parse → `provider-check: OK`.
- PR CI final green run 43947073489 on merged branch head `aad9d07`:
  `core (linux)` pass 1m5s, `app + gates (macos)` pass 8m29s. Earlier attempts exposed arm64 runner labels
  (`macos-15` never acquired, `macos-14-arm64` unsupported) and a 5s stub-start
  timeout; fixed by `macos-15-intel` and a 30s readiness check in
  `scripts/provider-check.sh`. No gate or rule was weakened.
- Commits on the branch: `e84c13f` (Core contracts), `7dc17fa` (SSE client),
  `7c283c9` (config + Keychain), `5ce4680` (JSON persistence), `7ce0eb1` (Settings),
  `7ae3497` (app wiring + provider-check), `1605e4b` (integration fixes),
  `86a1cbb`/`9187bb0` (runner), `64ac372` (stub readiness),
  `df98e29`/`a6907cd`/`aad9d07` (CI evidence).

### Gaps and risks

- No full Xcode → Settings UI and streaming visuals have no automated UI test;
  engine/contract tests and `make demo` cover behavior.
- ADR 0003 wording and cross-host redirect blocking remain deferred; header
  placeholders are expanded at request time (no literal `{{…}}` is sent).
- Real endpoint Q&A still requires a personal Keychain key; the gate uses a stub.

## M1 — Conversation loop

**State:** complete — merged via PR [#4](https://github.com/yoAlves/yo-champs/pull/4).
**Date:** 2026-11-16.
**Branch:** `feature/m1-loop` (PR #4, merged 2026-11-16).

### Gate

| Check | Result | Evidence |
|---|---|---|
| `make test` | pass | 45 tests / 9 suites, 0 failures (3 consecutive runs for MockProvider; twice at final gate) |
| `make lint` | pass | SwiftFormat 0/30 need formatting; SwiftLint 0 violations in 28 files |
| `make verify` | pass | exit 0: lint + 45 tests + app build + 1 pack + gitleaks no leaks |
| `make demo` | pass | exit 0; debug bundle launched with `--demo`; PID observed; fixture question auto-asked |
| URL scheme + lifecycle | pass | `yochamps://open` registered in Info.plist; log `url open schemes=yochamps`; log `launch demo=true` |
| Core vendor-free | pass | case-insensitive grep for mock/vendor names in `Sources/YoChampsCore`: no matches |
| PR + CI + review | pass | [PR #4](https://github.com/yoAlves/yo-champs/pull/4) with `--assignee @me`; `core (linux)` and `app + gates (macos)` green ([run 43884012520](https://github.com/yoAlves/yo-champs/actions/runs/43884012520)); review 0 critical / 0 important after fix; merge commit via PR |

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

- No full Xcode at M1 → no `test-ui` and no automated screenshot of streaming.
  Manual visual confirmation was still owed then; M3 XCUITest and the M3 gate
  later covered the panel flow.
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
