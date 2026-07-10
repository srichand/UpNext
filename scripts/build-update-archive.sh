#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-$HOME/Applications/UpNext.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH" >&2
  echo "Install a Release build first with ./scripts/release.sh" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
OUTPUT_PATH="${2:-$PWD/artifacts/releases/UpNext-$SHORT_VERSION.zip}"

codesign --verify --deep --strict "$APP_PATH"

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

echo "Packaging Sparkle update archive from $APP_PATH..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_PATH"

echo "Created update archive: $OUTPUT_PATH"
echo "SHA-256: $(shasum -a 256 "$OUTPUT_PATH" | awk '{print $1}')"
