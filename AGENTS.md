# AGENTS

## Release Install

- Use `scripts/release.sh` to build a clean `Release` app and install it to `~/Applications/UpNext.app`.
- This script runs `xcodebuild` with `-configuration Release -derivedDataPath /tmp/UpNextRelease clean build`, then replaces `~/Applications/UpNext.app` with the new build.
- Preferred command:
  - `./scripts/release.sh`
