#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build.sh "${1:-Release}"

pkill -x ExpoTools >/dev/null 2>&1 || true
open dist/ExpoTools.app

echo "==> Expo Tools is running in the menu bar (look for the hammer icon)"
