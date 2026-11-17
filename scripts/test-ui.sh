#!/usr/bin/env bash
# make test-ui: run the M3 XCUITest critical flow.
#
# Standalone local gate in M3: intentionally not part of make verify/ci.
# The Xcode project is committed, so no generator is needed at test time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

exec xcodebuild test \
    -project YoChamps.xcodeproj \
    -scheme YoChampsUITests \
    -destination 'platform=macOS'
