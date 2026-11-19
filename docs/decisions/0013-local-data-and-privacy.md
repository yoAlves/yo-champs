# ADR 0013 — Local data and the outbound payload boundary

**Status:** accepted (2026-11-19).
**Covers:** D30 — what stays on the Mac and what leaves in a provider request.

## Context

The app keeps provider profiles, conversation history and API keys on the
user’s Mac, and sends the conversation to a user-configured endpoint. V0 had no
single document stating that split, and the history had no size or permission
boundary. Without one, an added field, header or log line could leak local state
without anyone noticing.

## Decision

**Local-only data**

- `config.json`: provider profiles (base URL, model, label, non-secret headers,
  `secretRef`) in the app’s own Application Support directory.
- `history.json`: `{schemaVersion: 1, messages: [...]}` under
  `~/Library/Application Support/YoChamps/`, written atomically.
- API keys: Keychain only (service `com.yurioliveira.yochamps`). Config holds a
  reference, never a value.
- No telemetry, no backend, no cloud sync, no auto-update.

**Storage boundary**

- History is capped at 2 MB of encoded JSON. When it grows past the cap, the
  oldest complete user/assistant turns are dropped; the newest turn is kept even
  when it alone exceeds the cap.
- The history directory (the app’s own Application Support directory) is set to
  mode `0700` and `history.json` to `0600` on every history save, including when
  the directory already existed.
- No app-level encryption in V0. At-rest protection is the OS disk encryption
  (FileVault) plus those POSIX modes; the Keychain is encrypted by macOS.
- No SQLite yet: JSON stays behind the `ConversationStore` protocol.

**Outbound boundary**

- A provider request carries exactly `model`, `messages`, `stream` (always
  `true`), and the optional `max_tokens` and `temperature`.
- Headers are the profile’s non-secret headers plus `Content-Type` and an
  `Authorization: Bearer` header added from the Keychain at send time. The
  provider itself adds no credential header and stores no key.
- Never in the body: file paths, Keychain references, conversation IDs,
  app/user identity fields or telemetry.
- HTTPS is required outside loopback. `http` is accepted only for
  `localhost`, `127.0.0.1` and `::1`, so a local model can run without TLS.

`Tests/YoChampsProvidersTests/PrivacyPayloadTests.swift` captures the request
the provider builds and fails if the body key set or headers change.

## Consequences

- History is plaintext within the user account: a process running as the same
  user can still read it. FileVault is the at-rest dependency until a later
  encryption design exists.
- The 2 MB cap bounds disk use and keeps the file cheap to rewrite, at the cost
  of dropping the oldest turns.
- The payload test makes the boundary executable: a new field is a deliberate
  decision, not an accidental leak.
- Moving to SQLite or adding encryption changes storage behind
  `ConversationStore`; the outbound boundary does not change.

## Future (not in V0)

- SQLite/GRDB for history search and RAG.
- Optional app-level encryption with an explicit key-management story.
- Rehydrating the stored transcript into the Ask window on launch; history is
  currently written but not replayed into a new session.

## Alternatives

- **SQLite from day zero (ADR 0005).** Rejected: database and migration cost
  before the data shape stabilizes.
- **App-level encryption now.** Rejected: no key-management UX yet, and a
  password prompt for a menu bar companion is worse than FileVault.
- **Store keys in Application Support.** Rejected: Keychain is the only store
  for secrets (ADR 0006).
- **Allow any `http` base URL.** Rejected: silently exposes prompts and keys to
  the network; loopback is the only trusted plaintext case.
