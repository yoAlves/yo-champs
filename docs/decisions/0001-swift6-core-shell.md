# ADR 0001 — Swift 6, pure Core, macOS shell

**Status:** accepted (2026-11-15).
**Covers:** D01, D02, D04, D14.

## Context

V0 is a native menu bar companion for macOS. The risk is UX and OS integration,
not CPU or memory. Testability and a small footprint matter.

## Decision

- Swift 6 with strict concurrency, SwiftUI/AppKit for the shell.
- `YoChampsCore` is pure Foundation and portable; the macOS shell is thin and
  in-process.
- No Rust, no Electron, no Tauri, no daemon in V0.
- macOS 14+, Apple Silicon first.

## Consequences

- Native APIs and small bundles; Core is unit-testable on Linux CI.
- The shell owns everything OS-specific, keeping Core free of AppKit.
- Intel support and other OSes are post-V0 work.
