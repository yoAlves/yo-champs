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

## Review budget

One full review per non-trivial change set; critical/important findings get one
focused fix pass and one focused re-review. Suggestions are reported, not
looped. If the same critical finding survives a fix attempt, stop and escalate.
