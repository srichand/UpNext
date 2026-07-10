#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/UpNext.xcodeproj"
EXPORT_OPTIONS="$REPO_ROOT/config/ExportOptions-DeveloperID.plist"
WORK_DIR="${WORK_DIR:-/tmp/UpNextDistribution}"
ARCHIVE_PATH="$WORK_DIR/UpNext.xcarchive"
EXPORT_PATH="$WORK_DIR/export"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/artifacts/releases}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-EYVP6WNPPE}"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-Developer ID Application: Srichand Pendyala (EYVP6WNPPE)}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/srichand/UpNext/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY is required for a distributable build" >&2
  exit 2
fi

if [[ "$WORK_DIR" != /tmp/* ]]; then
  echo "WORK_DIR must be inside /tmp: $WORK_DIR" >&2
  exit 2
fi

if ! security find-identity -v -p codesigning | grep -Fq "$DEVELOPER_ID_APPLICATION"; then
  echo "Developer ID signing identity is not installed: $DEVELOPER_ID_APPLICATION" >&2
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$EXPORT_PATH" "$OUTPUT_DIR"

BUILD_SETTINGS=(
  "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
  "CODE_SIGN_STYLE=Manual"
  "CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION"
  "SPARKLE_FEED_URL=$SPARKLE_FEED_URL"
  "SPARKLE_PUBLIC_ED_KEY=$SPARKLE_PUBLIC_ED_KEY"
)

if [[ -n "${MARKETING_VERSION:-}" ]]; then
  BUILD_SETTINGS+=("MARKETING_VERSION=$MARKETING_VERSION")
fi
if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
  BUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION")
fi

echo "Archiving a universal Developer ID build..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme UpNext \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$WORK_DIR/DerivedData" \
  -archivePath "$ARCHIVE_PATH" \
  clean archive \
  "${BUILD_SETTINGS[@]}"

echo "Exporting with Developer ID signing..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH"

APP_PATH="$EXPORT_PATH/UpNext.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Exported app not found: $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

SIGNATURE_INFO="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
if ! grep -Fq "Authority=$DEVELOPER_ID_APPLICATION" <<<"$SIGNATURE_INFO"; then
  echo "Exported app is not signed with the expected Developer ID identity" >&2
  exit 1
fi
if ! grep -Fq "TeamIdentifier=$DEVELOPMENT_TEAM" <<<"$SIGNATURE_INFO"; then
  echo "Exported app has the wrong Developer ID team" >&2
  exit 1
fi
if ! grep -q '^Timestamp=' <<<"$SIGNATURE_INFO"; then
  echo "Exported app does not have a secure signing timestamp" >&2
  exit 1
fi

APP_ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/UpNext")"
if [[ "$APP_ARCHS" != *arm64* || "$APP_ARCHS" != *x86_64* ]]; then
  echo "Expected a universal arm64/x86_64 app, found: $APP_ARCHS" >&2
  exit 1
fi

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Warning: SKIP_NOTARIZATION=1; this archive is not ready for distribution." >&2
else
  NOTARY_ARCHIVE="$WORK_DIR/UpNext-notary.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ARCHIVE"

  echo "Submitting to Apple's notary service..."
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$NOTARY_ARCHIVE" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
  elif [[ -n "${NOTARY_KEY_FILE:-}" && -n "${NOTARY_KEY_ID:-}" ]]; then
    NOTARY_KEY_ARGS=(
      --key "$NOTARY_KEY_FILE"
      --key-id "$NOTARY_KEY_ID"
    )
    if [[ -n "${NOTARY_ISSUER_ID:-}" ]]; then
      NOTARY_KEY_ARGS+=(--issuer "$NOTARY_ISSUER_ID")
    fi
    xcrun notarytool submit "$NOTARY_ARCHIVE" \
      "${NOTARY_KEY_ARGS[@]}" \
      --wait
  else
    echo "Set NOTARY_PROFILE or NOTARY_KEY_FILE/NOTARY_KEY_ID (and NOTARY_ISSUER_ID for team keys)" >&2
    exit 2
  fi

  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
fi

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
FINAL_ARCHIVE="$OUTPUT_DIR/UpNext-$SHORT_VERSION.zip"

"$REPO_ROOT/scripts/build-update-archive.sh" "$APP_PATH" "$FINAL_ARCHIVE"
"$REPO_ROOT/scripts/generate-homebrew-cask.sh" \
  "$FINAL_ARCHIVE" \
  "$SHORT_VERSION" \
  "$OUTPUT_DIR/upnext.rb"

echo "Distribution archive: $FINAL_ARCHIVE"
echo "Homebrew Cask: $OUTPUT_DIR/upnext.rb"
