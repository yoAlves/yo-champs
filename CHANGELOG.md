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
