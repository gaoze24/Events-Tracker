# File Preview, Download Management, and Global Search Design

## Goal

Add a native file workflow and global search surface to Events Tracker:

- preview or open Canvas files after downloading them locally;
- manage downloaded files with status, filters, and cache cleanup;
- search across synced and cached Canvas data from one app-level page.

This should improve everyday student navigation without silently bulk-downloading course material or attempting full document text indexing.

## Current Context

`Courses > Files` already lists course folders and files from Canvas. `CanvasFile` includes metadata such as `id`, `folderID`, `displayName`, `filename`, `contentType`, `url`, `htmlURL`, `size`, lock/hidden flags, and timestamps. The current UI links out to Canvas but does not keep local downloads.

The app already has local Application Support storage patterns for dashboard snapshots, course detail cache, configuration, and course preferences. `CanvasStore` is the state hub and `NetworkManager` owns Canvas REST calls.

Search is currently page-local: each model has `matchesSearch` helpers, but there is no app-wide search page or result routing.

## Product Design

### File Preview And Download

In `Courses > Files`, each file row should expose:

- `Preview` for downloaded files;
- `Download` for files that are not local yet;
- `Open` for Canvas or local file depending state;
- `Reveal` for downloaded local files where possible.

Downloads are explicit user actions. The app should not bulk-download all course files automatically.

Downloaded files live under Application Support:

```text
EventsTracker/Downloads/<courseID>/<fileID>-<safe-filename>
```

The app tracks file download state:

- not downloaded;
- downloading, with progress when available;
- downloaded, including local URL and downloaded date;
- failed, including a readable error message.

Preview should prefer native Quick Look where available. If Quick Look is not available for a file type, use the system default app. If neither works, keep the Canvas link as the fallback.

### Download Management Page

Add a top-level `Downloads` page to the app sidebar.

The page should show all known downloaded/downloadable files that the app has seen through course file browsing. It should include:

- summary cards for downloaded, downloading, failed, and storage size;
- filters for course, file type, and status;
- search by filename/content type/course;
- actions to preview/open, reveal in Finder, retry failed download, remove one local file, and clear all downloaded files.

The page should remain useful even if not every course folder has been loaded. It should clearly say that it reflects files the app has already seen or downloaded.

### Global Search

Add a top-level `Search` page to the app sidebar.

Search scope is currently synced and cached data:

- courses;
- assignments;
- upcoming events;
- missing submissions;
- modules and module items;
- folders and files;
- announcements;
- syllabus summaries;
- people;
- cached native quiz/discussion/page details.

Results should be grouped by type and course when possible, with type filters. Recent search terms are saved locally and can be cleared.

Click behavior:

- Course results open `Courses`;
- assignment/event/missing results open Canvas link or relevant course page;
- module/file/announcement/person/syllabus results open `Courses` with the best available course context;
- cached quiz/discussion/page detail results open the related course/module context when possible;
- if exact in-app routing is not available, use the Canvas link fallback.

### Out Of Scope

- Full-text indexing of downloaded PDFs, Office documents, or images.
- Background/bulk downloading all files for all courses.
- iCloud sync of downloaded files or search history.
- Editing, uploading, or deleting Canvas files remotely.
- Offline guarantee for data that has never been loaded by the app.

## Technical Design

### Download Models

Add models in `DataStructure.swift` or a focused model file:

- `FileDownloadStatus`
- `FileDownloadRecord`
- `FileDownloadSnapshot`
- helpers for safe filenames and file type labels.

Records should be keyed by Canvas file ID. Include course ID when known, folder ID, file metadata snapshot, local URL path, status, downloaded date, failure message, and byte count.

### File Download Manager

Create `FileDownloadManager.swift` in `Models/`.

Responsibilities:

- load/save `file-downloads.json` in Application Support;
- resolve local download URLs;
- download a single Canvas file URL with the Canvas bearer token;
- remove one downloaded file;
- clear all downloaded files;
- calculate downloaded storage size;
- tolerate corrupt JSON by clearing and returning defaults.

`NetworkManager` can expose a lower-level authorized download method, or `FileDownloadManager` can accept `CanvasConfig` and perform the request directly. Prefer a small manager with injected `URLSession` for testability.

### Store Integration

Extend `CanvasStore` with:

- `fileDownloadSnapshot`;
- download state accessors for `CanvasFile`;
- `downloadFile(_:courseID:)`;
- `removeDownloadedFile(_:)`;
- `clearDownloadedFiles()`;
- `openDownloadedFile(_:)` / URL helpers for UI.

When course files load, register seen file metadata in the download snapshot so the Downloads page can list files the user has browsed even before download.

Credential changes should clear download metadata and local downloads because Canvas file IDs and permissions are account-specific.

### Preview/Open

Add a SwiftUI sheet or system integration wrapper for Quick Look if feasible on macOS. If Quick Look integration adds too much risk, use `NSWorkspace.shared.open(localURL)` for the first implementation while keeping the UI label `Preview/Open`.

Reveal in Finder uses `NSWorkspace.shared.activateFileViewerSelecting([url])`.

### Search Index

Create a pure `GlobalSearchIndex` builder:

- input: current `CanvasStore` data snapshots;
- output: `[GlobalSearchResult]`;
- no network calls;
- deterministic ranking:
  - title/name exact or prefix matches first;
  - then substring matches;
  - then metadata/body matches;
  - stable sort by type/course/title.

Create models:

- `GlobalSearchResult`
- `GlobalSearchResultKind`
- `RecentSearchStore` or store recent terms in course preferences if appropriate.

The search index should only search loaded/cached data. The UI should explain this so users understand why unloaded course files may not appear yet.

### UI

Add `downloads` and `search` cases to `AppSection` in `ContentView`.

Create:

- `DownloadsView.swift`;
- `GlobalSearchView.swift`;
- small reusable rows where helpful.

`Courses > Files` should call the same download actions used by `DownloadsView`.

## Error Handling

File downloads should surface errors without crashing:

- missing file URL;
- locked/hidden file;
- Canvas auth failure;
- failed local write;
- missing local file after a previous download.

Search should handle empty queries, no cached data, and no matches with helpful empty states.

## Testing

Add unit tests for:

- safe download filename generation;
- download snapshot save/load and corrupt JSON fallback;
- download record status transitions;
- authorized file download request headers;
- clear one/all downloaded files;
- global search result creation across assignments/modules/files/announcements/people;
- search ranking and type filtering;
- recent search save/load/clear.

Verification commands:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```
