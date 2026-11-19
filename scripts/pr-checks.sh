#!/usr/bin/env bash
# Wait for a pull request's checks to finish.
#
# Usage: scripts/pr-checks.sh <pr-number> [timeout-seconds]
#
# Exit codes:
#   0  every check passed
#   1  a check failed, the PR does not exist, or gh is not authenticated
#   8  still pending when a timeout expired (registration, watch or query)
#
# Bounds:
#   - up to 120s waiting for GitHub to register the checks after a push
#     (`PR_CHECKS_REGISTER_TIMEOUT` overrides it; the test suite uses that);
#   - `timeout-seconds` (default 2400) for the watch itself;
#   - 30s per probe and 60s per table query, so a stalled connection cannot
#     defeat the deadline.
#
# Why not `gh pr checks --watch` alone:
# - right after a push GitHub has not registered the checks yet and the watch
#   exits with "no checks reported", so we wait for the first check to appear;
# - `--watch` blocks forever if a runner hangs, and macOS has no `timeout`, so
#   every gh call is bounded with perl's alarm (ITIMER_REAL survives exec).
set -euo pipefail

PR="${1:?usage: scripts/pr-checks.sh <pr-number> [timeout-seconds]}"
TIMEOUT="${2:-2400}"
REGISTER_TIMEOUT="${PR_CHECKS_REGISTER_TIMEOUT:-120}"
PROBE_TIMEOUT=30
TABLE_TIMEOUT=60

for tool in gh perl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "pr-checks: $tool is required" >&2
        exit 1
    fi
done

for value in "$PR" "$TIMEOUT" "$REGISTER_TIMEOUT"; do
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "pr-checks: expected a positive integer, got '$value'" >&2
        exit 1
    fi
done

gh_bounded() { # seconds gh-args...
    local seconds="$1"
    shift
    perl -e 'alarm shift; exec @ARGV or die "pr-checks: cannot exec $ARGV[0]: $!\n"' "$seconds" gh "$@"
}

set +e
gh_bounded "$PROBE_TIMEOUT" pr view "$PR" >/dev/null 2>&1
precheck=$?
set -e
case "$precheck" in
0) ;;
142)
    echo "pr-checks: timed out checking PR $PR" >&2
    exit 8
    ;;
*)
    echo "pr-checks: PR $PR not found (or gh is not authenticated)" >&2
    exit 1
    ;;
esac

deadline=$(( $(date +%s) + REGISTER_TIMEOUT ))
while :; do
    first="$(gh_bounded "$PROBE_TIMEOUT" pr checks "$PR" 2>/dev/null | head -1)" || true
    if [ -n "$first" ]; then
        break
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "pr-checks: no checks registered for PR $PR after ${REGISTER_TIMEOUT}s" >&2
        exit 8
    fi
    sleep 5
done

set +e
# `--watch` reprints the table on every poll; keep only the final one below.
gh_bounded "$TIMEOUT" pr checks "$PR" --watch --fail-fast --interval 15 >/dev/null 2>&1
status=$?
set -e

case "$status" in
0)
    gh_bounded "$TABLE_TIMEOUT" pr checks "$PR" || true
    ;;
142)
    echo "pr-checks: timed out after ${TIMEOUT}s waiting for PR $PR" >&2
    gh_bounded "$TABLE_TIMEOUT" pr checks "$PR" || true
    exit 8
    ;;
130 | 143)
    echo "pr-checks: interrupted while waiting for PR $PR" >&2
    exit 8
    ;;
*)
    echo "pr-checks: checks failed (exit $status) on PR $PR" >&2
    gh_bounded "$TABLE_TIMEOUT" pr checks "$PR" || true
    exit 1
    ;;
esac
