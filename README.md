# Events Tracker

Events Tracker is a macOS SwiftUI app for students who want a cleaner Canvas dashboard focused on what matters: upcoming work, missing submissions, course context, and quick access back to Canvas.

## What It Does

- Connects to a Canvas instance with a personal access token
- Loads active courses, upcoming events, missing submissions, grades, course details, people, and the current user profile
- Presents a dashboard for overdue work, today, this week, and later priorities
- Provides a calendar workspace with calendar, week, and agenda views
- Adds course workspaces for overview, modules, announcements, syllabus, files, people, assignments, and grades
- Caches dashboard and course detail data locally for faster relaunches
- Lets you filter course work, calendar items, files, announcements, and people
- Can send Telegram reminders for assignments due soon while the app is open

This is a student-side Canvas companion. It focuses on planning, course context, and quick review, while still linking back to Canvas for workflows that are not native yet.

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

## Data And Caching

- Canvas configuration is stored under Application Support.
- Canvas and Telegram tokens are stored in the macOS Keychain.
- Dashboard snapshots and lazily loaded course details are cached locally with short TTLs.
- Changing the Canvas URL or token clears cached app data so accounts do not mix.

## Security Notes

- Do **not** commit real Canvas tokens.
- The app stores non-sensitive Canvas configuration in Application Support and secrets in the macOS Keychain.
- Keep README examples and screenshots free of personal course data.

## Current Direction

The app now covers the core student planning surface, course workspace, files, syllabus, announcements, people, assignments, grades, local cache, and Telegram reminders. The next logical areas are richer assignment workflows, native quiz/discussion/page detail views, Canvas Inbox or notification support, saved course preferences, and clearer cache/offline state.
