# ADR 0011 — PR to main only (no develop)

**Status:** accepted (2026-11-16). Supersedes [ADR 0010](0010-gitflow-protected-branches.md).
**Covers:** D28 — branch model and merge gate.

## Context

ADR 0010 adopted GitFlow with `main` + `develop` + release/hotfix back-merges.
This is a local, solo V0 project; `develop` adds a second protected branch and
back-merges without adding review capacity. The real safety gate is CI plus
branch protection, not the number of long-lived branches. `develop` was created,
then removed before M1.

## Decision

- `main` is the only long-lived branch.
- Protect `main` on GitHub:
  - pull request required (0 approvals, solo owner);
  - required checks `core (linux)` and `app + gates (macos)`;
  - branches must be up to date (`strict`);
  - admins enforced, no force pushes, no deletions, conversation resolution.
- Work on short-lived branches from `main` with a typed prefix:
  `feature/<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`, `ci/<slug>`.
- Open a PR into `main`, wait for both checks, merge with a merge commit.
- Releases are `vX.Y.Z` tags on `main`; a one-off `release/vX.Y.Z` branch may
  carry the changelog cut through a PR.
- No `develop` and no long-lived release branches in V0. Reintroduce GitFlow only
  if the project gains collaborators or parallel release trains.

## Consequences

- One integration branch and no back-merges; every change is a PR with green
  checks.
- Branch protection makes direct pushes fail (`GH006`), including for the owner.
- CI capacity/queue is the merge bottleneck; a flaky runner is fixed or rerun,
  never bypassed.
- The M0 history predates this policy and remains the baseline.
