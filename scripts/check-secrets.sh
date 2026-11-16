#!/usr/bin/env bash
# make secrets: scan the working tree for committed secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v gitleaks >/dev/null 2>&1; then
    echo "error: gitleaks not found (run make bootstrap)" >&2
    exit 1
fi

if gitleaks version 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "gitleaks $(gitleaks version)"
fi

exec gitleaks detect \
    --source "$ROOT" \
    --config "$ROOT/.gitleaks.toml" \
    --no-git \
    --redact \
    --verbose
