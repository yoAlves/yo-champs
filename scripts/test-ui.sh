#!/usr/bin/env bash
# make test-ui: run the V0 XCUITest critical flow.
#
# Standalone local gate: intentionally not part of make verify/ci. Stop any
# installed instance first (`make stop`): the suite is order-sensitive and a
# second app with the same bundle id confuses the status-item/hotkey cases.
# The Xcode project is committed, so no generator is needed at test time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

exec xcodebuild test \
    -project YoChamps.xcodeproj \
    -scheme YoChampsUITests \
    -destination 'platform=macOS'
