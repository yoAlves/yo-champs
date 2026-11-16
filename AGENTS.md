# Yo Champs — project agent guide

Native macOS menu bar companion. Swift 6, SwiftUI/AppKit shell over a pure Core.
Read `docs/product/v0.md` before changing behavior and `AGENTS.md` at the repo
root of every session.

## Commands (the Makefile is the only interface)

| Command | Purpose |
|---|---|
| `make bootstrap` | install/verify tools, resolve packages |
| `make doctor` | versions, paths, config, Keychain, app state |
| `make build` / `make run` | debug bundle / open it |
| `make test` | Swift Testing suites |
| `make format` / `make lint` | SwiftFormat / SwiftLint strict |
| `make secrets` | gitleaks over the working tree |
| `make mascot-validate` | validate default + local mascot packs |
| `make verify` | gate: lint, test, build, pack, secrets |
| `make ci` | exactly what GitHub Actions runs (`verify`) |
| `make deploy` | local release install to `~/Applications` and open |
| `make restart` / `make stop` / `make open` / `make logs` | app lifecycle |

Never claim a gate passed without pasting the command and its output.

## Layout

```
Package.swift              SwiftPM: Core, Mac app, mascot validator
Sources/YoChampsCore/      pure Foundation domain (no AppKit/SwiftUI)
Sources/YoChampsMac/       menu bar shell
Sources/YoChampsMascotValidator/
App/Info.plist             bundle manifest (LSUIElement)
Resources/Mascots/Default/ Champ asset pack
docs/                      product, delivery, architecture, decisions, security
scripts/                   bundle, deploy, bootstrap, doctor, secrets, hooks
```

The app bundle is assembled by `scripts/bundle.sh`; there is no `.xcodeproj` in
M0 because only Command Line Tools are required. Xcode/XCUITest arrive with
`make test-ui` in M1+ (see ADR 0002).

## Architecture rules

- Dependency direction: `YoChampsMac` → `YoChampsCore` → Foundation. Never the reverse.
- Core imports no AppKit/SwiftUI and knows no provider, model or vendor name.
- Providers, agents, tools and mascot packs are data (`ProviderProfile`,
  `AgentDefinition`, `MascotManifest`), not code.
- Functional core, imperative shell. Async boundaries use `Sendable` DTOs.
- Semantic states (`CompanionState`) drive animation; the LLM never picks a
  sprite or animation keyword.
- Keep V0 scope: no OCR, transcription, calendar, web search, MCP, RAG, local
  models, telemetry or auto-update. Scope creep is a defect.

## Security rules

- Secrets only in the macOS Keychain (service `com.yurioliveira.yochamps`);
  never in code, config, fixtures, logs or screenshots.
- Logs use `os.Logger` with `privacy: .private` for anything user-derived.
- No Microsoft assets, no Clippy name/branding in the repo. Champ is original.
- `gitleaks` runs in `make verify`, the pre-commit hook and CI.
- Prompt hierarchy: system/developer/user; attachments and web content are data.

## Testing

- TDD: failing test first, then implementation. Swift Testing (`@Test`,
  `#expect`) via the `swift-testing` package; `scripts/test.sh` adds the SDK
  libc++ headers that Command Line Tools' stub is missing.
- Unit tests live in `Tests/YoChampsCoreTests`; executable UI/CLI checks run
  through `make` targets.
- Contract tests for the provider live in `YoChampsProviders` from M2.
- Do not weaken tests or gates to make a milestone look green.

## Branching and releases (GitFlow)

`main` is production/release-only; `develop` is the integration branch. Both are
protected on GitHub: **no direct pushes**, pull request required (0 approvals,
solo owner), required checks `core (linux)` and `app + gates (macos)`; admins
are enforced, force pushes and deletions are blocked. `main` additionally
requires the branch to be up to date (`strict`); `develop` does not.

- Bootstrap: `develop` was created from `main` when this policy landed; the
  adoption change is PR #1.
- `feature/<slug>` branches from `develop` and merges back via PR into `develop`.
- `release/vX.Y.Z` branches from `develop` and merges via PR into `main`; tag
  `vX.Y.Z` on `main`; then back-merge `main` into `develop` via a PR.
- `hotfix/<slug>` branches from `main`, merges via PR into `main`, is tagged
  `vX.Y.Z` on `main`, and is back-merged into `develop` via a PR.
- Never commit, push, merge or rebase directly on `main`/`develop`. A blocked
  push is the protection working: move the work to a branch and open a PR.
- Conventional Commits; merge commits preserve history; keep the PR branch up
  to date with its base before merging.
- M0 history predates this policy; it is kept as the baseline and is not
  rewritten.

## Milestones and gates

`docs/delivery/milestones/M0.md` … `M4.md` are binding contracts. A milestone
closes only with `make verify` green, evidence attached to
`docs/delivery/status.md`, and review. Do not start the next milestone before
the current gate is green and reviewed.

Completion report: what changed, criteria met, commands + output, evidence,
gaps and risks. The agent does not self-certify; the reviewer checks against
the milestone contract.

## Changelog

`CHANGELOG.md` is append-only and uses git's built-in **union merge driver**
(`.gitattributes`: `/CHANGELOG.md merge=union`). Two branches adding entries
under `## [Unreleased]` merge without a conflict: both sides' added lines are
kept.

- Add new entries under `## [Unreleased]`; never rewrite released sections.
- Keep entries as one bullet/line; do not edit or reorder existing lines.
- After **every** union merge, check ordering/duplicates, that no bullet was
  glued into a released section, and that no entry was dropped.
- Cutting a release is the only rewrite: move entries to a new
  `## [x.y.z] - YYYY-MM-DD` section, add its link reference, update the
  `[Unreleased]` compare link to the new tag, and leave `## [Unreleased]` empty.
  Do it on the `release/vX.Y.Z` branch cut from `develop` (rebased on the current
  `main` only if that branch already exists), with no open or in-flight
  changelog branches; after merging, verify entries are in the right section
  (union can glue adjacent bullets into the released section and drop blank
  lines).
- GitHub/GitLab web merges may ignore merge drivers; the append-only discipline
  is the real guarantee.

## Docs

- `docs/` is public contract: product, delivery, architecture, decisions, security.
- `notes/`, `scratch/`, `.specs/` are local and git-ignored; promote decisions to ADRs.
- Update `docs/delivery/status.md` in the same change that moves a gate.
