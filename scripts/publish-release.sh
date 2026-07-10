#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/UpNext.xcodeproj"
REPOSITORY="${GITHUB_REPOSITORY:-srichand/UpNext}"
NOTARY_PROFILE="${NOTARY_PROFILE:-UpNext}"
SPARKLE_KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-upnext}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-2GV/w+t67iwrxKwZDJkIQpO2aYTAI2p/P+MSahQuHR4=}"

if [[ "$(git -C "$REPO_ROOT" branch --show-current)" != "main" ]]; then
  echo "Releases must be cut from main" >&2
  exit 1
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "The worktree must be clean before publishing a release" >&2
  exit 1
fi

MARKETING_VERSION="$(
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme UpNext \
    -configuration Release \
    -showBuildSettings 2>/dev/null \
    | awk '/ MARKETING_VERSION = / { print $3; exit }'
)"
BUILD_VERSION="$(
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme UpNext \
    -configuration Release \
    -showBuildSettings 2>/dev/null \
    | awk '/ CURRENT_PROJECT_VERSION = / { print $3; exit }'
)"

if [[ -z "$MARKETING_VERSION" || -z "$BUILD_VERSION" ]]; then
  echo "Could not resolve the app version from Xcode build settings" >&2
  exit 1
fi

TAG="v$MARKETING_VERSION"
NOTES_PATH="${RELEASE_NOTES_PATH:-$REPO_ROOT/release-notes/UpNext-$MARKETING_VERSION.md}"
RELEASE_ROOT="${RELEASE_ROOT:-/tmp/UpNextRelease-$MARKETING_VERSION}"
ASSET_DIR="$RELEASE_ROOT/assets"

if [[ "$RELEASE_ROOT" != /tmp/* ]]; then
  echo "RELEASE_ROOT must be inside /tmp: $RELEASE_ROOT" >&2
  exit 2
fi

if [[ ! -s "$NOTES_PATH" ]]; then
  echo "Release notes not found: $NOTES_PATH" >&2
  exit 1
fi

for command in gh jq swift xcodebuild xcrun; do
  if ! command -v "$command" >/dev/null; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

git -C "$REPO_ROOT" fetch origin main
LOCAL_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD)"
REMOTE_HEAD="$(git -C "$REPO_ROOT" rev-parse origin/main)"
if [[ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
  echo "Local main must exactly match origin/main before publishing" >&2
  exit 1
fi

if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  echo "GitHub release already exists: $TAG" >&2
  exit 1
fi

if git -C "$REPO_ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
  if [[ "$(git -C "$REPO_ROOT" rev-list -n 1 "$TAG")" != "$LOCAL_HEAD" ]]; then
    echo "Existing local tag $TAG does not point to HEAD" >&2
    exit 1
  fi
else
  git -C "$REPO_ROOT" tag -a "$TAG" -m "UpNext $MARKETING_VERSION"
fi

rm -rf "$RELEASE_ROOT"
mkdir -p "$ASSET_DIR"

echo "Running SwiftPM tests..."
swift test --package-path "$REPO_ROOT" --scratch-path "$RELEASE_ROOT/SwiftPM"

echo "Running Xcode tests..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme UpNext \
  -configuration Debug \
  -derivedDataPath "$RELEASE_ROOT/XcodeTests" \
  test

echo "Building, notarizing, and packaging UpNext $MARKETING_VERSION ($BUILD_VERSION)..."
WORK_DIR="$RELEASE_ROOT/distribution" \
OUTPUT_DIR="$ASSET_DIR" \
NOTARY_PROFILE="$NOTARY_PROFILE" \
SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
"$REPO_ROOT/scripts/build-distribution.sh"

cp "$NOTES_PATH" "$ASSET_DIR/UpNext-$MARKETING_VERSION.md"

LATEST_TAG="$(
  gh release list \
    --repo "$REPOSITORY" \
    --limit 100 \
    --json tagName,isDraft,isPrerelease \
    --jq '[.[] | select(.isDraft == false and .isPrerelease == false)][0].tagName // ""'
)"
if [[ -n "$LATEST_TAG" ]]; then
  gh release download "$LATEST_TAG" \
    --repo "$REPOSITORY" \
    --pattern appcast.xml \
    --dir "$ASSET_DIR"
fi

"$REPO_ROOT/scripts/generate-appcast.sh" \
  --archives-dir "$ASSET_DIR" \
  --download-url-prefix \
    "https://github.com/$REPOSITORY/releases/download/$TAG/" \
  --keychain-account "$SPARKLE_KEYCHAIN_ACCOUNT"

for asset in \
  "$ASSET_DIR/UpNext-$MARKETING_VERSION.zip" \
  "$ASSET_DIR/UpNext-$MARKETING_VERSION.md" \
  "$ASSET_DIR/appcast.xml" \
  "$ASSET_DIR/upnext.rb"; do
  if [[ ! -s "$asset" ]]; then
    echo "Missing release asset: $asset" >&2
    exit 1
  fi
done

if ! grep -Fq \
  "https://github.com/$REPOSITORY/releases/download/$TAG/UpNext-$MARKETING_VERSION.zip" \
  "$ASSET_DIR/appcast.xml"; then
  echo "The generated appcast does not reference the expected archive" >&2
  exit 1
fi

if ! grep -Fq 'sparkle-signatures:' "$ASSET_DIR/appcast.xml"; then
  echo "The generated appcast is not signed" >&2
  exit 1
fi

git -C "$REPO_ROOT" push origin "$TAG"

gh release create "$TAG" \
  --repo "$REPOSITORY" \
  --verify-tag \
  --draft \
  --title "UpNext $MARKETING_VERSION" \
  --notes-file "$NOTES_PATH" \
  "$ASSET_DIR/UpNext-$MARKETING_VERSION.zip" \
  "$ASSET_DIR/UpNext-$MARKETING_VERSION.md" \
  "$ASSET_DIR/appcast.xml" \
  "$ASSET_DIR/upnext.rb"

echo "Created draft release $TAG from $LOCAL_HEAD"
echo "Assets: $ASSET_DIR"
echo "Review and publish with: gh release edit $TAG --repo $REPOSITORY --draft=false --latest"
