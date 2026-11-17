# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). V0 stays in `0.x`
until the public contract stabilizes.

> Append-only: add entries under `[Unreleased]`; released sections are
> immutable. `.gitattributes` uses git's union merge driver for this file
> (ADR 0009).

## [Unreleased]

## [0.1.0] - 2026-11-17

First functional V0 release: the menu bar companion answers, streams, keeps
history and renders Champ inside the Ask window. Hardening items outside the V0
definition of done (evals, injection fixtures, performance report, release
dry-run) remain a post-release backlog.

### Added

- Menu bar app with Ask, Show/Hide Ask, Settings and Quit; `LSUIElement`, no Dock icon.
- Global hotkey (⌥⌘K by default, customizable) opens Ask and focuses the input.
- OpenAI-compatible streaming provider with provider profiles, SSE parsing, typed errors and retries.
- Keychain-backed API keys; `config.json` stores only `secretRef`.
- Settings/onboarding with base URL, model, headers and “Test connection”.
- Multi-turn chat transcript; history persisted as versioned JSON and reused as
  context (the transcript starts fresh on relaunch); new-chat action (`+`, ⌘N).
- Embedded animated Champ driven by semantic `CompanionState`s, plus local mascot packs.
- Resizable Ask window with its frame persisted across launches.
- XCUITest critical flow: hotkey, Esc, show/hide, embedded mascot layout and new chat.

### Changed

- One window is the product: Champ is embedded in the Ask header; the separate
  mascot panel and its drag/position persistence were removed. The Ask window
  itself stays movable and frame-autosaved (ADR 0012).
- Show/Hide now toggles the Ask window.
- Ask is a chat: transcript above, input pinned at the bottom, cancel button and
  a waiting indicator while a turn streams.

### Fixed

- Bundle SwiftPM resource bundles into the `.app` so the installed app launches;
  `make deploy` fails if the app exits immediately after opening.
- Keep the Ask panel on screen while the app is inactive (`hidesOnDeactivate`),
  so the global hotkey reliably brings it forward.
- Activate and focus Ask on every summon, including the first one after launch.
- Keep the typed API key visible after Test Connection until Save or close; give
  the connection test a 256-token budget so reasoning models can answer.

## [0.0.0-m0] - 2026-11-16

First public milestone (prerelease). Foundation only; the conversation loop
starts in M1.

### Added

- SwiftPM workspace: `YoChampsCore`, `YoChampsMac`, `YoChampsMascotValidator`.
- Menu bar shell (`LSUIElement`, no Dock icon) with Quit.
- Makefile-first DX: bootstrap, doctor, build, run, test, format, lint,
  secrets, mascot-validate, verify, ci, deploy (local), restart, stop, open,
  logs, config, mascots, install-hooks, clean.
- GitHub Actions CI: Linux Core tests, macOS gates.
- Mascot pack contract, validator and placeholder Champ pack.
- Documentation: product V0, milestone contracts, architecture, ADRs, security,
  M0 release notes.
- Project `AGENTS.md`, `opencode.jsonc`, `.gitignore`, `.env.example`,
  `.gitleaks.toml`, LICENSE, ASSETS.md, SECURITY.md.

[Unreleased]: https://github.com/yoAlves/yo-champs/compare/v0.1.0...main
[0.1.0]: https://github.com/yoAlves/yo-champs/releases/tag/v0.1.0
[0.0.0-m0]: https://github.com/yoAlves/yo-champs/releases/tag/v0.0.0-m0
