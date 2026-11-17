# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). V0 stays in `0.x`
until the public contract stabilizes.

> Append-only: add entries under `[Unreleased]`; released sections are
> immutable. `.gitattributes` uses git's union merge driver for this file
> (ADR 0009).

## [Unreleased]

### Added

- M2: versioned provider profiles and config with Keychain-backed secrets.
- M2: OpenAI-compatible streaming client, SSE parser, typed errors and retries.
- M2: Settings/onboarding, JSON conversation history and a local provider check.
- M3: animated Champ mascot panel with drag/persistence, global hotkey, menu show/hide and XCUITest.
- Embed Champ in the Ask window; remove the floating panel, drag and position persistence; Show/Hide now toggles Ask.
- Resizable Ask panel: the window frame (size and position) persists across launches via `frameAutosaveName`.
- Ask panel restyled as a chat: multi-turn transcript, CHAMP badge + mascot avatar header, input pinned at the bottom.

### Changed

- Default Ask hotkey is now ⌥⌘K; it stays customizable in Settings.

### Fixed

- Keep the Ask panel on screen while the app is inactive (`NSPanel.hidesOnDeactivate` defaults to `true`), so the global hotkey reliably brings it to the front.
- Bundle SwiftPM resource bundles into the `.app` so the installed app launches; `make deploy` now fails if the app exits immediately after opening.
- Keep the typed API key visible after Test Connection until Save or close, and give the connection test a 256-token budget so reasoning models can answer.
- Close the Settings window on Save and reset the API key only when the panel closes.

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

[Unreleased]: https://github.com/yoAlves/yo-champs/compare/v0.0.0-m0...main
[0.0.0-m0]: https://github.com/yoAlves/yo-champs/releases/tag/v0.0.0-m0
