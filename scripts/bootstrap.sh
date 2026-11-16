#!/usr/bin/env bash
# make bootstrap: install/verify dev tools and resolve Swift packages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
    echo "error: Homebrew is required (https://brew.sh)" >&2
    exit 1
fi

missing=()
for formula in swiftlint swiftformat gitleaks; do
    if ! brew list --formula "$formula" >/dev/null 2>&1; then
        missing+=("$formula")
    fi
done

if ((${#missing[@]} > 0)); then
    echo "installing: ${missing[*]}"
    brew install "${missing[@]}"
fi

echo "resolving Swift packages"
swift package --package-path "$ROOT" resolve

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    echo "notice: full Xcode not selected (xcrun --select)."
    echo "        M0 builds with Command Line Tools; XCUITest (make test-ui) needs Xcode."
fi

echo "bootstrap: ok"
