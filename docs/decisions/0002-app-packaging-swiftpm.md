# ADR 0002 — M0 app packaging with SwiftPM and scripts/bundle.sh

**Status:** accepted (2026-11-15), provisional until XCUITest lands.
**Covers:** D01, D16, D20; M0 ruling.

## Context

The plan allows Xcode or XcodeGen for the app. The M0 machine has only Command
Line Tools (`xcode-select` points at `/Library/Developer/CommandLineTools`);
`xcodebuild` fails and no `Xcode.app` is installed. Requiring Xcode at M0 would
block the foundation gate on an install outside the repo.

## Decision

- Build the menu bar executable with SwiftPM (`YoChampsMac`).
- Assemble `YoChamps.app` in `scripts/bundle.sh`: copy `App/Info.plist` and the
  executable, ad-hoc sign, print the bundle path.
- `make deploy` copies that bundle to `~/Applications` and opens it.
- No `.xcodeproj` in M0. `make test-ui` is documented as blocked until full
  Xcode is available; M1/M3 will add an Xcode/XcodeGen project for XCUITest.

## Consequences

- The M0 gate does not depend on Xcode, only Command Line Tools.
- XCUITest cannot run yet; the milestone stays blocked on that criterion until
  Xcode is installed.
- `scripts/bundle.sh` remains useful for fast local builds after Xcode lands.
- Cost if wrong: we add an Xcode project earlier than planned; no throwaway work.
