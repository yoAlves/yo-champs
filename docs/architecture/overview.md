# Architecture overview

## Shape

```
YoChampsMac (menu bar, hotkey, Ask panel + chat, embedded Champ, settings)
    │ async/await, in-process
YoChampsCore (engine, context, provider contract, storage)
    │
OpenAI-compatible HTTP API (OpenRouter / OpenCode Go / Ollama / LM Studio)
```

Functional core, imperative shell. The Core is pure Foundation and portable;
the macOS shell owns AppKit/SwiftUI, Keychain, JSON files on disk, logging and
rendering.

## Dependency rule

- `YoChampsMac` → `YoChampsCore` → Foundation.
- `YoChampsProviders` → `YoChampsCore` → Foundation (from M2).
- `YoChampsCore` must not import AppKit/SwiftUI and must not contain provider,
  model, vendor or endpoint names.
- Test targets may import any module.

Enforcement: review + case-insensitive grep over `Sources/YoChampsCore` (manual
evidence in `docs/delivery/status.md`; no dedicated CI step in V0). M2 added the
provider profile and config contracts without bringing vendor names into Core.

## Modules

| Module | Responsibility | Status |
|---|---|---|
| `YoChampsCore` | engine, context, contracts, storage protocols, mascot manifest | M0–M3 |
| `YoChampsProviders` | `OpenAICompatibleProvider`, SSE, registry, `MockProvider` | M2 |
| `YoChampsNetwork` | `URLSession` transport, Keychain auth wrapper | M2 |
| `YoChampsMac` | menu bar, hotkey, Ask panel/chat, embedded Champ, settings, Keychain, JSON store | M0–M3 |
| `YoChampsEvals` | eval runner and fixtures | M4 (open backlog) |
| `YoChampsMascotValidator` | CLI pack validator | M0 |
| `YoChampsProviderCheck` | real client against a local SSE stub | M2 |

## Process model

One process, no daemon, no local HTTP server, no backend. Async work uses
`async/await` and `AsyncStream`; DTOs crossing actors are `Sendable`.

## App bundle

`scripts/bundle.sh` builds the `YoChampsMac` executable with SwiftPM and
assembles `YoChamps.app`:

- `App/Info.plist` → `Contents/Info.plist` (bundle id, display name,
  `LSUIElement`, minimum macOS 14).
- executable → `Contents/MacOS/YoChamps`.
- ad-hoc signature for local launch.

The product build needs only SwiftPM and Command Line Tools. `project.yml`
generates `YoChamps.xcodeproj`, which exists only so `make test-ui` can run
XCUITest with full Xcode (ADR 0002).

## Window model

One floating-level `NSPanel` hosts Ask: header with controls and the embedded
Champ avatar, scrollable transcript, input row at the bottom. Show/Hide toggles
that window, Esc hides it, and the process keeps running. The window is
resizable and its frame is persisted by `frameAutosaveName`. There is no
separate mascot window, mascot drag or restored mascot position; the Ask window
itself is movable and frame-autosaved (ADR 0012).

## Runtime data

| Path | Contents |
|---|---|
| `~/Library/Application Support/YoChamps/config.json` | non-secret config, profiles, `secretRef` |
| `~/Library/Application Support/YoChamps/history.json` | conversations (JSON in V0) |
| `~/Library/Application Support/YoChamps/Mascots/<id>/` | local packs |
| Keychain (service `com.yurioliveira.yochamps`) | API keys |

When a turn starts, the engine loads `history.json` as model context; the Ask
transcript itself starts fresh in V0.

## Flow (V0)

1. Hotkey/menu opens the Ask window and focuses the input.
2. `CompanionEngine` builds context from the conversation and agent definition.
3. The provider streams `LLMEvent`s; the engine maps them to
   `CompanionState` and text deltas.
4. The shell renders the chat transcript and the embedded mascot animation.
5. The store persists the turn; cancellation tears down the stream.

## UI validation

XCUITest, snapshots and `YoChampsMascotValidator`; evals are an open M4 backlog
item. MCP is never used to validate UI.
