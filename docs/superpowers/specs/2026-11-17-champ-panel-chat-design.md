# Champ Panel Chat Restyle — Design

**Date:** 2026-11-17
**Status:** Approved (conversation 2026-11-17); header and text rendering
superseded on 2026-11-19 (Markdown answers, copy on select, avatar moved to the
left) — see `docs/delivery/status.md`.

## Intent

Turn the floating ask panel into a chat-style companion box: a header with a
"CHAMP" badge and a small mascot avatar, a scrollable multi-turn transcript,
and the input pinned at the bottom — the look of the approved hand sketch.
The panel follows the system light/dark appearance and stays responsive to
resizing.

## Goals

- Real multi-turn history in the panel: previous question/answer rounds stay
  visible and scrollable; streaming fills the last turn in place.
- Header: "CHAMP" badge on the left, mascot avatar (~36pt) on the right.
  The avatar keeps animating from `CompanionState` via `MascotRenderer`.
- Transcript inside an inset rounded box, auto-scrolling to the newest turn
  while streaming.
- Input row ("Ask Champ…" + Ask) and status/error row fixed at the bottom.
- Colors are semantic (`primary`, `.quaternary`, materials) so the panel
  follows macOS dark/light automatically. No hard-coded black.
- Layout flexes on resize: transcript stretches, header and input stay fixed;
  min size 380×300 (view aligns with the panel's `contentMinSize`).

## Non-goals

- No history persistence across app launches.
- No changes to `YoChampsCore`, `CompanionEngine`, providers or context.
- No window chrome change: traffic lights, Esc, ⌘W, hotkey, focus and
  frame-restore behavior stay exactly as today.

## Constraints

- Dependency direction `YoChampsMac → YoChampsCore → Foundation`.
- Core knows no provider, model or vendor name; display history is data in
  the Mac layer only.
- TDD with Swift Testing; `make verify` stays the gate.
- Conventional Commits, subject ≤72 chars, no AI attribution.

## Approaches considered

1. **Display history in the Mac shell (chosen):** `CompanionViewModel`
   accumulates `[ChatTurn]`; the engine keeps its own conversation context
   (`newChat()` already exists). No Core change. Smallest safe diff; visual
   result identical for the user.
2. **History exposed by Core:** transcript DTO on `CompanionEngine`, mirrored
   by the VM. Rejected for V0: over-engineering; no other frontend needs it
   and no persistence was requested (scope creep is a defect).
3. **Visual-only restyle, one answer at a time:** rejected — the user
   confirmed they want the multi-turn history the sketch shows.

## Decisions

- `ChatTurn` is `Identifiable, Equatable` (`id: UUID`, `question`, `answer`).
  `CompanionViewModel.ask(_:)` appends the turn; deltas append to the last
  turn's answer; `newChat()` clears the list; a failed turn keeps its partial
  answer with the error shown by the existing `errorMessage` row.
- The existing `answer` property is deleted once `AskView` stops using it
  (same change that rewrites the view).
- Transcript lines render conversation-style: the user's question has no
  prefix; the response is preceded by a bullet (`• …`).
- O avatar do header usa SwiftUI `Image(nsImage:).resizable().scaledToFit()`
  com frame fixo de 56pt; a abordagem com `avatarSize` em `MascotImageView`
  foi revertida porque o `intrinsicContentSize` do `NSImageView` ignorava o
  frame proposto pelo SwiftUI.
- Unit tests for the view model live in a new `YoChampsMacTests` target
  (macOS-only), driving a real `CompanionEngine` with a scripted fake
  `LLMProvider`.
