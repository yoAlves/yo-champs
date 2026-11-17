# Champ Panel Chat Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the floating ask panel into a chat-style box: CHAMP badge + mascot avatar header, scrollable multi-turn transcript, input pinned at the bottom, following the system appearance.

**Architecture:** `CompanionViewModel` accumulates display-only `ChatTurn` values while `CompanionEngine` keeps owning the conversation context (unchanged). `AskView` is rewritten around a transcript `ScrollView` with the header and input rows fixed, using semantic colors so dark/light comes for free.

**Tech Stack:** Swift 6 (SwiftUI, AppKit, Swift Testing 6.2.4), SwiftPM.

**Spec:** `docs/superpowers/specs/2026-11-17-champ-panel-chat-design.md`.

## Global Constraints

- Dependency direction `YoChampsMac → YoChampsCore → Foundation`; never the reverse. Core is not modified by this plan.
- Semantic colors only in `AskView` (`primary`, `secondary`, `quaternary`, materials); no hard-coded `Color(red:green:blue:)`/`Color.black`/white.
- Window chrome, Esc, ⌘W, hotkey, focus-token and frame-restore behavior in `AskPanel.swift` stay untouched.
- Conventional Commits, subject ≤72 chars, **no AI attribution**.
- Work on a branch from up-to-date `main` (e.g. `feature/champ-panel-chat`); never commit directly to `main`.
- `make verify` is the gate; do not weaken tests or gates.

## Review Focus

1. **Cancel mid-stream, then ask again** — the first turn must keep its partial answer and a second turn must be appended; the transcript must never lose or merge rounds → Task 1 test `cancelMidStreamKeepsPartialAndNextAskAppends`.
2. **Empty answer (confused state)** — a turn with no streamed text renders as `USR: <q>` + `RESPONSE: …` and the next ask still works → Task 1 test `emptyAnswerStillCompletes`.
3. **Rapid consecutive asks** — `ask` cancels an in-flight turn; every completed or cancelled round stays a distinct transcript entry → covered by the same tests as (1) via turn count assertions.
4. **Narrow resize (380×300 min)** — transcript stretches, header and input rows keep their height, nothing overlaps → Task 2 manual check.
5. **Light mode** — with the system in light appearance every new view element stays readable (semantic colors only) → Task 2 review step + manual check.

---

### Task 1: Multi-turn history in CompanionViewModel

**Files:**
- Modify: `Package.swift`
- Create: `Tests/YoChampsMacTests/Support/ScriptedProvider.swift`
- Create: `Tests/YoChampsMacTests/CompanionViewModelTests.swift`
- Modify: `Sources/YoChampsMac/CompanionViewModel.swift`

**Interfaces:**
- Consumes: `CompanionEngine(provider:agent:store:budget:)`, `LLMProvider.stream(_:) -> AsyncThrowingStream<LLMEvent, Error>`, `LLMRequest(model:messages:)`, `LLMEvent` (`.textDelta`, `.done`), `InMemoryConversationStore`, `AgentDefinition(id:name:systemPrompt:model:)` — all public in `YoChampsCore`.
- Produces: `struct ChatTurn: Identifiable, Equatable { let id: UUID; let question: String; var answer: String }` and `@Published private(set) var turns: [ChatTurn]` on `CompanionViewModel`. Existing public surface (`question`, `answer`, `state`, `errorMessage`, `isBusy`, `canAsk`, `statusLabel`, `ask`, `cancel`, `newChat`, `stop`) is unchanged in this task — `answer` stays until Task 2 removes it.

- [ ] **Step 1: Add the YoChampsMacTests target to Package.swift**

Inside the existing `#if os(macOS)` block (after the executable targets, before the closing `#endif`), append to the `targets` array:

```swift
targets.append(
    .testTarget(
        name: "YoChampsMacTests",
        dependencies: [
            "YoChampsMac",
            "YoChampsCore",
            .product(name: "Testing", package: "swift-testing"),
        ]
    )
)
```

- [ ] **Step 2: Write the scripted provider double**

Create `Tests/YoChampsMacTests/Support/ScriptedProvider.swift`, modeled on the `SpyProvider` pattern in `Tests/YoChampsCoreTests/Support/EngineTestDoubles.swift`:

```swift
import Foundation
import YoChampsCore

/// Provider double whose replies are chosen per test. Each `stream` call
/// plays the next mode in order. `block` yields one chunk, then sleeps far
/// past any test so cancellation has a deterministic window.
final class ScriptedProvider: LLMProvider, @unchecked Sendable {
    enum Mode: Sendable {
        case reply([String])
        case block(chunk: String)
    }

    private let modes: [Mode]
    private let lock = NSLock()
    private var index = 0

    init(_ modes: [Mode]) {
        self.modes = modes
    }

    convenience init(_ mode: Mode) {
        self.init([mode])
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        lock.lock()
        let mode = modes[min(index, modes.count - 1)]
        index += 1
        lock.unlock()

        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    switch mode {
                    case let .reply(chunks):
                        for chunk in chunks {
                            continuation.yield(.textDelta(chunk))
                        }
                        continuation.yield(.done)
                        continuation.finish()
                    case let .block(chunk):
                        continuation.yield(.textDelta(chunk))
                        try await Task.sleep(for: .seconds(600))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }
}
```

- [ ] **Step 3: Write the failing tests**

Create `Tests/YoChampsMacTests/CompanionViewModelTests.swift` with a small polling helper (`waitUntil(_:timeout:)`, 5s cap, `Task.sleep` 10ms between checks — `CompanionViewModel` consumes events in its own unstructured task, so tests poll observable state instead of awaiting the stream):

```swift
import Foundation
import Testing
import YoChampsCore
@testable import YoChampsMac
```

Suite `@Suite("CompanionViewModel")` with this builder:

```swift
private func makeViewModel(
    _ modes: ScriptedProvider.Mode...
) -> CompanionViewModel {
    let engine = CompanionEngine(
        provider: ScriptedProvider(modes),
        agent: AgentDefinition(
            id: "champ",
            name: "Champ",
            systemPrompt: "You are Champ.",
            model: "mock-model"
        )
    )
    return CompanionViewModel(engine: engine)
}
```

Tests (each asserts on `model.turns` exactly):

1. `askAppendsTurnAndStreamsAnswer` — `.reply(["one ", "two"])`; `model.question = "hello"`, `model.ask()`; wait until `model.state == .happy`; expect `turns.count == 1`, `turns[0].question == "hello"`, `turns[0].answer == "one two"`.
2. `secondAskKeepsBothTurns` — `.reply(["one"])`; ask "first", wait `.happy`; ask "second" (VM is idle again, so `question = "second"` then `ask()`), wait `.happy`; expect 2 turns, `turns[0].question == "first"`, `turns[0].answer == "one"`, `turns[1].question == "second"`, `turns[1].answer == "one"`.
3. `emptyAnswerStillCompletes` — `.reply([])`; ask "hello"; wait `.happy`; expect 1 turn, question "hello", answer `""`.
4. `cancelMidStreamKeepsPartialAndNextAskAppends` — `makeViewModel(.block(chunk: "part"), .reply(["done"]))`; ask "hello"; wait until `!model.turns.isEmpty && model.turns[0].answer == "part"`; `model.cancel()`; wait `model.state == .idle`; expect 1 turn with answer "part". Then `model.question = "next"`, `model.ask()`; wait `.happy`; expect 2 turns, `turns[0].answer == "part"`, `turns[1].answer == "done"` — the two modes play in order on the same engine, so one VM exercises cancel + re-ask.
5. `newChatClearsTranscript` — `.reply(["one"])`; ask "hello", wait `.happy`; `await model.newChat()`; expect `turns.isEmpty` and `errorMessage == nil`.

- [ ] **Step 4: Run the tests to verify they fail**

Run: `scripts/test.sh 2>&1 | tail -20`
Expected: FAIL — `ChatTurn`/`turns` do not exist (compile error in `CompanionViewModelTests.swift`).

- [ ] **Step 5: Implement the history in CompanionViewModel**

In `Sources/YoChampsMac/CompanionViewModel.swift`:

```swift
struct ChatTurn: Identifiable, Equatable {
    let id = UUID()
    let question: String
    var answer: String
}
```

Add `@Published private(set) var turns: [ChatTurn] = []`. In `ask(_:)`, after the guard: `turns.append(ChatTurn(question: trimmed, answer: ""))` (keep the existing `answer = ""` reset). In `handle(_:)`, `case let .textDelta(delta)` also appends to the last turn:

```swift
if !turns.isEmpty {
    turns[turns.count - 1].answer += delta
}
```

In `newChat()`, set `turns = []` alongside the existing resets. `ChatTurn.id` is a stored `let id = UUID()`; tests compare `question`/`answer`/count fields, never whole-value equality, so no memberwise init with `id` is needed.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `scripts/test.sh 2>&1 | tail -20`
Expected: PASS for all 5 `CompanionViewModel` tests, existing suites still green.

- [ ] **Step 7: Verify the @main import builds**

The test target imports the `YoChampsMac` executable, which contains `@main` in `YoChampsApp.swift`. If Step 6 fails to **build/link** with a `main` symbol error (tests compile but the executable's entry point collides), fall back: create a macOS-only library target `YoChampsCompanionKit` (deps `["YoChampsCore"]`) in the `#if os(macOS)` block, move `CompanionViewModel.swift` into it, make `YoChampsMac` depend on it, point `YoChampsMacTests` at `YoChampsCompanionKit` instead of `YoChampsMac`, and re-run. If tests pass without the fallback, do nothing.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Tests/YoChampsMacTests Sources/YoChampsMac/CompanionViewModel.swift
git commit -m "feat(app): keep multi-turn transcript in ask view model"
```

### Task 2: Chat restyle of AskView

**Files:**
- Modify: `Sources/YoChampsMac/AskView.swift`
- Modify: `Sources/YoChampsMac/MascotImageView.swift`
- Modify: `Sources/YoChampsMac/CompanionViewModel.swift`

**Interfaces:**
- Consumes: `CompanionViewModel.turns: [ChatTurn]` (Task 1), `MascotImageView(renderer:)`.
- Produces: `MascotImageView(renderer:avatarSize:)` — new optional parameter `avatarSize: CGSize? = nil` (default keeps today's behavior). `CompanionViewModel.answer` is removed in this task.

- [ ] **Step 1: Give MascotImageView an avatar mode**

Add `var avatarSize: CGSize? = nil`. In `makeNSView`, when `avatarSize != nil` use `imageScaling = .scaleProportionallyUpOrDown` (keep `.scaleNone` otherwise). In `updateNSView`, only call `uiView.setFrameSize(renderer.frameDisplaySize)` when `avatarSize == nil`. Keep `setAccessibilityIdentifier("mascotPanel")`.

- [ ] **Step 2: Rewrite AskView body**

Replace the current `body` in `AskView.swift` with this hierarchy (keep `onAppear`, `onChange(of: panelState.showToken)`, `onExitCommand` exactly as today):

```
VStack(alignment: .leading, spacing: 10)          // padding 16, frame minWidth 380 minHeight 300
├─ HStack                                          // header
│  ├─ Text("CHAMP")  caption, semibold, letter-spaced,
│  │    padding h10 v4, background(.quaternary, in: Capsule())
│  ├─ Spacer()
│  ├─ Button("New Chat") { model.newChat() }      // .buttonStyle(.link), disabled(model.isBusy)
│  └─ MascotImageView(renderer: renderer,
│                    avatarSize: CGSize(width: 36, height: 36))
├─ ScrollViewReader { proxy in ScrollView {        // transcript, maxHeight .infinity
│     if model.turns.isEmpty {
│       Text(placeholder)  // keep existing copy, .secondary, textSelection
│     }
│     LazyVStack(alignment: .leading, spacing: 12) {
│       ForEach(model.turns) { turn in
│         Text("USR: \(turn.question)")            // .callout, .semibold, textSelection
│         Text(turn.answer.isEmpty ? "RESPONSE: …" : "RESPONSE: \(turn.answer)")
│           // .callout, .primary, textSelection, fixedSize(horizontal: false, vertical: true)
│       }
│     }
│   }
│   .onChange(of: model.turns.last?.answer) { proxy.scrollTo(model.turns.last?.id, anchor: .bottom) }
│   .onChange(of: model.turns.count)        { proxy.scrollTo(model.turns.last?.id, anchor: .bottom) }
├─ error row                                       // unchanged: model.errorMessage, .red, textSelection
├─ HStack { TextField("Ask Champ…", …); Button("Ask") }
│  // keep .roundedBorder, focus, onSubmit, shortcuts, accessibility ids, disabled states
└─ status row                                      // unchanged: statusLabel + Cancel button
```

Rules for the rewrite: semantic styles only (no fixed black/white); every `Text` that can be long gets `textSelection(.enabled)`; the transcript `ScrollView` is the only `maxHeight: .infinity` element so the header/input rows stay fixed on resize; delete the placeholder `Text` variable copy if it now reads wrong for a chat (final wording: keep the existing sentence — it still describes streaming in the chat).

- [ ] **Step 3: Verify lint, build and tests**

Run: `make lint && scripts/test.sh 2>&1 | tail -5 && make build`
Expected: all exit 0; lint clean under SwiftFormat/SwiftLint strict.

- [ ] **Step 4: Remove the legacy `answer` property**

Delete `@Published private(set) var answer = ""` from `CompanionViewModel` and every write to it (`ask(_:)` reset, `newChat()` reset, `handle` delta). Task 1's tests do not assert on `answer`; the view no longer uses it after Step 2.

- [ ] **Step 5: Verify tests and build**

Run: `scripts/test.sh 2>&1 | tail -5 && make build`
Expected: PASS, exit 0.

- [ ] **Step 6: Manual visual check**

Run: `make run`
Check with the app running: two consecutive questions render as two `USR:`/`RESPONSE:` rounds; the transcript auto-scrolls while streaming; resizing to the minimum keeps header/input fixed and the transcript scrolling; light and dark mode both look right; Esc still closes; "New Chat" empties the box. Report what was checked.

- [ ] **Step 7: Commit**

```bash
git add Sources/YoChampsMac/AskView.swift Sources/YoChampsMac/MascotImageView.swift Sources/YoChampsMac/CompanionViewModel.swift
git commit -m "feat(app): restyle ask panel as chat with transcript"
```

### Task 3: Gate and changelog

**Files:**
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces: green `make verify` evidence.

- [ ] **Step 1: Add the changelog bullet**

Under `## [Unreleased]` in `CHANGELOG.md`, append one line (do not touch existing lines; union-merge rules):

`- Ask panel restyled as a chat: multi-turn transcript, CHAMP badge + mascot avatar header, input pinned at the bottom.`

- [ ] **Step 2: Run the full gate**

Run: `make verify`
Expected: lint, test, build, mascot pack validation and secrets all green. Paste the summary output as evidence.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: note ask panel chat restyle"
```
