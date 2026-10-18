#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required: brew install xcodegen" >&2
  exit 1
fi

CONFIGURATION="${1:-Release}"
DERIVED_DATA=".build/DerivedData"

echo "==> Generating Xcode project"
xcodegen generate --spec project.yml --quiet

echo "==> Building ($CONFIGURATION)"
xcodebuild \
  -project ExpoTools.xcodeproj \
  -scheme ExpoTools \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -n 5

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/ExpoTools.app"

echo "==> Packaging"
mkdir -p dist
rm -rf dist/ExpoTools.app
cp -R "$APP_PATH" dist/
codesign --force --deep --sign - dist/ExpoTools.app >/dev/null 2>&1 || true

echo "==> Built dist/ExpoTools.app"
