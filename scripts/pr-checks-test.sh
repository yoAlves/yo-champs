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
            hang) exec sleep 600 ;;
            fail) echo "core (linux) fail 1m"; exit 1 ;;
            pass) echo "core (linux) pass 1m"; exit 0 ;;
            esac
        else
            [[ -n "${FAKE_NO_CHECKS:-}" ]] && exit 8
            echo "core (linux) pending 0"
        fi
        ;;
esac
EOF
chmod +x "$tmp/gh"

failures=0

expect() { # name expected_exit command...
    local name="$1" expected="$2"
    shift 2
    local out status
    # Bound every case so a fixture bug cannot hang the suite.
    out="$(PATH="$tmp:$PATH" perl -e 'alarm shift; exec @ARGV' 120 "$@" 2>&1)"
    status=$?
    if [ "$status" -ne "$expected" ]; then
        echo "FAIL $name: expected exit $expected, got $status"
        echo "$out"
        failures=$((failures + 1))
        return
    fi
    echo "ok   $name (exit $status)"
}

expect "all checks pass" 0 env FAKE_WATCH=pass "$ROOT/scripts/pr-checks.sh" 7 30
expect "a check fails" 1 env FAKE_WATCH=fail "$ROOT/scripts/pr-checks.sh" 7 30
expect "watch times out" 8 env FAKE_WATCH=hang "$ROOT/scripts/pr-checks.sh" 7 1
expect "no checks registered" 8 env FAKE_NO_CHECKS=1 PR_CHECKS_REGISTER_TIMEOUT=2 \
    "$ROOT/scripts/pr-checks.sh" 7 30
expect "PR not found" 1 env FAKE_VIEW_EXIT=1 "$ROOT/scripts/pr-checks.sh" 7 30
expect "PR number must be positive" 1 "$ROOT/scripts/pr-checks.sh" 0 30
expect "timeout must be positive" 1 "$ROOT/scripts/pr-checks.sh" 7 0

if [ "$failures" -ne 0 ]; then
    echo "pr-checks-test: $failures failure(s)"
    exit 1
fi
echo "pr-checks-test: ok"
