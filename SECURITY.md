# Security policy

## Reporting a vulnerability

This is a personal project. Report issues privately to the repository owner
(GitHub private vulnerability reporting or a direct message); do not open a
public issue with exploit details. Expect an initial response within a few days.

Do not include real API keys, tokens or personal data in a report. Rotate any
credential you believe was exposed.

## Supported versions

V0 is pre-release (`0.x`). Only the latest `main` receives fixes.

## Security posture (V0)

- **Secrets:** API keys live in the macOS Keychain (service
  `com.yurioliveira.yochamps`). Config files hold `secretRef` only.
- **No telemetry, no cloud backend:** network calls happen only on explicit
  user action to the configured provider.
- **Logs:** `os.Logger` with `privacy: .private` for user-derived values.
- **Secret scanning:** gitleaks in the pre-commit hook, `make verify` and CI.
  Enable GitHub secret scanning and push protection on the remote.
- **Prompt injection:** system/developer/user hierarchy; attachments and web
  content are data, never instructions. No side-effectful tools in V0. See
  `docs/security/threat-model.md` and `docs/security/prompt-injection.md`.
- **Supply chain:** dependencies are minimal and pinned. MCP is opt-in and
  version-pinned (ADR 0008); V0 ships no MCP servers.
- **Builds:** `make deploy` is local and unsigned. Signed/notarized releases
  are out of V0 scope.

## Out of scope

- Physical access to an unlocked Mac.
- Attacks requiring a compromised OS or a malicious Keychain client.
- Third-party packs or provider behaviour outside the app's contract.

## Disclosure

Fixes ship with a changelog entry. Credit is given unless you ask otherwise.
