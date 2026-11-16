# Data, versioning and evolution

## Versioning

- SemVer: `0.x` during V0; `1.0` when the public contract stabilizes.
- `CHANGELOG.md`, tags and release notes track changes.
- `schemaVersion` is written in config, conversations, mascot manifests and
  eval fixtures.

## Migrations

- `Migrator` reads the stored version, writes the current one.
- N-1 migration tests are required; back up before migrating.
- A missing/unknown newer version is refused with a clear error, never guessed.

## Capabilities and feature flags

- `Capability` (streaming, reasoningEffort, tools, maxContext) is declared by
  provider profiles, agents and packs; the UI hides what is unavailable.
- Feature flags live in config, default off, and are removed when a feature
  ships or is dropped.

## Data over code

Providers, agents, tools and mascot packs are JSON data. Adding a provider or a
pack does not require recompiling Core. Editions (personal/public) and channels
(dev/beta/stable) are configuration, never forks.

## Storage

V0: JSON files with `Codable` under
`~/Library/Application Support/YoChamps/`. SQLite/GRDB arrives with history
search/RAG (post-V0); the `ConversationStore` protocol isolates the swap.

## Multi-OS

Post-V1. The Core can ship as a library or behind a JSON-RPC daemon; the shell
is per-OS. V0 is macOS-only, Apple Silicon first.

## Compatibility rules

- Never write a secret into a versioned file.
- Unknown fields in JSON are ignored on read and preserved only where the
  schema says so.
- A migration that fails leaves the old file intact.
