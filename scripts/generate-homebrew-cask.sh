#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 APP_ZIP VERSION [OUTPUT_PATH]" >&2
  exit 2
fi

APP_ZIP="$1"
VERSION="$2"
OUTPUT_PATH="${3:-artifacts/releases/upnext.rb}"

if [[ ! -f "$APP_ZIP" ]]; then
  echo "Archive not found: $APP_ZIP" >&2
  exit 1
fi

if ! unzip -Z1 "$APP_ZIP" | grep '^UpNext\.app/' >/dev/null; then
  echo "Archive must contain UpNext.app at its root" >&2
  exit 1
fi

SHA256="$(shasum -a 256 "$APP_ZIP" | awk '{print $1}')"
mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<EOF
cask "upnext" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/srichand/UpNext/releases/download/v#{version}/UpNext-#{version}.zip"
  name "UpNext"
  desc "Shows the next calendar meeting in the macOS menu bar"
  homepage "https://github.com/srichand/UpNext"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "UpNext.app"

  uninstall quit: "com.srichand.UpNext"

  zap trash: [
    "~/Library/Caches/com.srichand.UpNext",
    "~/Library/Preferences/com.srichand.UpNext.plist",
    "~/Library/Saved Application State/com.srichand.UpNext.savedState",
  ]
end
EOF

echo "Generated Homebrew Cask: $OUTPUT_PATH"
echo "SHA-256: $SHA256"
