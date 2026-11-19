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
| `make demo` | debug bundle with `MockProvider` and a fixture question |
| `make test` | Swift Testing suites |
| `make test-ui` | XCUITest critical flow (needs full Xcode) |
| `make format` / `make lint` | SwiftFormat / SwiftLint strict |
| `make secrets` | gitleaks over the working tree |
| `make mascot-validate` | validate default + local mascot packs |
| `make verify` | gate: lint, test, build, pack, secrets |
| `make provider-check` | real SSE client against a local stub |
| `make ci` | exactly what GitHub Actions runs (`verify` + `provider-check`) |
| `make pr-checks PR=<number> [TIMEOUT=<seconds>]` | wait for a PR's checks (bounded watch, no polling; 120s registration budget + TIMEOUT) |
| `make pr-checks-test` | deterministic suite for the watcher (fake `gh`, no network) |
| `make deploy` | local release install to `~/Applications` and open |
| `make restart` / `make stop` / `make open` / `make logs` | app lifecycle |

Never claim a gate passed without pasting the command and its output.

## Layout

```
Package.swift              SwiftPM: Core, providers, network, Mac app, CLIs
Sources/YoChampsCore/      pure Foundation domain (no AppKit/SwiftUI)
Sources/YoChampsProviders/ OpenAI-compatible client, SSE, MockProvider
Sources/YoChampsNetwork/   URLSession transport
Sources/YoChampsMac/       menu bar shell, Ask panel/chat, embedded Champ
Sources/YoChampsMascotValidator/  Sources/YoChampsProviderCheck/
App/Info.plist             bundle manifest (LSUIElement)
Resources/Mascots/Default/ Champ asset pack
UITests/                   XCUITest critical flow
project.yml                XcodeGen project for the UI tests only
docs/                      product, delivery, architecture, decisions, security
scripts/                   bundle, deploy, bootstrap, doctor, secrets, hooks
```

The app bundle is assembled by `scripts/bundle.sh`; SwiftPM and Command Line
Tools build the product. The small `.xcodeproj` (from `project.yml`) exists only
so `make test-ui` can run XCUITest (ADR 0002).

## Architecture rules

- Dependency direction: `YoChampsMac` → `YoChampsCore` → Foundation. Never the reverse.
- Core imports no AppKit/SwiftUI and knows no provider, model or vendor name.
- Providers, agents, tools and mascot packs are data (`ProviderProfile`,
  `AgentDefinition`, `MascotManifest`), not code.
- Functional core, imperative shell. Async boundaries use `Sendable` DTOs.
- Semantic states (`CompanionState`) drive animation; the LLM never picks a
  sprite or animation keyword.
- Champ is embedded in the Ask window; there is no separate mascot window or
  mascot drag/persisted position. The Ask window itself is movable and its
  frame is autosaved (ADR 0012).
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
- Unit tests live in `Tests/YoChampsCoreTests`, `Tests/YoChampsProvidersTests`
  and `Tests/YoChampsMacTests`; UI checks run through `make test-ui`.
- Provider contract tests live in `Tests/YoChampsProvidersTests`.
- Do not weaken tests or gates to make a milestone look green.

## Branching and releases (PR to main)

`main` is the only long-lived branch and is protected on GitHub: **no direct
pushes**, pull request required (0 approvals, solo owner), required checks
`core (linux)` and `app + gates (macos)`, branches must be up to date (`strict`),
admins enforced, no force push or deletion, conversation resolution required.

- Branch from `main` with a typed prefix: `feature/<slug>`, `fix/<slug>`,
  `docs/<slug>`, `chore/<slug>` or `ci/<slug>`.
- Open a PR into `main`, wait for both checks, then merge with a merge commit.
- No `develop` or long-lived release branches in V0: a release is a `vX.Y.Z` tag
  on `main` after the PR merges. A one-off `release/vX.Y.Z` branch is allowed for
  the changelog cut and is PR'd into `main`.
- Never commit, push, merge or rebase directly on `main`. A blocked push
  (`GH006`) is the protection working: move the work to a branch and open a PR.
- Conventional Commits; keep the PR branch up to date with `main`.
- M0 history predates this policy; it is kept as the baseline, not a precedent.

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
  Do it on a `release/vX.Y.Z` branch cut from `main` (or the PR branch doing the
  cut), with no open or in-flight changelog branches; after merging, verify
  entries are in the right section (union can glue adjacent bullets into the
  released section and drop blank lines).
- GitHub/GitLab web merges may ignore merge drivers; the append-only discipline
  is the real guarantee.

## Docs

- `docs/` is public contract: product, delivery, architecture, decisions, security.
- `notes/`, `scratch/`, `.specs/` are local and git-ignored; promote decisions to ADRs.
- Update `docs/delivery/status.md` in the same change that moves a gate.
