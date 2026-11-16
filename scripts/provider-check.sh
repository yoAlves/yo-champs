#!/usr/bin/env bash
# Integration check: run the real streaming client against a local SSE stub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in python3 curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "provider-check: $tool is required for the local SSE stub" >&2
        exit 1
    fi
done

PORT_FILE="$(mktemp)"
ERR_FILE="$(mktemp)"
python3 -u "$ROOT/scripts/provider-stub.py" >"$PORT_FILE" 2>"$ERR_FILE" &
STUB_PID=$!
cleanup() {
    kill "$STUB_PID" 2>/dev/null || true
    wait "$STUB_PID" 2>/dev/null || true
    rm -f "$PORT_FILE" "$ERR_FILE"
}
trap cleanup EXIT

# CI runners can take several seconds to start python3; 30s avoids a false
# failure while a swift/xcode shim warms up.
PORT=""
for _ in $(seq 1 300); do
    if [[ -s "$PORT_FILE" ]]; then
        PORT="$(head -n 1 "$PORT_FILE")"
        break
    fi
    if ! kill -0 "$STUB_PID" 2>/dev/null; then
        echo "provider-check: stub exited before printing a port" >&2
        cat "$ERR_FILE" >&2
        exit 1
    fi
    sleep 0.1
done
if [[ -z "$PORT" ]]; then
    echo "provider-check: stub did not start within 30s" >&2
    cat "$ERR_FILE" >&2
    exit 1
fi

# The port line is printed before the socket listens; wait for readiness.
READY=0
for _ in $(seq 1 100); do
    if curl -sS -o /dev/null --max-time 1 -X POST \
        "http://127.0.0.1:${PORT}/v1/chat/completions" \
        -H 'Content-Type: application/json' -d '{"stream":false}' 2>/dev/null; then
        READY=1
        break
    fi
    sleep 0.1
done
if [[ "$READY" -eq 0 ]]; then
    echo "provider-check: stub port ${PORT} never became ready" >&2
    cat "$ERR_FILE" >&2
    exit 1
fi

swift run --package-path "$ROOT" YoChampsProviderCheck --url "http://127.0.0.1:${PORT}/v1"
echo "provider-check: OK"
