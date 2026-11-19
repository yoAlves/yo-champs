# Threat model (V0)

## Assets

- Provider API keys.
- Conversation history and prompts (may contain personal data).
- The user’s machine and other apps (via screen/automation surfaces).
- The repo’s supply chain (dependencies, CI, hooks).

## Trust boundaries

1. **App ↔ provider:** TLS to a user-configured base URL (plain `http` only for
   loopback); the response is untrusted text.
2. **App ↔ disk:** config and history in the app’s own Application Support
   directory (directory `0700`, `history.json` `0600`); keys only in Keychain.
3. **App ↔ OS:** menu bar, hotkey, Ask window, Keychain.
4. **Repo ↔ CI:** workflow runs commands from the default branch; secrets are
   never available to pulls from forks.

## Threats and mitigations

| Threat | Mitigation |
|---|---|
| API key leaked to disk, logs, fixtures or git | Keychain only; `secretRef`; gitleaks; redacted logging; no keys in screenshots |
| Prompt injection via provider output or future attachments | system/developer/user hierarchy; content is data; no side-effectful tools; adversarial eval is an open M4 backlog item |
| Malicious provider endpoint | user-configured URL, visible in settings; HTTPS required outside loopback (`localhost`/`127.0.0.1`/`::1` only for `http`); no automatic redirects to unexpected hosts; clear errors |
| Local pack with malicious/huge assets | validator limits (manifest 64 KB, sheet 5 MB, preview 2 MB) and dimension checks; no code execution from packs |
| History exposure on a shared Mac | files under the user account, directory `0700` and `history.json` `0600`; 2 MB history cap; clear-history action (M2); no telemetry. See [`data-and-privacy.md`](data-and-privacy.md) |
| Supply chain (dependencies, actions, MCP) | minimal dependencies, pinned versions, reviewed actions, opt-in MCP (ADR 0008) |
| Secret in a commit | pre-commit gitleaks, `make verify`, CI; GitHub push protection |
| Update tampering | no auto-update in V0; signed/notarized releases are post-V0 |

## Explicit non-goals

- Compromised OS or Keychain client.
- Malicious local apps with screen-recording or accessibility permissions.
- Provider-side data handling beyond the app’s contract.

## Verification

- `make verify` (gitleaks included) and the pre-commit hook.
- Pack validator limits.
- Provider payload boundary test (`PrivacyPayloadTests`): fixed body keys, no
  secret/path/telemetry fields, no invented `Authorization` header.
- M4 injection eval and review checklist.
