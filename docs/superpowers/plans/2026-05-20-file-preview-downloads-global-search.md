# File Preview Downloads Global Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit Canvas file downloads with local open/reveal management and an app-wide search page over synced/cached Canvas data.

**Architecture:** Introduce a file download snapshot and manager backed by Application Support JSON plus local files, expose download actions through `CanvasStore`, and add `DownloadsView` plus file-row controls. Build global search from already-loaded store state using a pure index builder and store recent search terms locally.

**Tech Stack:** Swift 5, SwiftUI, Foundation `URLSession`, AppKit `NSWorkspace`, Swift Testing, existing macOS Xcode project.

---

## File Structure

- Modify `Events Tracker/Models/DataStructure.swift`
  - Add file download models.
  - Add global search result models.
- Create `Events Tracker/Models/FileDownloadManager.swift`
  - Download metadata persistence, file URL generation, download/remove/clear actions.
- Create `Events Tracker/Models/GlobalSearchIndex.swift`
  - Pure search index builder and ranking.
- Create `Events Tracker/Models/RecentSearchManager.swift`
  - Recent search persistence.
- Modify `Events Tracker/Models/CanvasStore.swift`
  - Own download snapshot and recent search terms.
  - Register seen files, trigger downloads, remove files, and build search results.
- Modify `Events Tracker/Views/ContentView.swift`
  - Add `Downloads` and `Search` sidebar sections.
- Create `Events Tracker/Views/DownloadsView.swift`
  - Download manager page.
- Create `Events Tracker/Views/GlobalSearchView.swift`
  - Global search page.
- Modify `Events Tracker/Views/CoursesView.swift`
  - Add download/open/reveal actions to file rows.
- Modify `Events TrackerTests/Events_TrackerTests.swift`
  - Add manager/model/search tests.

Do not create git commits unless the user explicitly asks for commits.

---

### Task 1: Download Models And Manager

**Files:**
- Modify: `Events Tracker/Models/DataStructure.swift`
- Create: `Events Tracker/Models/FileDownloadManager.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [x] **Step 1: Add tests**

Add tests for safe filename, snapshot round-trip, and corrupt JSON fallback.

- [x] **Step 2: Add models**

Add:

```swift
enum FileDownloadState: String, Codable, CaseIterable
struct FileDownloadRecord: Codable, Identifiable, Hashable
struct FileDownloadSnapshot: Codable, Equatable
```

Include helpers for `safeFilename`, `typeLabel`, `isDownloaded`, and storage size.

- [x] **Step 3: Implement `FileDownloadManager`**

Persist `file-downloads.json`, resolve `Downloads/<courseID>/<fileID>-filename`, download using bearer token, remove one file, clear all files, and calculate size.

---

### Task 2: Store Integration

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [x] **Step 1: Add store state**

Add `@Published private(set) var fileDownloadSnapshot`, `downloadingFileIDs`, and manager dependency.

- [x] **Step 2: Register seen files**

When `loadFiles(for:)` succeeds, register files with the containing course ID.

- [x] **Step 3: Add actions**

Add `downloadFile(_:courseID:)`, `removeDownloadedFile(_:)`, `clearDownloadedFiles()`, `openDownloadedFile(_:)`, and `revealDownloadedFile(_:)`.

- [x] **Step 4: Clear downloads on account reset**

`clearLocalData()` should clear download metadata and local files.

---

### Task 3: Downloads UI And Course File Row Actions

**Files:**
- Create: `Events Tracker/Views/DownloadsView.swift`
- Modify: `Events Tracker/Views/CoursesView.swift`
- Modify: `Events Tracker/Views/ContentView.swift`

- [x] **Step 1: Add `downloads` app section**

Add sidebar item and route to `DownloadsView`.

- [x] **Step 2: Implement `DownloadsView`**

Show summary cards, status/course/type filters, search, rows, retry/remove/open/reveal/clear-all actions.

- [x] **Step 3: Add file row actions**

In `CourseFileRow`, show Download for remote files, Preview/Open and Reveal for downloaded files, and failed retry state.

---

### Task 4: Global Search Models And Recent Terms

**Files:**
- Modify: `Events Tracker/Models/DataStructure.swift`
- Create: `Events Tracker/Models/GlobalSearchIndex.swift`
- Create: `Events Tracker/Models/RecentSearchManager.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [x] **Step 1: Add search tests**

Verify results for courses, assignments, modules/items, files, announcements, people, and recent term persistence.

- [x] **Step 2: Add search models**

Add `GlobalSearchResultKind`, `GlobalSearchResult`, and filtering helpers.

- [x] **Step 3: Implement search index**

Build results from loaded `CanvasStore` state only. Rank exact/prefix title matches before substring metadata matches.

- [x] **Step 4: Implement recent search manager**

Persist recent terms to `recent-searches.json`, cap to 10 terms, and support clear.

---

### Task 5: Global Search UI And Store Wiring

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Create: `Events Tracker/Views/GlobalSearchView.swift`
- Modify: `Events Tracker/Views/ContentView.swift`

- [x] **Step 1: Add store search helpers**

Add `globalSearchResults(for:)`, recent term load/save, and clear.

- [x] **Step 2: Add `search` app section**

Add sidebar item and route to `GlobalSearchView`.

- [x] **Step 3: Implement search UI**

Search field, recent terms, type filter, grouped results, Canvas link fallback.

---

### Task 6: Verification

**Files:**
- All edited files

- [x] **Step 1: Run lints**

Read diagnostics for changed Swift files.

- [x] **Step 2: Run typecheck**

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

- [x] **Step 3: Run unit tests**

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

- [x] **Step 4: Inspect git status**

Run `git status --short --branch` and ensure only expected files changed.

---

## Self-Review

- Spec coverage: downloads, manager page, course file actions, global search, recent searches, and validation are covered.
- Placeholder scan: no unresolved TODO/TBD.
- Type consistency: model, manager, store, and UI names are consistent.
