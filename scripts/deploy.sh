#!/usr/bin/env bash
# make deploy: local-only release install. No signing, notarization or publish.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/YoChamps.app"

BUNDLE="$("$ROOT/scripts/bundle.sh" release | tail -n 1)"

"$ROOT/scripts/stop.sh"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$BUNDLE" "$INSTALLED_APP"
open "$INSTALLED_APP"

echo "installed: $INSTALLED_APP"
echo "note: local build only — unsigned, not notarized, not published"
