#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/UpNext.xcodeproj"
SCHEME="UpNext"
DERIVED_DATA_PATH="/tmp/UpNextRelease"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/UpNext.app"
TARGET_APP_PATH="$HOME/Applications/UpNext.app"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-EYVP6WNPPE}"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-Developer ID Application: Srichand Pendyala (EYVP6WNPPE)}"
BUILD_SETTINGS=(
  "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
  "CODE_SIGN_STYLE=Manual"
  "CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION"
)

if [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  BUILD_SETTINGS+=("SPARKLE_PUBLIC_ED_KEY=$SPARKLE_PUBLIC_ED_KEY")
fi

if [[ -n "${SPARKLE_FEED_URL:-}" ]]; then
  BUILD_SETTINGS+=("SPARKLE_FEED_URL=$SPARKLE_FEED_URL")
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found at $PROJECT_PATH" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "$DEVELOPER_ID_APPLICATION"; then
  echo "Developer ID signing identity is not installed: $DEVELOPER_ID_APPLICATION" >&2
  exit 1
fi

echo "Building Release app..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build \
  "${BUILD_SETTINGS[@]}"

echo "Applying a timestamped Developer ID signature..."
codesign \
  --force \
  --deep \
  --sign "$DEVELOPER_ID_APPLICATION" \
  --timestamp \
  --options runtime \
  --preserve-metadata=identifier,entitlements,requirements,flags,runtime \
  "$BUILT_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$BUILT_APP_PATH"

echo "Installing to $TARGET_APP_PATH..."
mkdir -p "$HOME/Applications"
rm -rf "$TARGET_APP_PATH"
cp -R "$BUILT_APP_PATH" "$TARGET_APP_PATH"

echo "Done. Installed: $TARGET_APP_PATH"
