# ADR 0005 — JSON storage, schema versions and migrations

**Status:** accepted (2026-11-15).
**Covers:** D07, D18, D22.

## Context

V0 needs multi-turn history and configuration without database complexity, but
on-disk formats will change.

## Decision

- Conversations and config are JSON with `Codable` under
  `~/Library/Application Support/YoChamps/`.
- Every persisted document has a `schemaVersion`; a `Migrator` upgrades N-1 and
  backs up first. Unknown newer versions are refused, never guessed.
- Keys are never written to these files; only `secretRef` values.
- Editions (personal/public) and channels (dev/beta/stable) are configuration
  and capabilities, never forks.
- SQLite/GRDB is post-V0 and isolated behind `ConversationStore`.

## Consequences

- Simple, inspectable files for V0.
- Migration tests are mandatory as soon as a schema exists (M2).
- Swapping to a database does not touch the engine.
