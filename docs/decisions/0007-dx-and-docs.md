# ADR 0007 — Makefile-first DX and docs policy

**Status:** accepted (2026-11-15).
**Covers:** D10, D13, D16, D19, D20, D23.

## Context

Humans and agents must run the same verified commands, and the repo must stay
reproducible without personal configuration.

## Decision

- The Makefile is the single interface: build, run, test, format, lint, secrets,
  mascot validation, verify, ci, deploy, restart, stop, open, logs, config,
  mascots, hooks and clean. Unimplemented targets fail loudly with their
  milestone.
- `make verify` is the gate and `make ci` is exactly what CI runs.
- `make deploy` is local only (no signing/notarization/publish) in V0; signed
  `make release` is post-V0.
- Specs and ADRs under `docs/` are committed; `notes/`, `scratch/` and `.specs/`
  are local and ignored.
- Project `AGENTS.md`, `opencode.jsonc` and project skills are committed;
  global/personal OpenCode config, auth and `service.json` are not.
- Slash commands are V0.1; lightweight spec-driven development with executable
  gates is used instead of prose-only specs.

## Consequences

- Onboarding is one command (`make bootstrap`), and CI mirrors local gates.
- Every new capability must be added to the Makefile and documented.
- Local-only deploy means distribution safety is deferred deliberately.
