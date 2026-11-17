# M3 Character Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Yo Champs a persistent, draggable Champ driven by the six semantic engine states, with a global hotkey, local pack loading and a real XCUITest gate.

**Architecture:** Pure decisions (state→frame mapping, pack selection) live in `YoChampsCore` and are tested with Swift Testing; AppKit owns the floating panel, frame drawing, drag persistence and hotkey; an Xcode project with a UI test target wraps the existing SwiftPM sources for `make test-ui`.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Swift Testing 6.2.4, `KeyboardShortcuts`, XcodeGen + `xcodebuild test`, Python/Pillow for art.

**Spec:** `docs/superpowers/specs/2026-11-16-m3-character-design.md` and `docs/delivery/milestones/M3.md`.

## Global Constraints

- Dependency direction `YoChampsMac → YoChampsCore → Foundation`; Core imports no AppKit/SwiftUI and no vendor/model name.
- Menu bar only (`LSUIElement`); closing Champ hides it and keeps the process alive.
- Secrets only in the Keychain; no new credential is needed in M3.
- Default pack is original Champ art; no Microsoft asset or Clippy name anywhere.
- `make verify` and `make provider-check` stay green throughout.
- `make test-ui` is a standalone local gate, not wired into `verify`/`ci` in M3.
- Commit messages: Conventional Commits, subject ≤72 chars, **no AI attribution**.
- Work on `feature/m3-character` from up-to-date `main`; PR with `--assignee @me`.

## Review Focus

1. **An answer with no text deltas** must produce `confused`, never a happy answer persisted as empty → Task 2 test.
2. **Several local packs, or an invalid local pack** must yield a clear user-facing error and still load the default → Task 4 tests.
3. **Hiding Champ during a stream** must stop the turn so nothing streams invisibly → Task 7 UI test.
4. **Dragging to another display / off-screen** must clamp the frame and restore it after restart → Task 8 UI test (drag + relaunch); Task 6 implements the clamp.
5. **A malformed pack** (missing animation, wrong sheet geometry) must be rejected by the same rules the app uses → Task 1 validation and Task 4 tests.

---

### Task 1: Multi-frame Champ pack

**Files:**
- Modify: `scripts/gen-champ-pack.py`
- Modify: `Resources/Mascots/Default/manifest.json`, `spritesheet.png`, `preview.png`
- Modify: `docs/architecture/mascot-pack.md` (frame counts)

**Interfaces:**
- Produces: a valid pack whose `orderedAnimationIds` frame counts are `idle 1, thinking 2, talking 3, happy 2, confused 2, error 2` (total 12 frames).

- [ ] **Step 1: Change the generator to emit per-state frame variants**

For `idle` emit one frame; for the other five states emit 2–3 frames with small programmatic variations (eye shift, mouth opening, bob). Keep the transparent background and 64×64 frame size; the spritesheet remains a horizontal strip in `MascotManifest.requiredAnimations` order.

- [ ] **Step 2: Regenerate and validate the default pack**

Run: `python3 scripts/gen-champ-pack.py Resources/Mascots/Default && make mascot-validate`
Expected: exit 0 and `ok .../Resources/Mascots/Default`, `validated 1 pack(s)`.

- [ ] **Step 3: Check the frame count against the manifest**

Run: `python3 -c "import json; d=json.load(open('Resources/Mascots/Default/manifest.json')); a=d['animations']; print(sum(v['frames'] for v in a.values()), [a[k]['frames'] for k in ['idle','thinking','talking','happy','confused','error']])"`
Expected: `12 [1, 2, 3, 2, 2, 2]`.

- [ ] **Step 4: Commit**

```bash
git add scripts/gen-champ-pack.py Resources/Mascots/Default docs/architecture/mascot-pack.md \
  docs/superpowers/specs/2026-11-16-m3-character-design.md \
  docs/superpowers/plans/2026-11-16-m3-character.md
git commit -m "feat(mascot): add animated Champ frames"
```

### Task 2: `confused` from a real engine event

**Files:**
- Modify: `Sources/YoChampsCore/Engine/CompanionEngine.swift`
- Test: `Tests/YoChampsCoreTests/CompanionEngineTests.swift`

**Interfaces:**
- Consumes: `CompanionEvent.state(CompanionState)` (existing).
- Produces: an empty/whitespace-only provider answer emits `.state(.confused)` and still emits `.completed`.

- [ ] **Step 1: Write the failing test**

Add a test using the existing mock/store doubles: a provider that emits `.done` with no `.textDelta` produces events `[.state(.thinking), .state(.confused), .completed]` and stores an empty assistant message.

- [ ] **Step 2: Run it to see it fail**

Run: `make test`
Expected: FAIL — the engine emits `.state(.happy)`.

- [ ] **Step 3: Implement the branch in `CompanionEngine.run`**

After the stream loop and `Task.checkCancellation()`, choose `.confused` when `answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`, otherwise `.happy`; persist first, then emit the chosen state and `.completed`.

- [ ] **Step 4: Run the suite**

Run: `make test`
Expected: PASS, 106 tests (was 105).

- [ ] **Step 5: Commit**

```bash
git add Sources/YoChampsCore/Engine/CompanionEngine.swift Tests/YoChampsCoreTests/CompanionEngineTests.swift
git commit -m "feat(core): emit confused for empty answers"
```

### Task 3: Pure state→frame mapping

**Files:**
- Create: `Sources/YoChampsCore/Mascot/MascotFrameSequence.swift`
- Test: `Tests/YoChampsCoreTests/MascotFrameSequenceTests.swift`

**Interfaces:**
- Consumes: `MascotManifest`, `CompanionState` (existing).
- Produces:

```swift
public struct MascotFrameSequence: Sendable {
    public init(manifest: MascotManifest)
    public func animationID(for state: CompanionState) -> String
    public func frameIndices(for state: CompanionState) -> [Int]
    public func fps(for state: CompanionState) -> Double
    public func loops(for state: CompanionState) -> Bool
    public var frameSize: MascotManifest.Size { get }
    public var anchor: MascotManifest.Anchor { get }
}
```

- [ ] **Step 1: Write failing tests for the mapping and offsets**

Assert: `streaming → "talking"`; `frameIndices(.idle) == [0]`; `frameIndices(.thinking) == [1, 2]`; `frameIndices(.streaming) == [3, 4, 5]`; `loops(.idle) == true`; `loops(.happy) == false`; `fps` equals the manifest value for the mapped id. Use a manifest built in the test with the Task 1 frame counts.

- [ ] **Step 2: Run them to see them fail**

Run: `make test`
Expected: FAIL — `MascotFrameSequence` does not exist.

- [ ] **Step 3: Implement `MascotFrameSequence`**

Map states explicitly through the six required ids; compute each animation's absolute starting index from `manifest.orderedAnimationIds` and cumulative `frames`; return `Array(start..<(start+frames))`. No AppKit/Foundation image work here.

- [ ] **Step 4: Run the suite**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/YoChampsCore/Mascot/MascotFrameSequence.swift Tests/YoChampsCoreTests/MascotFrameSequenceTests.swift
git commit -m "feat(core): map companion states to sprite frames"
```

### Task 4: Local pack selection rules

**Files:**
- Create: `Sources/YoChampsCore/Mascot/MascotPackSelector.swift`
- Test: `Tests/YoChampsCoreTests/MascotPackSelectorTests.swift`

**Interfaces:**
- Consumes: `URL` (Foundation).
- Produces:

```swift
public struct MascotPackCandidate: Sendable, Equatable {
    public let id: String
    public let name: String
    public let directory: URL
    public let validationError: String?
    public init(id: String, name: String, directory: URL, validationError: String?)
}
public enum MascotPackSelection: Sendable, Equatable {
    case `default`
    case local(MascotPackCandidate)
    case invalidLocal(reason: String)
    case ambiguous(count: Int)
}
public enum MascotPackSelector {
    public static func select(localPacks: [MascotPackCandidate]) -> MascotPackSelection
}
```

- [ ] **Step 1: Write failing tests for all four outcomes**

Assert: no candidates → `.default`; one valid → `.local(candidate)`; one candidate with `validationError` → `.invalidLocal(reason:)`; two valid → `.ambiguous(count: 2)`.

- [ ] **Step 2: Run them to see them fail**

Run: `make test`
Expected: FAIL — selector does not exist.

- [ ] **Step 3: Implement `MascotPackSelector.select`**

Validation errors take precedence; otherwise zero/one/many decide the result. This type performs no I/O.

- [ ] **Step 4: Run the suite**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/YoChampsCore/Mascot/MascotPackSelector.swift Tests/YoChampsCoreTests/MascotPackSelectorTests.swift
git commit -m "feat(core): select local mascot packs with clear errors"
```

### Task 5: Mac pack loader and Settings error

**Files:**
- Create: `Sources/YoChampsMac/MascotPackLoader.swift`
- Modify: `Sources/YoChampsMac/SettingsView.swift`, `Sources/YoChampsMac/SettingsViewModel.swift`

**Interfaces:**
- Consumes: `MascotPackValidator`, `MascotPackSelector`, `AppPaths` (existing).
- Produces:

```swift
public struct MascotPack: Sendable {
    public let manifest: MascotManifest
    public let spritesheetURL: URL
}
public enum MascotPackLoadResult: Sendable {
    case selected(MascotPack)
    case fallback(MascotPack, message: String)
}
public struct MascotPackLoader {
    public init(supportDirectory: URL = AppPaths.supportDirectory)
    public func load() throws -> MascotPackLoadResult
}
```

- [ ] **Step 1: Implement the loader using the existing validator**

Load the default pack from `Bundle.main.resourceURL` (falling back to `Resources/Mascots/Default` for debug builds), enumerate `AppPaths.supportDirectory/Mascots/*`, validate each candidate with `MascotPackValidator(imageSize:)` (ImageIO `pngSize`), map failures into `MascotPackCandidate.validationError`, and call `MascotPackSelector.select`. A `.invalidLocal` or `.ambiguous` result returns `.fallback(defaultPack, message:)`; `.default` returns `.fallback(defaultPack, message: "")`.

- [ ] **Step 2: Surface the fallback message in Settings**

Add a `mascotStatus: String?` published property to `SettingsViewModel`; set it from the loader result so a clear message is visible when the user opens Settings. Use `os.Logger` with `.private` for the detail.

- [ ] **Step 3: Verify build and lint**

Run: `make lint && make build`
Expected: exit 0, no violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/YoChampsMac/MascotPackLoader.swift Sources/YoChampsMac/SettingsView.swift Sources/YoChampsMac/SettingsViewModel.swift
git commit -m "feat(app): load default and local mascot packs"
```

### Task 6: Renderer and draggable Champ panel

**Files:**
- Create: `Sources/YoChampsMac/MascotRenderer.swift`
- Create: `Sources/YoChampsMac/MascotPanelController.swift`

**Interfaces:**
- Consumes: `MascotPack`, `MascotFrameSequence` from Tasks 3/5.
- Produces:

```swift
@MainActor final class MascotRenderer {
    init(pack: MascotPack)
    func setState(_ state: CompanionState)
    func setHidden(_ hidden: Bool)
    var currentImage: NSImage? { get }
}
@MainActor final class MascotPanelController {
    init(renderer: MascotRenderer)
    func show(); func hide(); func toggle()
    var frame: NSRect { get }
}
```

- [ ] **Step 1: Implement `MascotRenderer`**

Crop the current frame from the spritesheet using `MascotFrameSequence.frameIndices`; scale by `manifest.scale`; create one `Timer` only when the current animation has more than one frame, firing at `fps` and honouring `loop`. `setHidden(true)` invalidates the timer; `setState` resets frame index 0 and rebuilds the timer. No timer for single-frame states.

- [ ] **Step 2: Implement `MascotPanelController`**

Create a borderless transparent `NSPanel` with `.floating` level and `canJoinAllSpaces`, movable by background, `isReleasedWhenClosed = false`. Host the renderer image in an `NSImageView`; persist the origin in `UserDefaults` under `com.yurioliveira.yochamps` on `windowDidMove`; clamp to the union of `NSScreen.screens` visible frames on show and after moves. `hide()` calls `renderer.setHidden(true)` and `orderOut`.

- [ ] **Step 3: Verify build and the existing gate**

Run: `make verify`
Expected: exit 0 (lint, 106+ tests, builds, pack, gitleaks).

- [ ] **Step 4: Commit**

```bash
git add Sources/YoChampsMac/MascotRenderer.swift Sources/YoChampsMac/MascotPanelController.swift
git commit -m "feat(app): add animated mascot panel with saved position"
```

### Task 7: Hotkey, menu wiring and bubble anchoring

**Files:**
- Modify: `Package.swift`, `Package.resolved`
- Modify: `Sources/YoChampsMac/YoChampsApp.swift`, `Sources/YoChampsMac/AskPanel.swift`, `Sources/YoChampsMac/SettingsView.swift`

**Interfaces:**
- Consumes: `MascotPanelController` (Task 6), `CompanionViewModel.stop()` (existing).
- Produces: `KeyboardShortcuts.Name.ask`; `AskPanelController.init(model:anchorProvider:)` where `anchorProvider: () -> NSRect?`.

- [ ] **Step 1: Add the `KeyboardShortcuts` dependency and hotkey name**

Add a compatible package to `Package.swift` and declare `extension KeyboardShortcuts.Name { static let ask = ... }` with default ⌥⌘Y. Add `KeyboardShortcuts.Recorder(for: .ask)` to Settings. Register `KeyboardShortcuts.onKeyDown(for: .ask)` in `AppDelegate` to toggle the mascot panel on the main actor.

- [ ] **Step 2: Enable Show/Hide and make close hide-only**

Replace the disabled `"Show Champ (M3)"` menu item with a bound Show/Hide action that calls `MascotPanelController.toggle()`. Route the mascot panel's close to `hide()` and also call `model.stop()` so an in-flight answer cannot continue invisibly. Keep the process alive.

- [ ] **Step 3: Anchor the ask bubble to Champ**

Change `AskPanelController` to accept `anchorProvider`; in `show()`, position the panel near the mascot frame (trailing edge, vertically centred) clamped to the same screen. When the provider returns `nil`, keep the current centred placement.

- [ ] **Step 4: Verify build and lint**

Run: `make lint && make build`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Package.resolved Sources/YoChampsMac
git commit -m "feat(app): add global hotkey, show/hide and bubble anchoring"
```

### Task 8: Xcode project and real XCUITest

**Files:**
- Create: `project.yml`, `YoChamps.xcodeproj/**`
- Create: `UITests/YoChampsUITests.swift`
- Modify: `Makefile`, `scripts/test-ui.sh` (create if needed)

**Interfaces:**
- Consumes: accessibility identifiers added to the ask and mascot panels in Task 7.
- Produces: `make test-ui` runs `xcodebuild test` and exits 0 only on real XCUITest success.

- [ ] **Step 1: Create the Xcode project with XcodeGen**

Install `xcodegen` via Homebrew, write `project.yml` with a UI test target referencing the local SwiftPM package, generate and commit `YoChamps.xcodeproj` so the gate needs no generator at test time.

- [ ] **Step 2: Add accessibility identifiers and the UI test flow**

Give the ask field, Send button and mascot panel stable identifiers. Write XCUITest cases: hotkey opens Ask, Esc closes it, Show/Hide keeps the app process alive, and drag then relaunch restores the position.

- [ ] **Step 3: Wire `make test-ui`**

Replace the stub in the Makefile with `scripts/test-ui.sh`, which runs `xcodebuild test -project YoChamps.xcodeproj -scheme YoChampsUITests -destination 'platform=macOS'` and propagates the exit code.

- [ ] **Step 4: Run the new gate**

Run: `make test-ui`
Expected: exit 0 with all UI tests passing; no stub message.

- [ ] **Step 5: Commit**

```bash
git add project.yml YoChamps.xcodeproj UITests Makefile scripts/test-ui.sh
git commit -m "test(ui): add real XCUITest gate for M3"
```

### Task 9: Gate evidence and review

**Files:**
- Modify: `docs/delivery/status.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: green results from Tasks 6 and 8.

- [ ] **Step 1: Run the full gate**

Run: `make verify && make mascot-validate && make test-ui && make deploy && make restart`
Expected: every command exits 0; capture the output.

- [ ] **Step 2: Record evidence**

Add an M3 gate table to `docs/delivery/status.md` with the exact commands, exit codes and test counts; add an entry under `## [Unreleased]` in `CHANGELOG.md`.

- [ ] **Step 3: Commit and open the PR**

```bash
git add docs/delivery/status.md CHANGELOG.md
git commit -m "docs: record M3 gate evidence"
git push -u origin feature/m3-character
gh pr create --base main --assignee @me --title "feat(m3): character, hotkey and XCUITest" --body "M3 character milestone."
```

- [ ] **Step 4: Wait for CI, then merge**

Verify both required checks pass on the PR head, then `gh pr merge <number> --merge`.

- [ ] **Step 5: Whole-branch review**

Dispatch one fresh reviewer over `main..feature/m3-character`; fix critical/important findings, then do at most one focused re-review.
