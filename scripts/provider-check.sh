#!/usr/bin/env bash
# Integration check: run the real streaming client against a local SSE stub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT_FILE="$(mktemp)"
python3 "$ROOT/scripts/provider-stub.py" >"$PORT_FILE" &
STUB_PID=$!
trap 'kill "$STUB_PID" 2>/dev/null || true; wait "$STUB_PID" 2>/dev/null || true; rm -f "$PORT_FILE"' EXIT

for _ in $(seq 1 50); do
    [[ -s "$PORT_FILE" ]] && break
    sleep 0.1
done
PORT="$(head -n 1 "$PORT_FILE")"
if [[ -z "$PORT" ]]; then
    echo "provider-check: stub did not start" >&2
    exit 1
fi

swift run --package-path "$ROOT" YoChampsProviderCheck --url "http://127.0.0.1:${PORT}/v1"
echo "provider-check: OK"
