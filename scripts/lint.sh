#!/usr/bin/env bash
# make lint: SwiftFormat check + SwiftLint strict.
#
# SwiftLint loads sourcekitd from a full Xcode toolchain. Machines with only
# Command Line Tools use --disable-sourcekit, which skips and reports the few
# rules that need it instead of crashing. CI has Xcode and runs the full set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swiftformat "$ROOT" --lint --config "$ROOT/.swiftformat"

lint_args=(lint --strict --config "$ROOT/.swiftlint.yml")
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "notice: no full Xcode selected; SwiftLint runs with --disable-sourcekit" >&2
    lint_args+=(--disable-sourcekit)
fi

swiftlint "${lint_args[@]}"
