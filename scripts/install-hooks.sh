#!/usr/bin/env bash
# make install-hooks: pre-commit gate for secrets and lint.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: $ROOT is not a git repository" >&2
    exit 1
fi

hook_path="$(git -C "$ROOT" rev-parse --git-path hooks)/pre-commit"
cat >"$hook_path" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if command -v gitleaks >/dev/null 2>&1; then
    gitleaks git --staged --redact --config "$ROOT/.gitleaks.toml"
else
    echo "pre-commit: gitleaks missing; run make bootstrap" >&2
    exit 1
fi

make lint
HOOK
chmod +x "$hook_path"
echo "installed: $hook_path"
