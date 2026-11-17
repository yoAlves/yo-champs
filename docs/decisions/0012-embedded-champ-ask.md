# ADR 0012 — Champ embedded in the Ask window

**Status:** accepted (2026-11-17). Supersedes the separate-window, drag and
persisted-position parts of the M3 character contract.
**Covers:** D29 — window model for the mascot.

## Context

M3 shipped Champ as a separate floating, draggable `NSPanel` with a persisted
position, and anchored the answer bubble to it. In daily use that split the
product into two windows: the Ask prompt could sit behind the character, the
answer followed a window the user had moved, and both had to be managed
independently. The separate mascot also had no purpose when the chat was
closed.

The post-M3 product decision is one window: the conversation and the character
belong together.

## Decision

- Champ renders inside the Ask window, as a fixed avatar in the chat header.
  It is not scaled to the window and never overlaps the transcript.
- The separate mascot window and the mascot's drag/position persistence are
  removed. The Ask window itself remains movable by its background and its
  frame is autosaved.
- The menu item now labeled **Show/Hide Ask** toggles the Ask window. Esc hides
  it; the process keeps running and an in-flight turn is stopped.
- The global hotkey (⌥⌘K by default) opens Ask and focuses the input.
- The Ask window is a floating-level `NSPanel`, resizable, with its frame
  persisted by `frameAutosaveName`.

## Consequences

- One window is the product: `Ask` contains the transcript, the input and
  Champ. There is no second window to place, hide or restore.
- The mascot is visible only while the chat is open; the nostalgia lives in the
  header instead of a desktop pet.
- The M3 drag/position criteria are historical and marked superseded in
  `docs/delivery/milestones/M3.md`; they are not claimed as delivered.
- XCUITest covers hotkey, Esc, show/hide of the Ask window, embedded layout and
  new chat. The old drag-then-relaunch case is gone with the behaviour.
- A local pack still changes the art; only the window model changed.

## Alternatives

- **Keep the floating mascot panel and anchor the bubble to it (shipped in
  M3).** Rejected: two windows with independent state, the panel could cover
  the prompt, and it could be restored off-screen.
- **Keep both: floating mascot plus an embedded duplicate.** Rejected: two
  renderers, two states, no user value.
- **Overlay the mascot on the transcript with clipping.** Rejected: it is the
  overlap bug in disguise and does not reserve layout space.
