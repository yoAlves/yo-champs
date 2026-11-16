#!/usr/bin/env bash
# make test: run the Swift Testing suites.
#
# Command Line Tools' sourcekitd and libc++ headers are incomplete: the
# toolchain's usr/include/c++/v1 is a stub while the SDK ships the full libc++
# tree. swift-testing's C++ interop needs the real headers, so add the SDK path
# when the toolchain lacks <atomic>. Full Xcode and Linux are untouched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

sdk_path="$(xcrun --show-sdk-path 2>/dev/null || true)"
developer_dir="$(xcode-select -p 2>/dev/null || true)"

if [[ "$developer_dir" == *CommandLineTools* && -n "$sdk_path" \
    && -f "$sdk_path/usr/include/c++/v1/atomic" \
    && ! -f "$developer_dir/usr/include/c++/v1/atomic" ]]; then
    export CPLUS_INCLUDE_PATH="$sdk_path/usr/include/c++/v1${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
fi

exec swift test --package-path "$ROOT"
