# ADR 0010 — GitFlow with protected branches

**Status:** accepted (2026-11-16).
**Covers:** D27 — branching, PRs and protected branches.

## Context

M0 was built directly on `main` while the repository was being bootstrapped and
then published. That violated the project rule (branch + PR) and left `main`
unprotected. The project needs a predictable workflow for a solo owner with
milestone releases, agent-authored changes and required CI checks.

## Decision

- Use GitFlow:
  - `main`: production/release-only.
  - `develop`: integration branch, created from `main` when this policy landed
    (PR #1 is the adoption change).
  - `feature/<slug>` from `develop` → PR to `develop`.
  - `release/vX.Y.Z` from `develop` → PR to `main`; tag on `main`; back-merge
    `main` into `develop` via a PR.
  - `hotfix/<slug>` from `main` → PR to `main`; tag on `main`; back-merge into
    `develop` via a PR.
- Protect `main` and `develop` on GitHub:
  - pull request required (0 approvals, since the owner is solo);
  - required checks `core (linux)` and `app + gates (macos)`;
  - admins enforced, no force pushes, no deletions;
  - conversation resolution required;
  - `main` additionally requires branches up to date (`strict`); `develop`
    does not.
- Never bypass protection (no admin override, no disabling the rule) to land a
  change. A rejected direct push is the expected, correct outcome.
- Conventional Commits; merge commits preserve history.
- The pre-policy M0 history stays as-is; it is the baseline, not a licence to
  repeat the practice.

## Consequences

- Every change after M0 goes through a branch and a PR with green checks.
- Release and hotfix flows add back-merges between `main` and `develop`.
- Solo PRs can be merged without an approval, but cannot be pushed directly,
  which is exactly the guard the project needs.
- If a required check is flaky or unavailable, fix the check or the workflow;
  do not bypass branch protection.
