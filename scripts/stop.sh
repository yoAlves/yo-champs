#!/usr/bin/env bash
# Stops any running YoChamps process (installed or .build bundle).
set -euo pipefail

pkill -x YoChamps 2>/dev/null || true
echo "stopped YoChamps (if it was running)"
