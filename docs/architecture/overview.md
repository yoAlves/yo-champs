# Architecture overview

## Shape

```
YoChampsMac (menu bar, hotkey, panels, bubble, settings, mascot renderer)
    │ async/await, in-process
YoChampsCore (engine, context, provider contract, storage, commands)
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
evidence in `docs/delivery/status.md`; no dedicated CI step in V0)
(lands with M2). Today the Core contains only `CompanionState` and the mascot
manifest contract.

## Modules

| Module | Responsibility | Status |
|---|---|---|
| `YoChampsCore` | engine, context, contracts, storage protocols, mascot manifest | M0 (subset) |
| `YoChampsProviders` | `OpenAICompatibleProvider`, SSE, registry, `MockProvider` | M1–M2 |
| `YoChampsMac` | menu bar, hotkey, panels, bubble, settings, Keychain, JSON store, renderer | M0 (shell) |
| `YoChampsEvals` | eval runner and fixtures | M4 |
| `YoChampsMascotValidator` | CLI pack validator | M0 |

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

No `.xcodeproj` in M0: only Command Line Tools are required. XCUITest requires
full Xcode and will add an Xcode/XcodeGen project when `make test-ui` lands
(ADR 0002).

## Runtime data

| Path | Contents |
|---|---|
| `~/Library/Application Support/YoChamps/config.json` | non-secret config, profiles, `secretRef` |
| `~/Library/Application Support/YoChamps/history.json` | conversations (JSON in V0) |
| `~/Library/Application Support/YoChamps/Mascots/<id>/` | local packs |
| Keychain (service `com.yurioliveira.yochamps`) | API keys |

## Flow (target V0)

1. Hotkey/menu opens the prompt.
2. `CompanionEngine` builds context from the conversation and agent definition.
3. The provider streams `LLMEvent`s; the engine maps them to
   `CompanionState` and text deltas.
4. The shell renders the bubble and the mascot animation.
5. The store persists the turn; cancellation tears down the stream.

## UI validation

XCUITest, snapshots, `YoChampsMascotValidator` and evals. MCP is never used to
validate UI.
