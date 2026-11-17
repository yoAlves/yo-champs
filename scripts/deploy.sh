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

# A launch that exits immediately is a failed deploy (e.g. a missing SwiftPM
# resource bundle). Do not report success in that case.
sleep 2
if ! pgrep -f "$INSTALLED_APP/Contents/MacOS/YoChamps" >/dev/null; then
    echo "error: YoChamps exited immediately after launch; check ~/Library/Logs/DiagnosticReports" >&2
    exit 1
fi

echo "installed: $INSTALLED_APP"
echo "note: local build only — unsigned, not notarized, not published"
