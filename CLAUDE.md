# UpNext

A macOS menu bar app that shows your next upcoming calendar meeting at a glance.

## Project Overview

**Type:** Native macOS menu bar utility (no dock icon, no main window)
**Platform:** macOS 14+ (Sonoma)
**UI Framework:** SwiftUI
**Language:** Swift 6 with strict concurrency
**Build System:** Xcode / Swift Package Manager

## Architecture

### App Structure

- **Menu bar only** — uses `MenuBarExtra` with a popover/menu for interaction. No dock icon (`LSUIElement = true` in Info.plist).
- The menu bar item displays the next meeting's title and time (e.g., "Standup in 12m"). When no meetings remain, show something like "No more meetings today".
- Clicking the menu bar item opens a popover showing more detail about the upcoming meeting(s).

### Core Components

- **UpNextApp** — `@main` App entry point. Configures the `MenuBarExtra` scene.
- **CalendarManager** — Wraps EventKit. Handles calendar access permissions, fetching events, and filtering by selected calendars. Publishes the upcoming event(s).
- **MenuBarViewModel** — Drives the menu bar label and popover content. Subscribes to CalendarManager, computes relative time strings, refreshes on a timer.
- **SettingsView** — A settings window (opened from the popover menu) where the user selects which calendars to monitor. Persists selections to UserDefaults/AppStorage.
- **EventModel** — Lightweight struct representing a calendar event (title, start, end, calendar color, location, etc.).

### Data Flow

1. CalendarManager requests EventKit access on first launch.
2. On grant, it fetches today's events from selected calendars. Re-fetches periodically and on `EKEventStoreChanged` notifications.
3. MenuBarViewModel filters to future events, sorts by start time, picks the next one.
4. The menu bar label updates on a per-minute timer to keep the relative time ("in 5m", "in 1h 20m", "now") fresh.

## Key Technical Details

### EventKit

- Use `EKEventStore` for calendar access. Request full access (`requestFullAccessToEvents`) on macOS 14+.
- Requires the `com.apple.security.personal-information.calendars` entitlement.
- Add `NSCalendarsFullAccessUsageDescription` to Info.plist.
- Listen for `EKEventStoreChangedNotification` to refresh when the user modifies events externally.

### Sandboxing & Permissions

- App Sandbox enabled. Calendar entitlement required.
- No network access needed — everything is local via EventKit.

### Settings / Persistence

- Store selected calendar identifiers in `UserDefaults` (via `AppStorage` or `@AppStorage`).
- Settings window should list all available calendars grouped by account, with toggles. Show calendar color swatches next to names.
- Default behavior on first launch: all calendars selected.

### Menu Bar Display

- Keep the menu bar string short. Truncate long meeting titles.
- Format: `"[Title] in [time]"` or `"[Title] (now)"` if the meeting has started but not ended.
- Use SF Symbols for a calendar icon in the menu bar alongside the text.

## Coding Conventions

- Use Swift's structured concurrency (`async/await`, `@MainActor`) rather than Combine where possible.
- Use `@Observable` (Observation framework, macOS 14+) for view models rather than `ObservableObject`/`@Published`.
- Keep views thin — logic lives in view models and managers.
- Prefer value types (structs/enums) over classes where appropriate.
- No third-party dependencies unless absolutely necessary. EventKit and SwiftUI provide everything needed.

## Build & Run

```
open UpNext.xcodeproj
# or
xcodebuild -scheme UpNext -configuration Debug build
```

## File Structure (target)

```
UpNext/
  UpNextApp.swift
  Models/
    EventModel.swift
  ViewModels/
    MenuBarViewModel.swift
  Views/
    MenuBarPopover.swift
    SettingsView.swift
  Services/
    CalendarManager.swift
  Resources/
    Assets.xcassets
    Info.plist
    UpNext.entitlements
```
