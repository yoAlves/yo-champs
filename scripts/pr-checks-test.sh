#!/usr/bin/env bash
# Deterministic checks for scripts/pr-checks.sh using a fake `gh` on PATH.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "pr view") exit "${FAKE_VIEW_EXIT:-0}" ;;
    "pr checks")
        if [[ " $* " == *" --watch "* ]]; then
            case "${FAKE_WATCH:-pass}" in
            hang) exec sleep 30 ;;
            fail)
                echo fail >"${FAKE_STATE:?}"
                echo "core (linux) fail 1m"
                exit 1
                ;;
            pass)
                echo pass >"${FAKE_STATE:?}"
                echo "core (linux) pass 1m"
                exit 0
                ;;
            esac
        elif [[ -n "${FAKE_NO_CHECKS:-}" ]]; then
            exit 8
        else
            state="$(cat "${FAKE_STATE:-/dev/null}" 2>/dev/null || true)"
            echo "core (linux) ${state:-pending} 1m"
        fi
        ;;
esac
EOF
chmod +x "$tmp/gh"

failures=0

expect() { # name expected_exit expected_pattern command...
    local name="$1" expected="$2" pattern="$3"
    shift 3
    local out status
    rm -f "$tmp/state"
    # Bound every case so a fixture bug cannot hang the suite.
    out="$(PATH="$tmp:$PATH" perl -e 'alarm shift; exec @ARGV or die "pr-checks-test: cannot exec $ARGV[0]: $!\n"' 120 "$@" 2>&1)"
    status=$?
    if [ "$status" -ne "$expected" ]; then
        echo "FAIL $name: expected exit $expected, got $status"
        echo "$out"
        failures=$((failures + 1))
        return
    fi
    if [ -n "$pattern" ] && [[ "$out" != *"$pattern"* ]]; then
        echo "FAIL $name: output does not contain '$pattern'"
        echo "$out"
        failures=$((failures + 1))
        return
    fi
    echo "ok   $name (exit $status)"
}

expect "all checks pass" 0 "core (linux) pass" \
    env FAKE_STATE="$tmp/state" FAKE_WATCH=pass "$ROOT/scripts/pr-checks.sh" 7 30
expect "a check fails" 1 "checks failed" \
    env FAKE_STATE="$tmp/state" FAKE_WATCH=fail "$ROOT/scripts/pr-checks.sh" 7 30
expect "watch times out" 8 "timed out after" \
    env FAKE_STATE="$tmp/state" FAKE_WATCH=hang "$ROOT/scripts/pr-checks.sh" 7 1
expect "no checks registered" 8 "no checks registered" \
    env FAKE_NO_CHECKS=1 PR_CHECKS_REGISTER_TIMEOUT=2 "$ROOT/scripts/pr-checks.sh" 7 30
expect "PR not found" 1 "not found" \
    env FAKE_VIEW_EXIT=1 "$ROOT/scripts/pr-checks.sh" 7 30
expect "PR number must be positive" 1 "positive integer" \
    "$ROOT/scripts/pr-checks.sh" 0 30
expect "timeout must be positive" 1 "positive integer" \
    "$ROOT/scripts/pr-checks.sh" 7 0
expect "registration budget must be positive" 1 "positive integer" \
    env PR_CHECKS_REGISTER_TIMEOUT=abc "$ROOT/scripts/pr-checks.sh" 7 30

start=$SECONDS
expect "PR not found fails fast" 1 "not found" \
    env FAKE_VIEW_EXIT=1 "$ROOT/scripts/pr-checks.sh" 7 30
if [ $((SECONDS - start)) -ge 5 ]; then
    echo "FAIL PR not found fails fast: took $((SECONDS - start))s"
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    echo "pr-checks-test: $failures failure(s)"
    exit 1
fi
echo "pr-checks-test: ok"
