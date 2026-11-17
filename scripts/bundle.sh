#!/usr/bin/env bash
# Builds YoChampsMac and assembles a minimal .app bundle.
# Usage: scripts/bundle.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT/.build/YoChamps.app"

swift build --package-path "$ROOT" -c "$CONFIG" --product YoChampsMac
BIN_DIR="$(swift build --package-path "$ROOT" -c "$CONFIG" --show-bin-path)"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$ROOT/App/Info.plist" "$BUNDLE/Contents/Info.plist"
cp "$BIN_DIR/YoChampsMac" "$BUNDLE/Contents/MacOS/YoChamps"

# The loader resolves the default pack from Bundle.main.resourceURL, i.e.
# Contents/Resources in the bundle. Ship it there so bundled launches find
# Champ without relying on the cwd-relative debug fallback.
mkdir -p "$BUNDLE/Contents/Resources/Mascots"
cp -R "$ROOT/Resources/Mascots/Default" "$BUNDLE/Contents/Resources/Mascots/Default"

# Local ad-hoc signature: enough for local launch, not for distribution.
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || {
    echo "warn: ad-hoc codesign failed; bundle will still run locally" >&2
}

echo "$BUNDLE"
