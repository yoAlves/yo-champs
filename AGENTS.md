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

## Milestones and gates

`docs/delivery/milestones/M0.md` … `M4.md` are binding contracts. A milestone
closes only with `make verify` green, evidence attached to
`docs/delivery/status.md`, and review. Do not start the next milestone before
the current gate is green and reviewed.

Completion report: what changed, criteria met, commands + output, evidence,
gaps and risks. The agent does not self-certify; the reviewer checks against
the milestone contract.

## Docs

- `docs/` is public contract: product, delivery, architecture, decisions, security.
- `notes/`, `scratch/`, `.specs/` are local and git-ignored; promote decisions to ADRs.
- Update `docs/delivery/status.md` in the same change that moves a gate.
