# UpNext

A lightweight macOS menu bar app that shows your next calendar meeting at a glance.

## Features

- Menu bar display of the next upcoming event
- Relative countdowns like `in 12m` / `in 1h 5m`
- Calendar filtering in Settings
- Launch at Login toggle
- Native SwiftUI + EventKit implementation

## Requirements

- macOS 14.0+
- Xcode 16+

## Build and Run

```bash
xcodebuild -project UpNext.xcodeproj -scheme UpNext -configuration Debug -derivedDataPath /tmp/UpNextDerived build
open /tmp/UpNextDerived/Build/Products/Debug/UpNext.app
```

Or open the project in Xcode:

```bash
open UpNext.xcodeproj
```

## Permissions

UpNext requests Calendar access to read your events and show upcoming meetings.

## License

MIT. See [LICENSE](LICENSE).
