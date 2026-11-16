# Gates

A gate is evidence, not a feeling. Each milestone closes only when its gate is
green, the evidence is attached to `status.md`, and a review has no open
critical/important finding. The agent does not self-certify.

## Milestone order

`M0 → M1 → M2 → M3 → M4`. Do not start the next milestone while the current
gate is open. If a gate cannot be met, stop and write `BLOCKED.md` with what is
missing; do not guess or weaken the gate.

## `make verify`

The single automated gate. It runs, in order:

1. `make lint` — SwiftFormat check + SwiftLint strict.
2. `make test` — Swift Testing suites.
3. `make build` — debug app bundle.
4. `make mascot-validate` — default and local packs.
5. `make secrets` — gitleaks over the working tree.

Contract tests, integration tests and XCUITest join the gate when their
milestone lands. UI validation never uses MCP.

## CI

`.github/workflows/ci.yml` has two jobs:

- **core (linux):** `swift test` on a Swift 6.2 container. The macOS targets are
  excluded in `Package.swift` on non-Apple platforms.
- **app + gates (macos):** installs SwiftLint/SwiftFormat/gitleaks and runs
  `make ci`. `make ci` is exactly `make verify`.

CI green means the workflow passed on the remote. A local `make ci` run is
evidence of the same commands, but not of the remote result; record which one
was observed.

## Branching and merges (GitFlow)

`main` is production; `develop` is integration. Both are protected: pull request
required (0 approvals for the solo owner), required checks `core (linux)` and
`app + gates (macos)`, admins enforced, no force push or deletion. `main` also
requires branches up to date (`strict`); `develop` does not. Direct pushes are
expected to fail with `GH006`.

- Bootstrap: `develop` was created from `main` when the policy landed (PR #1 is
  the adoption change).
- `feature/*` → PR to `develop`.
- `release/vX.Y.Z` → PR `develop` → `main`; tag on `main`; back-merge `main` into
  `develop` via a PR.
- `hotfix/*` → PR to `main`, tag on `main`, back-merge into `develop` via a PR.
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
on the `release/vX.Y.Z` branch cut from `develop` (rebased on the current `main`
only if that branch already exists), with no open or in-flight changelog
branches. After merging, verify entries are in the right section and the blank
line before the new heading survived (union can glue adjacent bullets into the
released section). Web merges may ignore merge drivers; the discipline is the
guarantee (ADR 0009).

## Review budget

One full review per non-trivial change set; critical/important findings get one
focused fix pass and one focused re-review. Suggestions are reported, not
looped. If the same critical finding survives a fix attempt, stop and escalate.
