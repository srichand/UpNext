#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/UpNext.xcodeproj"
SCHEME="UpNext"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/UpNextScreenshotsDerived}"
TEST_IDENTIFIER="UpNextTests/ScreenshotGenerationTests/testGenerateMenuBarPopoverScreenshots"
OUTPUT_DIR="${1:-$REPO_ROOT/artifacts/screenshots}"
RESULT_BUNDLE_PATH="$DERIVED_DATA_PATH/ScreenshotTests.xcresult"
EXPORT_DIR="$DERIVED_DATA_PATH/ScreenshotAttachments"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found at $PROJECT_PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/popover-*.png
rm -rf "$RESULT_BUNDLE_PATH" "$EXPORT_DIR"

echo "Generating screenshots..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -only-testing:"$TEST_IDENTIFIER" \
  test

echo "Exporting screenshot attachments..."
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE_PATH" \
  --output-path "$EXPORT_DIR"

MANIFEST_PATH="$EXPORT_DIR/manifest.json"
if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Attachment manifest not found at $MANIFEST_PATH" >&2
  exit 1
fi

COPIED_COUNT=0
while IFS=$'\t' read -r exported_file suggested_name; do
  [[ -n "$exported_file" && -n "$suggested_name" ]] || continue

  stable_name="$(echo "$suggested_name" | sed -E 's/_0_[0-9A-F-]+\.png$/.png/')"
  if [[ "$stable_name" != popover-*.png ]]; then
    continue
  fi

  cp "$EXPORT_DIR/$exported_file" "$OUTPUT_DIR/$stable_name"
  COPIED_COUNT=$((COPIED_COUNT + 1))
done < <(jq -r '.[]?.attachments[]? | [.exportedFileName, .suggestedHumanReadableName] | @tsv' "$MANIFEST_PATH")

if [[ "$COPIED_COUNT" -eq 0 ]]; then
  echo "No popover screenshots were copied from $MANIFEST_PATH" >&2
  exit 1
fi

echo "Screenshots written to $OUTPUT_DIR:"
ls -1 "$OUTPUT_DIR"/popover-*.png
