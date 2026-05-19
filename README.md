# Events Tracker

Events Tracker is a macOS SwiftUI app for students who want a cleaner Canvas dashboard focused on what matters: upcoming work, missing submissions, course context, and quick access back to Canvas.

## What It Does

- Connects to a Canvas instance with a personal access token
- Loads active courses, upcoming events, missing submissions, and the current user profile
- Caches dashboard data locally for faster relaunches
- Lets you filter upcoming and missing work by course

This is currently a focused planner and dashboard companion, not a full Canvas replacement yet.

## Requirements

- macOS 15.1+
- Xcode 16+
- A Canvas personal access token

## Getting Started

1. Open `Events Tracker.xcodeproj` in Xcode.
2. Build and run the `Events Tracker` scheme.
3. Open **Settings** in the app.
4. Enter:
   - your Canvas base URL, for example `https://school.instructure.com`
   - your Canvas personal access token
5. Save and sync.

CLI build:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' \
  -scheme 'Events Tracker' \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Build a local `.app` bundle:

```bash
./scripts/build-app.sh
```

The script writes `dist/Events Tracker.app`. Set `CONFIGURATION=Release` if you want a release build.

## Project Layout

- `Events Tracker/Models/` app state, Canvas API client, config, and local cache
- `Events Tracker/Views/` SwiftUI screens and shared UI components
- `Events TrackerTests/` unit tests
- `Events TrackerUITests/` UI launch tests

## Security Notes

- Do **not** commit real Canvas tokens.
- The app stores non-sensitive Canvas configuration in Application Support and secrets in the macOS Keychain.
- Keep README examples and screenshots free of personal course data.

## Current Direction

The app now covers the dashboard layer well. The next logical areas are modules, announcements, grades, and richer assignment workflows.
