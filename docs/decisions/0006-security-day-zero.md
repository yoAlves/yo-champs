# ADR 0006 — Security from day zero

**Status:** accepted (2026-11-15).
**Covers:** D11, D15, D25.

## Context

A companion app handles API keys and user questions. Retrofitting security is
more expensive and riskier than building it in.

## Decision

- API keys only in the Keychain (service `com.yurioliveira.yochamps`); config
  holds `secretRef`.
- gitleaks in pre-commit, `make verify` and CI; GitHub secret scanning and push
  protection on the remote.
- `os.Logger` with `privacy: .private` for user-derived values; no secrets in
  fixtures, screenshots or logs.
- No telemetry and no cloud backend in V0; provider calls only on explicit user
  action.
- Prompt hierarchy (system/developer/user); attachments and web content are
  data. No side-effectful tools in V0.
- `.gitignore` covers scratch/notes/.specs/auth/.env; `.env.example` is the only
  example and contains names, not values.

## Consequences

- Some setup friction (Keychain prompts, gitleaks on first run) is accepted.
- Security docs and evals are part of the milestone gates, not a later pass.
