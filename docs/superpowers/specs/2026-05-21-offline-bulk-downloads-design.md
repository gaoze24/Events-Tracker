# Offline Bulk Downloads Design

## Goal

Make offline mode more complete by letting students choose courses, folders, and files for bulk download from Sync Center. The feature should preserve the current metadata-only preload behavior while adding an explicit, user-controlled path for downloading file bodies.

## Scope

- Add an `Offline Download Planner` section to Sync Center.
- Let users select files at three levels: course, folder, and individual file.
- Use loaded Canvas file metadata to estimate selected download size before starting.
- Block the entire bulk download if the selected files would exceed the configured download cache limit.
- Download selected files with the existing single-file download path so records, failures, previews, and cache accounting stay consistent.
- Keep existing downloaded files unless the user explicitly removes or clears downloads.

Out of scope for the first version:

- Automatic cleanup to make room for new downloads.
- Overriding the cache limit for a single run.
- Background downloads after the app exits.
- Concurrent download tuning and cancel/resume controls.

## User Experience

Sync Center gains a planner below the existing actions and readiness summary. It shows a course picker or course list, a load/refresh metadata action, and a selectable folder/file tree for the active course. Selecting a course selects all available files in that course; selecting a folder selects available files in that folder; selecting individual files refines the choice.

The planner shows:

- selected file count
- estimated selected size
- current downloaded size and configured limit
- counts for already downloaded, unavailable, unknown-size, and failed files
- current bulk progress while a run is active

The primary action is `Download Selected`. If the estimated selected size plus current reserved download usage exceeds the limit, the action does not start and the app shows a clear error telling the user to reduce the selection or raise the limit in Settings.

## Data Flow

1. The user marks courses as offline priority or opens Sync Center directly.
2. The planner loads course file metadata by reusing `CanvasStore.preloadCourseMetadata(courseID:)` and `loadCourseFiles(for:)`.
3. The planner builds an `OfflineDownloadPlan` from selected course IDs, folder IDs, and file IDs.
4. The plan filters out unavailable files, already-downloaded files, and files already downloading.
5. The plan calculates an estimated byte count from Canvas `CanvasFile.size` metadata.
6. Before starting, `CanvasStore` checks the plan against the configured `DownloadCacheLimitPreset`.
7. If the plan is allowed, `CanvasStore` downloads each file serially by calling the existing `downloadFile(_:courseID:)`.
8. `FileDownloadSnapshot` remains the source of truth for per-file state.

Unknown-size files are allowed only when they otherwise pass eligibility checks. They do not contribute to the preflight estimate, but each individual download still goes through the existing single-file cache limit check.

## Components

### Models

Add lightweight planning models in `SyncCenterModels.swift` or a focused model file:

- `OfflineDownloadPlan`: selected files, skipped files, estimated bytes, and eligibility summary.
- `OfflineDownloadSkipReason`: already downloaded, unavailable, already downloading, missing direct URL, or not selected.
- `OfflineBulkDownloadProgress`: active run counts for total, completed, failed, and skipped.

### Store

Add `CanvasStore` APIs:

- build a plan for selected course/folder/file IDs
- validate a plan against the download cache limit
- run a bulk download plan serially
- expose active bulk progress and active course/file IDs for UI state

The store should reuse current download record mutation and persistence logic rather than duplicating it.

### UI

Add the planner as a SwiftUI subview used by `SyncCenterView`. Keep it local to Sync Center unless it grows large enough to deserve its own file.

The course Files tab can keep its current single-file workflow in this version. A later enhancement can add `Add to Offline Planner` shortcuts from the Files tab.

## Error Handling

- If Canvas credentials are missing, disable loading and downloading actions.
- If metadata loading fails, show the existing store error and keep any cached metadata visible.
- If the plan exceeds the cache limit, block the whole run before downloading anything.
- If a file fails during the run, record that file as failed and continue with the remaining eligible files.
- If the user lowers the cache limit below existing downloads, do not delete existing files; future bulk runs should be blocked until there is room.

## Testing

Use test-first implementation. Add unit tests for:

- building a plan from selected courses, folders, and files
- skipping unavailable, already-downloaded, and already-downloading files
- estimating selected size and exposing skip counts
- blocking a plan that exceeds the configured cache limit before any request starts
- running an allowed plan and updating `FileDownloadSnapshot`
- preserving metadata-only preload behavior unless the user starts a bulk file download

Targeted view logic should stay thin enough that model/store tests cover most behavior.
