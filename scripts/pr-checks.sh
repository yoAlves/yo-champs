#!/usr/bin/env bash
# Wait for a pull request's checks to finish.
#
# Usage: scripts/pr-checks.sh <pr-number> [timeout-seconds]
#
# Exit codes:
#   0  every check passed
#   1  a check failed (or the PR does not exist / gh is not authenticated)
#   8  still pending when the timeout expired, or no check was ever registered
#
# Why not `gh pr checks --watch` alone:
# - right after a push GitHub has not registered the checks yet and the watch
#   exits with "no checks reported", so we wait for the first check to appear;
# - `--watch` blocks forever if a runner hangs, and macOS has no `timeout`, so
#   the wait is bounded with perl's alarm.
set -euo pipefail

PR="${1:?usage: scripts/pr-checks.sh <pr-number> [timeout-seconds]}"
TIMEOUT="${2:-2400}"
REGISTER_TIMEOUT="${PR_CHECKS_REGISTER_TIMEOUT:-120}"

if ! [[ "$PR" =~ ^[1-9][0-9]*$ ]]; then
    echo "pr-checks: the PR number must be a positive integer, got '$PR'" >&2
    exit 1
fi
if ! [[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
    echo "pr-checks: the timeout must be a positive integer, got '$TIMEOUT'" >&2
    exit 1
fi

# `gh pr view <n> --json number` synthesizes a stub for a missing PR (gh 2.87),
# so the plain form is the one that actually fails on "not found".
gh pr view "$PR" >/dev/null 2>&1 || {
    echo "pr-checks: PR $PR not found (or gh is not authenticated)" >&2
    exit 1
}

deadline=$(( $(date +%s) + REGISTER_TIMEOUT ))
until [ -n "$(gh pr checks "$PR" 2>/dev/null | head -1)" ]; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "pr-checks: no checks registered for PR $PR after ${REGISTER_TIMEOUT}s" >&2
        exit 8
    fi
    sleep 5
done

set +e
# `--watch` reprints the table on every poll; keep only the final one below.
perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" \
    gh pr checks "$PR" --watch --fail-fast --interval 15 >/dev/null
status=$?
set -e

case "$status" in
0)
    gh pr checks "$PR" || true
    ;;
142)
    echo "pr-checks: timed out after ${TIMEOUT}s waiting for PR $PR" >&2
    gh pr checks "$PR" || true
    exit 8
    ;;
*)
    echo "pr-checks: checks failed (exit $status) on PR $PR" >&2
    gh pr checks "$PR" || true
    exit "$status"
    ;;
esac
