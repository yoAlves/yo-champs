# Yo Champs

A native macOS menu bar companion with the nostalgia of a desk assistant and a
real, provider-agnostic LLM underneath. V0 answers short questions in a chat
panel with an original paperclip character named **Champ** embedded in the
header.

**Status:** v0.1.0 (functional V0). M4 hardening is a post-release backlog; see
`docs/delivery/status.md`.

> Fan-spirited project with an original character. Not affiliated with or
> endorsed by Microsoft. No Microsoft assets are included. Code is MIT;
> original assets are CC BY 4.0 (see `ASSETS.md`).

## Requirements

- macOS 14+ on Apple Silicon
- Swift 6 toolchain (Command Line Tools are enough for build, tests and gates)
- Full Xcode only for `make test-ui`
- Homebrew for `swiftlint`, `swiftformat`, `gitleaks`

## Quick start

```sh
git clone https://github.com/yoAlves/yo-champs.git
cd yo-champs
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

- `YoChampsCore`: pure Foundation domain (engine, context, storage, mascot manifests).
- `YoChampsProviders`: OpenAI-compatible streaming client, SSE parser, `MockProvider`.
- `YoChampsNetwork`: `URLSession` transport for the provider.
- `YoChampsMac`: menu bar shell, Ask panel/chat, embedded Champ, Settings, Keychain.
- `YoChampsMascotValidator` / `YoChampsProviderCheck`: local CLIs for packs and the SSE stub.
- No backend, no daemon, no Rust, no Electron.
- `scripts/bundle.sh` assembles the app bundle; the small Xcode project is only
  for `make test-ui`.

Read `docs/architecture/overview.md` and the ADRs in `docs/decisions/`.

## Docs

| Path | Content |
|---|---|
| `docs/product/v0.md` | V0 scope, stories, providers, mascot, definition of done |
| `docs/delivery/milestones/` | Binding contracts M0–M4 |
| `docs/delivery/status.md` | Current milestone, gate, evidence |
| `docs/delivery/releases/` | Release notes (M0, v0.1.0) |
| `docs/architecture/` | Module graph, contracts, data/versioning, pack format |
| `docs/decisions/` | Decision log and ADRs |
| `docs/security/` | Threat model, data and privacy, prompt injection, MCP policy |

No telemetry, no backend, no cloud sync. What stays on the Mac and what leaves
in a provider request: [`docs/security/data-and-privacy.md`](docs/security/data-and-privacy.md).

## License

MIT — see `LICENSE`. Original mascot assets: CC BY 4.0 — see `ASSETS.md`.
