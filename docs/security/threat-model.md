# Threat model (V0)

## Assets

- Provider API keys.
- Conversation history and prompts (may contain personal data).
- The user’s machine and other apps (via screen/automation surfaces).
- The repo’s supply chain (dependencies, CI, hooks).

## Trust boundaries

1. **App ↔ provider:** TLS to a user-configured base URL; the response is
   untrusted text.
2. **App ↔ disk:** config/history in Application Support; keys only in Keychain.
3. **App ↔ OS:** menu bar, hotkey, floating panels, Keychain.
4. **Repo ↔ CI:** workflow runs commands from the default branch; secrets are
   never available to pulls from forks.

## Threats and mitigations

| Threat | Mitigation |
|---|---|
| API key leaked to disk, logs, fixtures or git | Keychain only; `secretRef`; gitleaks; redacted logging; no keys in screenshots |
| Prompt injection via provider output or future attachments | system/developer/user hierarchy; content is data; no side-effectful tools; adversarial eval (M4) |
| Malicious provider endpoint | user-configured URL, visible in settings; TLS; no automatic redirects to unexpected hosts; clear errors |
| Local pack with malicious/huge assets | validator limits (manifest 64 KB, sheet 5 MB, preview 2 MB) and dimension checks; no code execution from packs |
| History exposure on a shared Mac | local files under the user account; clear-history action (M2); no telemetry |
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
- M4 injection eval and review checklist.
