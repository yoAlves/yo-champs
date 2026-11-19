# Gates

A gate is evidence, not a feeling. Each milestone closes only when its gate is
green, the evidence is attached to `status.md`, and a review has no open
critical/important finding. The agent does not self-certify.

## Milestone order

`M0 → M1 → M2 → M3 → M4`. Do not start the next milestone while the current
gate is open. If a gate cannot be met, stop and write `BLOCKED.md` with what is
missing; do not guess or weaken the gate.

**Release ruling (2026-11-17):** `v0.1.0` was cut from the functional V0
definition of done with M4 hardening still open, by explicit owner decision.
M0–M3 gates were green and merged; M4 (evals, injection fixtures, performance,
release dry-run, recorded demo) remains an open post-release backlog. This is a
scoped exception for the functional V0 release, not a new rule for future
milestones.

## `make verify`

The single automated gate. It runs, in order:

1. `make lint` — SwiftFormat check + SwiftLint strict.
2. `make test` — Swift Testing suites.
3. `make build` — debug app bundle.
4. `make mascot-validate` — default and local packs.
5. `make secrets` — gitleaks over the working tree.

`make provider-check` is the M2 integration check: it runs the real streaming
client against a local SSE stub. `make ci` (macOS) runs `verify` followed by
`provider-check`; `make verify` alone does not start the stub. XCUITest still
waits for full Xcode. UI validation never uses MCP.

## CI

`.github/workflows/ci.yml` has two jobs:

- **core (linux):** `swift test` on a Swift 6.2 container. The macOS targets are
  excluded in `Package.swift` on non-Apple platforms.
- **app + gates (macos):** installs SwiftLint/SwiftFormat/gitleaks and runs
  `make ci`, i.e. `make verify` + `make provider-check`.

CI green means the workflow passed on the remote. A local `make ci` run is
evidence of the same commands, but not of the remote result; record which one
was observed.

`.github/workflows/ui.yml` is a separate, **non-required** workflow: it runs
`make test-ui` on `macos-15-intel` on `workflow_dispatch` and on a nightly
schedule. The required `app + gates (macos)` job already has full Xcode; it does
not run the XCUITest suite because that suite needs a foreground GUI session
(the app is an accessory app, and cases click the status item and switch to
Finder) and is slower and flakier than the gate set. So the UI suite runs on
demand and nightly as a signal. A red `ui` run is not a merge blocker: required
PR checks remain `core (linux)` and `app + gates (macos)`. If the hosted runner
cannot run the suite headlessly, keep the workflow manual-only and record the
limitation in `status.md`; never weaken the local `make test-ui` gate to make it
pass.

## Branching and merges (PR to main)

`main` is the only long-lived branch, protected: pull request required (0
approvals for the solo owner), required checks `core (linux)` and
`app + gates (macos)`, branches up to date (`strict`), admins enforced, no force
push or deletion, conversation resolution. Direct pushes are expected to fail
with `GH006`. The short-lived `develop` experiment was removed; the flow is
PR → `main` (ADR 0011).

- Branch from `main` (`feature/*`, `fix/*`, `docs/*`, `chore/*`, `ci/*`), open a
  PR to `main`, wait for both checks, merge with a merge commit.
- Releases are `vX.Y.Z` tags on `main`; a one-off `release/vX.Y.Z` branch may
  carry the changelog cut through a PR.
- Work only on branches; never use an admin bypass or disable protection to land
  a change. M0 history is the pre-policy baseline and is not rewritten.

## Evidence

Append to `docs/delivery/status.md`:

- milestone and state;
- date;
- each command run with its result (counts, pass/fail);
- manual evidence (what you saw: menu bar item, no Dock icon, Quit works);
- gaps and risks.

Keep raw logs out of the repo if they contain user data; summarize counts.

## Completion report

Every milestone ends with a report containing:

1. What changed (files/areas).
2. Criteria met, mapped to the milestone contract.
3. Commands + output (trimmed to the meaningful lines).
4. Evidence (manual checks, screenshots without personal data).
5. Gaps and risks.
6. Rulings made where the plan was silent or wrong.

## Local deploy

`make deploy` builds Release, ad-hoc signs, copies to
`~/Applications/YoChamps.app` and opens it. It is not a release: no Developer
ID, no notarization, no publish, and it prints that notice. It never deletes
user data; destructive resets are a separate, confirmed target (post-V0).

## Changelog

`CHANGELOG.md` is append-only: new bullets go under `## [Unreleased]`, released
sections are immutable. `.gitattributes` sets `/CHANGELOG.md merge=union` so two
branches adding entries merge without a conflict (both sides kept). After
**every** union merge, check ordering/duplicates, that no bullet was glued into
a released section, and that no entry was dropped.

Cutting a release is the only rewrite: move entries into a new
`## [x.y.z] - YYYY-MM-DD` section, add its link reference, update the
`[Unreleased]` compare link to the new tag, leave `[Unreleased]` empty, and do it
on a `release/vX.Y.Z` branch cut from `main` (or the PR branch doing the cut),
with no open or in-flight changelog branches. After merging, verify entries are
in the right section and the blank line before the new heading survived (union
can glue adjacent bullets into the released section). Web merges may ignore merge
drivers; the discipline is the guarantee (ADR 0009).

## Review budget

One full review per non-trivial change set; critical/important findings get one
focused fix pass and one focused re-review. Suggestions are reported, not
looped. If the same critical finding survives a fix attempt, stop and escalate.
