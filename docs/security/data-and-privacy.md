# Data and privacy (V0)

What stays on the Mac, what leaves in a provider request, and what the app
never does. See [ADR 0013](../decisions/0013-local-data-and-privacy.md) for the
decision and [`threat-model.md`](threat-model.md) for the risks.

## Principle

The conversation goes to the provider the user configured, and nowhere else.
There is no telemetry, backend or cloud sync, and no provider call happens
without a user action.

## What stays local

| Data | Where | Notes |
|---|---|---|
| Provider profiles | `config.json` in the app’s own Application Support directory | base URL, model, label, non-secret headers, `secretRef`; never a key value |
| Conversation history | `history.json` under `~/Library/Application Support/YoChamps/` | `{schemaVersion: 1, messages: [...]}`, written atomically, capped at 2 MB |
| API keys | macOS Keychain, service `com.yurioliveira.yochamps` | read at send time and never written to config, history or logs |
| Mascot packs | local packs in `Application Support/YoChamps/Mascots/`, default pack in the app bundle | assets only, no conversation content |
| Logs | `os.Logger` | user-derived values use `privacy: .private` |

File permissions: the history directory (the app’s own Application Support
directory, `~/Library/Application Support/YoChamps/`) is set to mode `0700` and
`history.json` to `0600` on every history save.

The 2 MB cap is on encoded JSON. Past it, the oldest complete user/assistant
turns are dropped; the newest turn is kept even when it alone is larger.

## What leaves the machine

Only the provider request, sent to the base URL in the selected profile:

| Field | Content |
|---|---|
| `model` | model id configured in the profile |
| `messages` | the system prompt and the user/assistant turns in the conversation |
| `stream` | always `true` |
| `max_tokens` | optional generation limit |
| `temperature` | optional sampling value |
| headers | the profile’s non-secret headers, `Content-Type: application/json`, and `Authorization: Bearer <key>` added from the Keychain at send time |

The body never carries file paths, Keychain references, conversation IDs,
telemetry fields or app/user identity. The provider itself adds no
`Authorization` header: credentials come from the request headers.

`Tests/YoChampsProvidersTests/PrivacyPayloadTests.swift` pins that boundary by
capturing the built request.

Transport: HTTPS outside loopback. Plain `http` is rejected unless the host is
`localhost`, `127.0.0.1` or `::1`, which is how a local model can be used.

## What the app never does

- No telemetry, analytics, crash reporting or usage metrics.
- No backend, account, cloud sync or remote config.
- No auto-update; releases are installed manually.
- No reading of other apps’ data, screen content or clipboard in V0.
- No tools or MCP; the model cannot act on the machine.

## At rest

V0 has no app-level encryption. Conversation history is plaintext JSON,
protected by the user account, POSIX modes and the OS disk encryption
(FileVault). The Keychain is encrypted by macOS. A same-user process can read
the files; the threat model lists this as a non-goal to defend against.

## Future

- SQLite/GRDB for history search and RAG (post-V0).
- Optional app-level encryption with an explicit key-management story.
- Replaying the stored transcript into the Ask window on launch; history is
  written today but not rehydrated into a new session.
