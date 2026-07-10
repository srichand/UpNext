#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVES_DIR="$REPO_ROOT/artifacts/releases"
DOWNLOAD_URL_PREFIX=""
RELEASE_NOTES_URL_PREFIX=""
PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_ED_KEY_FILE:-}"
KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-upnext}"
APPCAST_PATH=""
MAXIMUM_VERSIONS=10

usage() {
  cat <<'EOF'
Usage:
  ./scripts/generate-appcast.sh --download-url-prefix URL [options]

Options:
  --archives-dir PATH              Directory containing flat release archives and notes
  --download-url-prefix URL        Public URL prefix for release archives
  --release-notes-url-prefix URL   Public URL prefix for release notes (defaults to download URL)
  --private-key-file PATH          Sparkle EdDSA private key file; use - to read stdin
  --keychain-account NAME          Keychain account when no key file is supplied (default: upnext)
  --appcast PATH                   Output appcast path (defaults to ARCHIVES_DIR/appcast.xml)
  --maximum-versions N             Number of versions to retain (default: 10)
  -h, --help                       Show this help

The script delegates signing and appcast generation to Sparkle's official
generate_appcast tool. Release assets must be flat files, for example:
  UpNext-1.0.0.zip
  UpNext-1.0.0.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archives-dir)
      ARCHIVES_DIR="$2"
      shift 2
      ;;
    --download-url-prefix)
      DOWNLOAD_URL_PREFIX="$2"
      shift 2
      ;;
    --release-notes-url-prefix)
      RELEASE_NOTES_URL_PREFIX="$2"
      shift 2
      ;;
    --private-key-file)
      PRIVATE_KEY_FILE="$2"
      shift 2
      ;;
    --keychain-account)
      KEYCHAIN_ACCOUNT="$2"
      shift 2
      ;;
    --appcast)
      APPCAST_PATH="$2"
      shift 2
      ;;
    --maximum-versions)
      MAXIMUM_VERSIONS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$DOWNLOAD_URL_PREFIX" ]]; then
  echo "--download-url-prefix is required" >&2
  exit 2
fi

if [[ ! "$MAXIMUM_VERSIONS" =~ ^[1-9][0-9]*$ ]]; then
  echo "--maximum-versions must be a positive integer" >&2
  exit 2
fi

if [[ -n "$PRIVATE_KEY_FILE" && "$PRIVATE_KEY_FILE" != "-" && ! -s "$PRIVATE_KEY_FILE" ]]; then
  echo "Sparkle private key file not found or empty: $PRIVATE_KEY_FILE" >&2
  exit 1
fi

SIGNING_ARGS=(--account "$KEYCHAIN_ACCOUNT")
if [[ -n "$PRIVATE_KEY_FILE" ]]; then
  SIGNING_ARGS=(--ed-key-file "$PRIVATE_KEY_FILE")
fi

mkdir -p "$ARCHIVES_DIR"
APPCAST_PATH="${APPCAST_PATH:-$ARCHIVES_DIR/appcast.xml}"
RELEASE_NOTES_URL_PREFIX="${RELEASE_NOTES_URL_PREFIX:-$DOWNLOAD_URL_PREFIX}"

if [[ "$DOWNLOAD_URL_PREFIX" != */ ]]; then
  DOWNLOAD_URL_PREFIX="$DOWNLOAD_URL_PREFIX/"
fi
if [[ "$RELEASE_NOTES_URL_PREFIX" != */ ]]; then
  RELEASE_NOTES_URL_PREFIX="$RELEASE_NOTES_URL_PREFIX/"
fi

GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"
if [[ -z "$GENERATE_APPCAST" ]]; then
  GENERATE_APPCAST="$(find "$REPO_ROOT/.build/artifacts" -path '*/Sparkle/bin/generate_appcast' -type f -perm -111 -print -quit 2>/dev/null || true)"
fi

if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast tool not found." >&2
  echo "Run 'swift package resolve' first or set SPARKLE_GENERATE_APPCAST." >&2
  exit 1
fi

"$GENERATE_APPCAST" \
  "${SIGNING_ARGS[@]}" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --release-notes-url-prefix "$RELEASE_NOTES_URL_PREFIX" \
  --maximum-versions "$MAXIMUM_VERSIONS" \
  --maximum-deltas 0 \
  -o "$APPCAST_PATH" \
  "$ARCHIVES_DIR"

echo "Generated and signed appcast: $APPCAST_PATH"
