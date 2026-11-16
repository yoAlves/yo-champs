# ADR 0008 — No MCP in V0

**Status:** accepted (2026-11-15).
**Covers:** D09, D24.

## Context

MCP adds tools and integrations, but V0 validates the core loop and UI. MCP is
an executable supply-chain surface and would not help validate the app.

## Decision

- V0 ships no MCP client or server.
- UI validation uses XCUITest, snapshots, `YoChampsMascotValidator` and evals.
- When MCP arrives: pin version/command, review the server, least privilege,
  no inline secrets (`{env:VAR}` or OAuth), opt-in, off the build/test critical
  path.
- The project `opencode.jsonc` keeps `mcp` empty until then.

## Consequences

- Smaller attack surface and a simpler V0.
- Integrations wait for V1; the Core tool contract is designed now so they can
  be added without redesign.
