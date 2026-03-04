#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/UpNext.xcodeproj"
SCHEME="UpNext"
DERIVED_DATA_PATH="/tmp/UpNextRelease"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/UpNext.app"
TARGET_APP_PATH="$HOME/Applications/UpNext.app"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found at $PROJECT_PATH" >&2
  exit 1
fi

echo "Building Release app..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build

echo "Installing to $TARGET_APP_PATH..."
mkdir -p "$HOME/Applications"
rm -rf "$TARGET_APP_PATH"
cp -R "$BUILT_APP_PATH" "$TARGET_APP_PATH"

echo "Done. Installed: $TARGET_APP_PATH"
