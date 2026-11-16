#!/usr/bin/env bash
# make doctor: report versions, paths, config, Keychain and app state.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
warnings=0

pass() { printf 'ok    %s\n' "$1"; }
warn() { printf 'warn  %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

version_major="$(sw_vers -productVersion | cut -d. -f1)"
if ((version_major >= 14)); then
    pass "macOS $(sw_vers -productVersion) (>= 14)"
else
    fail "macOS $(sw_vers -productVersion) is below the 14.0 minimum"
fi

arch="$(uname -m)"
if [[ "$arch" == "arm64" ]]; then
    pass "arch arm64"
else
    warn "arch $arch (Apple Silicon is the V0 target)"
fi

if command -v swift >/dev/null 2>&1; then
    pass "swift: $(swift --version 2>/dev/null | head -n 1)"
else
    fail "swift not found"
fi

dev_dir="$(xcode-select -p 2>/dev/null || echo none)"
if xcodebuild -version >/dev/null 2>&1; then
    pass "xcodebuild: $(xcodebuild -version | head -n 1) ($dev_dir)"
else
    warn "xcodebuild unavailable ($dev_dir); XCUITest needs full Xcode"
fi

for tool in swiftlint swiftformat gitleaks; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "$tool: $("$tool" --version 2>/dev/null | head -n 1)"
    else
        fail "$tool not found (run make bootstrap)"
    fi
done

if swift package --package-path "$ROOT" describe >/dev/null 2>&1; then
    pass "Package.swift parses"
else
    fail "Package.swift does not parse"
fi

config_dir="$HOME/Library/Application Support/YoChamps"
mascots_dir="$config_dir/Mascots"
installed_app="$HOME/Applications/YoChamps.app"

[[ -d "$config_dir" ]] && pass "config dir: $config_dir" || warn "config dir missing: $config_dir (created on first launch)"
[[ -d "$mascots_dir" ]] && pass "mascots dir: $mascots_dir" || warn "mascots dir missing: $mascots_dir (created on first launch)"
[[ -d "$installed_app" ]] && pass "installed app: $installed_app" || warn "installed app missing: $installed_app (run make deploy)"

if security find-generic-password -s "com.yurioliveira.yochamps" >/dev/null 2>&1; then
    pass "Keychain item present for com.yurioliveira.yochamps"
else
    warn "no Keychain item yet (expected until M2)"
fi

if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "git repository"
else
    warn "not a git repository yet"
fi

echo
echo "doctor: $failures failure(s), $warnings warning(s)"
((failures == 0))
