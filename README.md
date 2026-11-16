# Yo Champs

A native macOS menu bar companion with the nostalgia of a desk assistant and a
real, provider-agnostic LLM underneath. V0 answers short questions in a bubble
near an original paperclip character named **Champ**.

**Status:** M0 (foundation). No LLM loop yet; see `docs/delivery/status.md`.

> Fan-spirited project with an original character. Not affiliated with or
> endorsed by Microsoft. No Microsoft assets are included. Code is MIT;
> original assets are CC BY 4.0 (see `ASSETS.md`).

## Requirements

- macOS 14+ on Apple Silicon
- Swift 6 toolchain (Command Line Tools are enough for M0)
- Homebrew for `swiftlint`, `swiftformat`, `gitleaks`

## Quick start

```sh
make bootstrap   # tools + package resolve
make doctor      # environment report
make verify      # lint, test, build, mascot pack, secrets
make deploy      # local release install + open YoChamps.app
```

The app lives in the menu bar (no Dock icon). Quit from the menu.

## Commands

`make help` is the index. The Makefile is the single interface for humans and
agents: build, run, test, gates, deploy and logs all go through it.

## Architecture

- `YoChampsCore`: pure Foundation domain (engine, contracts, mascot manifests).
- `YoChampsMac`: thin SwiftUI/AppKit menu bar shell.
- `YoChampsMascotValidator`: CLI that validates asset packs.
- No backend, no daemon, no Rust, no Electron.

Read `docs/architecture/overview.md` and the ADRs in `docs/decisions/`.

## Docs

| Path | Content |
|---|---|
| `docs/product/v0.md` | V0 scope, stories, providers, mascot, definition of done |
| `docs/delivery/milestones/` | Binding contracts M0–M4 |
| `docs/delivery/status.md` | Current milestone, gate, evidence |
| `docs/architecture/` | Module graph, contracts, data/versioning, pack format |
| `docs/decisions/` | Decision log and ADRs |
| `docs/security/` | Threat model, prompt injection, MCP policy |

## License

MIT — see `LICENSE`. Original mascot assets: CC BY 4.0 — see `ASSETS.md`.
