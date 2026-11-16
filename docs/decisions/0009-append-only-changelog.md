# ADR 0009 — Append-only changelog with union merge

**Status:** accepted (2026-11-16).
**Covers:** D26 — changelog discipline and release notes.

## Context

Parallel branches and PRs often add entries to `CHANGELOG.md` under the same
`## [Unreleased]` heading. A normal three-way merge reports a conflict even
though both changes are purely additive, and resolving it by hand risks losing
an entry.

## Decision

- `CHANGELOG.md` is append-only: new bullets go under `## [Unreleased]`;
  released sections are immutable.
- `.gitattributes` sets `/CHANGELOG.md merge=union`, using git's built-in union
  merge driver. When both sides add lines, the merge keeps both instead of
  conflicting.
- After a union merge, review ordering/duplicates by hand and never drop an
  entry that landed elsewhere.
- Cutting a release is the only rewrite: move entries into a new
  `## [x.y.z] - YYYY-MM-DD` section, add its link reference, update the
  `[Unreleased]` compare link to the new tag and leave `## [Unreleased]` empty.
  Do the cut on a `release/vX.Y.Z` branch cut from `main` (or the PR branch doing
  the cut), with no open or in-flight changelog branches, and verify the result
  after merging.
- The driver is local/merge-time only; GitHub/GitLab web merges may ignore it,
  so the append-only convention is the real guarantee.

## Consequences

- Additive changelog changes merge cleanly and preserve both entries.
- Around a release cut, union merges can glue an adjacent new bullet into the
  newly released section or drop the blank line before its heading. The cut is
  therefore a separate, reviewed change, and the merged file is inspected for:
  entry in the right section, one blank line before the new heading, and the
  link reference present. If the check fails, move the bullet back under
  `[Unreleased]`, restore the blank line, and update the compare link in a
  follow-up commit; never rewrite a released section's history.
- Union merges can interleave ordering or duplicate a blank line; the manual
  check handles that.
- The driver must not be used for code or prose where context matters; it is
  scoped to `CHANGELOG.md` only.
