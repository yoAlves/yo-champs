# Decisions

The decision log records every architectural choice for V0. ADR files expand
the load-bearing ones; the log stays as the index of record.

| ID | Decision | Why | Discarded alternatives | ADR |
|---|---|---|---|---|
| D01 | Swift 6 + SwiftUI/AppKit | native APIs, small footprint, V0 speed | Electron, Tauri, Rust UI | 0001 |
| D02 | Pure Core + macOS shell, in-process | testability and portability without a daemon | HTTP backend, daemon in V0 | 0001 |
| D03 | API-first OpenAI-compatible; OpenRouter as docs example | simple, agnostic, covers OpenAI/Ollama/LM Studio | proprietary SDK, agent framework | 0003 |
| D04 | No Rust in V0 | the bottleneck is macOS/UX, not CPU/memory | Rust core + FFI, Tauri | 0001 |
| D05 | Asset packs; original default mascot | solves licensing, becomes a community feature | hardcoding Clippy, committing Microsoft assets | 0004 |
| D06 | Semantic animation states | avoids LLM-chosen animation keywords and injection | asking the model for animations | 0004 |
| D07 | Multi-turn with budget; JSON in V0 | simple and testable; RAG later | SQLite/RAG in V0 | 0005 |
| D08 | One generalist agent + registry | no premature agent hierarchy | multi-agent in V0 | 0003 |
| D09 | No MCP in V0 | MCP is tools, not UI validation; attack surface | MCP client/server in V0 | 0008 |
| D10 | Slash commands in V0.1 | they do not block the main loop | commands in V0 | 0007 |
| D11 | Security from day zero | Keychain, gitleaks, redacted logs, prompt hierarchy | “we’ll see later” | 0006 |
| D12 | Code MIT; assets CC BY 4.0; disclaimer | separates code from IP; unambiguous public repo | MIT covering Microsoft assets | 0004 |
| D13 | Lightweight SDD + executable contracts | verifiable gates for agents | prose spec without gates | 0007 |
| D14 | macOS 14+ / Apple Silicon first | modern APIs; universal later | Intel/old macOS in V0 | 0001 |
| D15 | No telemetry/cloud in V0 | privacy and simplicity | analytics/crash reporting | 0006 |
| D16 | Makefile is the single DX and gate interface | humans and agents run the same command | ad-hoc commands | 0007 |
| D17 | Provider profiles are data; no provider/model names in Core | swap providers without recompiling; Go Plus is a personal profile | constants/hardcode | 0003 |
| D18 | Versioned schemas + migrations from day zero | evolve without breaking data | “we’ll migrate later” | 0005 |
| D19 | Specs/ADRs are committed; notes/scratch are not | public contract vs personal memory | commit everything | 0007 |
| D20 | Local `make deploy` in V0; signed `make release` later | speed now, safe distribution later | signing/notarizing in V0 | 0007 |
| D21 | Go Plus carries an intended-use notice (coding agent) | avoids relying on out-of-contract use | public Go Plus default | 0003 |
| D22 | Versions/editions via capabilities/config, never forks | sustainable evolution | fork per version | 0005 |
| D23 | Project skills, AGENTS.md and opencode.jsonc are committed; personal/global config is not | reproducible, safe DX | committing personal config | 0007 |
| D24 | MCP is an executable dependency: pin, review, least privilege, opt-in | supply-chain security | auto-starting arbitrary MCP | 0008 |
| D25 | `.gitignore` covers scratch/notes/.specs/auth/.env; `.env.example` is the only example | prevents leaks and noise | “just don’t commit it” | 0006 |

## ADRs

- [0001 — Swift 6, pure Core, macOS shell](0001-swift6-core-shell.md)
- [0002 — M0 app packaging with SwiftPM and scripts/bundle.sh](0002-app-packaging-swiftpm.md)
- [0003 — Provider-agnostic OpenAI-compatible contract](0003-provider-agnostic.md)
- [0004 — Mascot packs, semantic states and licensing](0004-mascot-and-assets.md)
- [0005 — JSON storage, schema versions and migrations](0005-storage-and-versioning.md)
- [0006 — Security from day zero](0006-security-day-zero.md)
- [0007 — Makefile-first DX and docs policy](0007-dx-and-docs.md)
- [0008 — No MCP in V0](0008-no-mcp-v0.md)
