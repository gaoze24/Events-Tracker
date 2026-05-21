# Offline Bulk Downloads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Sync Center offline download planner that lets students select courses, folders, and files for bulk download while respecting the configured download cache limit.

**Architecture:** Keep file metadata preloading separate from file-body downloads. Add lightweight planning models for selected files and skipped reasons, extend `CanvasStore` with plan building, cache-limit validation, and serial bulk execution, then add a focused SwiftUI planner section inside Sync Center. Reuse `downloadFile(_:courseID:)`, `FileDownloadSnapshot`, and `FileDownloadManager` so single-file and bulk downloads share state and error behavior.

**Tech Stack:** Swift 5, SwiftUI, Testing framework, existing Canvas REST models, JSON-backed local persistence.

---

## File Structure

- Modify `Events Tracker/Models/SyncCenterModels.swift`: add `OfflineDownloadSelection`, `OfflineDownloadPlan`, `OfflineDownloadPlanItem`, `OfflineDownloadSkippedFile`, `OfflineDownloadSkipReason`, and `OfflineBulkDownloadProgress`.
- Modify `Events Tracker/Models/CanvasStore.swift`: add published bulk progress state, plan-building APIs, cache-limit validation, and serial bulk runner.
- Modify `Events Tracker/Views/SyncCenterView.swift`: add `OfflineDownloadPlannerView` below Sync Center actions with course/folder/file selection, plan summary, and bulk action.
- Modify `Events TrackerTests/Events_TrackerTests.swift`: add test-first coverage for plan creation, skip reasons, cache-limit blocking, allowed bulk execution, and metadata-only preload preservation.

Do not modify the existing design spec while implementing. Do not create a git commit unless the user explicitly requests commits.

---

### Task 1: Add Offline Download Planning Models

**Files:**
- Modify: `Events Tracker/Models/SyncCenterModels.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing tests for plan summaries and skip counts**

Add this test near the other file download tests:

```swift
@Test func offlineDownloadPlanSummarizesEligibleAndSkippedFiles() async throws {
    let eligible = makeCanvasFile(id: 10, name: "Lecture.pdf", size: 2_048)
    let unknownSize = makeCanvasFile(id: 11, name: "Slides.pdf", size: nil)
    let unavailable = makeCanvasFile(id: 12, name: "Locked.pdf")

    let plan = OfflineDownloadPlan(
        items: [
            OfflineDownloadPlanItem(courseID: 42, folderID: 7, file: eligible),
            OfflineDownloadPlanItem(courseID: 42, folderID: 7, file: unknownSize)
        ],
        skippedFiles: [
            OfflineDownloadSkippedFile(
                courseID: 42,
                folderID: 7,
                file: unavailable,
                reason: .unavailable
            )
        ]
    )

    #expect(plan.fileCount == 2)
    #expect(plan.estimatedByteCount == 2_048)
    #expect(plan.unknownSizeCount == 1)
    #expect(plan.skippedCount == 1)
    #expect(plan.skippedCount(for: .unavailable) == 1)
}
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests/offlineDownloadPlanSummarizesEligibleAndSkippedFiles' test
```

Expected: build fails because `OfflineDownloadPlan`, `OfflineDownloadPlanItem`, and skip models do not exist.

- [ ] **Step 3: Add the planning models**

Append these models to `Events Tracker/Models/SyncCenterModels.swift`:

```swift
struct OfflineDownloadSelection: Equatable {
    var selectedCourseIDs: Set<Int> = []
    var selectedFolderIDs: Set<Int> = []
    var selectedFileIDs: Set<Int> = []
}

enum OfflineDownloadSkipReason: String, Codable, CaseIterable, Hashable, Identifiable {
    case unavailable
    case alreadyDownloaded
    case alreadyDownloading
    case missingDownloadURL

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .alreadyDownloaded:
            return "Already Downloaded"
        case .alreadyDownloading:
            return "Already Downloading"
        case .missingDownloadURL:
            return "Missing Download URL"
        }
    }
}

struct OfflineDownloadPlanItem: Identifiable, Equatable {
    let courseID: Int
    let folderID: Int?
    let file: CanvasFile

    var id: Int { file.id }
    var estimatedByteCount: Int? { file.size }
}

struct OfflineDownloadSkippedFile: Identifiable, Equatable {
    let courseID: Int
    let folderID: Int?
    let file: CanvasFile
    let reason: OfflineDownloadSkipReason

    var id: String { "\(file.id)-\(reason.rawValue)" }
}

struct OfflineDownloadPlan: Equatable {
    var items: [OfflineDownloadPlanItem]
    var skippedFiles: [OfflineDownloadSkippedFile]

    init(items: [OfflineDownloadPlanItem] = [], skippedFiles: [OfflineDownloadSkippedFile] = []) {
        self.items = items
        self.skippedFiles = skippedFiles
    }

    var fileCount: Int { items.count }
    var skippedCount: Int { skippedFiles.count }
    var isEmpty: Bool { items.isEmpty }

    var estimatedByteCount: Int {
        items.reduce(0) { total, item in
            total + (item.estimatedByteCount ?? 0)
        }
    }

    var unknownSizeCount: Int {
        items.filter { $0.estimatedByteCount == nil }.count
    }

    func skippedCount(for reason: OfflineDownloadSkipReason) -> Int {
        skippedFiles.filter { $0.reason == reason }.count
    }
}

struct OfflineBulkDownloadProgress: Equatable {
    let totalCount: Int
    var completedCount: Int
    var failedCount: Int
    let skippedCount: Int

    var processedCount: Int {
        completedCount + failedCount
    }

    var isComplete: Bool {
        processedCount >= totalCount
    }
}
```

- [ ] **Step 4: Run the model test and verify it passes**

Run the same `xcodebuild ... -only-testing:'Events TrackerTests/offlineDownloadPlanSummarizesEligibleAndSkippedFiles' test` command.

Expected: test passes.

---

### Task 2: Build Download Plans From Course, Folder, and File Selections

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing tests for selection expansion and skip reasons**

Add tests near the Task 1 test:

```swift
@MainActor
@Test func canvasStoreBuildsOfflineDownloadPlanFromCourseFolderAndFileSelections() async throws {
    let course = makeCourse(id: 42, name: "Biology")
    let rootFolder = makeCanvasFolder(id: 100, name: "Root", filesCount: 2)
    let labFolder = makeCanvasFolder(id: 101, name: "Labs", filesCount: 1)
    let lecture = makeCanvasFile(id: 1, name: "Lecture.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/1/download"), size: 1_024)
    let worksheet = makeCanvasFile(id: 2, name: "Worksheet.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/2/download"), size: 2_048)
    let lab = makeCanvasFile(id: 3, name: "Lab.pdf", folderID: 101, url: URL(string: "https://canvas.example.edu/files/3/download"), size: 4_096)
    let harness = try makeCanvasStoreHarness(
        courses: [course],
        foldersByCourseID: [42: [rootFolder, labFolder]],
        filesByFolderID: [100: [lecture, worksheet], 101: [lab]]
    )
    defer { harness.cleanup() }

    let plan = harness.store.offlineDownloadPlan(
        selection: OfflineDownloadSelection(
            selectedCourseIDs: [],
            selectedFolderIDs: [100],
            selectedFileIDs: [3]
        )
    )

    #expect(plan.items.map(\.file.id).sorted() == [1, 2, 3])
    #expect(plan.estimatedByteCount == 7_168)
}

@MainActor
@Test func canvasStoreOfflineDownloadPlanSkipsUnavailableDownloadedAndDownloadingFiles() async throws {
    let course = makeCourse(id: 42, name: "Biology")
    let folder = makeCanvasFolder(id: 100, name: "Root", filesCount: 4)
    let available = makeCanvasFile(id: 1, name: "Available.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/1/download"))
    let locked = makeCanvasFile(id: 2, name: "Locked.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/2/download"), lockedForUser: true)
    let downloaded = makeCanvasFile(id: 3, name: "Downloaded.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/3/download"))
    let downloading = makeCanvasFile(id: 4, name: "Downloading.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/4/download"))
    let downloadedURL = FileManager.default.temporaryDirectory.appendingPathComponent("EventsTracker-\(UUID().uuidString)-downloaded.pdf")
    try Data("downloaded".utf8).write(to: downloadedURL)
    defer { try? FileManager.default.removeItem(at: downloadedURL) }
    let downloadSnapshot = FileDownloadSnapshot(recordsByFileID: [
        downloaded.id: FileDownloadRecord(fileID: downloaded.id, courseID: 42, folderID: 100, file: downloaded, state: .downloaded, localPath: downloadedURL.path, downloadedAt: Date(), byteCount: 1_024),
        downloading.id: FileDownloadRecord(fileID: downloading.id, courseID: 42, folderID: 100, file: downloading, state: .downloading)
    ])
    let harness = try makeCanvasStoreHarness(
        courses: [course],
        foldersByCourseID: [42: [folder]],
        filesByFolderID: [100: [available, locked, downloaded, downloading]],
        fileDownloadSnapshot: downloadSnapshot
    )
    defer { harness.cleanup() }

    let plan = harness.store.offlineDownloadPlan(
        selection: OfflineDownloadSelection(selectedCourseIDs: [42])
    )

    #expect(plan.items.map(\.file.id) == [available.id])
    #expect(plan.skippedCount(for: .unavailable) == 1)
    #expect(plan.skippedCount(for: .alreadyDownloaded) == 1)
    #expect(plan.skippedCount(for: .alreadyDownloading) == 1)
}
```

Use the helper added in Step 4 to seed store state through `DatabaseManager`, `CourseDetailCacheManager`, and `FileDownloadManager`; do not assign to `private(set)` store properties directly.

- [ ] **Step 2: Run the selection tests and verify they fail**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests/canvasStoreBuildsOfflineDownloadPlanFromCourseFolderAndFileSelections' -only-testing:'Events TrackerTests/canvasStoreOfflineDownloadPlanSkipsUnavailableDownloadedAndDownloadingFiles' test
```

Expected: build fails because `offlineDownloadPlan(selection:)` is missing.

- [ ] **Step 3: Add plan-building API to `CanvasStore`**

Add this method near the existing download APIs in `CanvasStore.swift`:

```swift
func offlineDownloadPlan(selection: OfflineDownloadSelection) -> OfflineDownloadPlan {
    var itemsByFileID: [Int: OfflineDownloadPlanItem] = [:]
    var skippedByFileID: [Int: OfflineDownloadSkippedFile] = [:]

    for courseID in selectedCourseIDs(from: selection) {
        for folder in courseFoldersByCourseID[courseID] ?? [] {
            addFiles(
                in: folder,
                courseID: courseID,
                itemsByFileID: &itemsByFileID,
                skippedByFileID: &skippedByFileID
            )
        }
    }

    for folderID in selection.selectedFolderIDs {
        guard let courseID = courseID(containingFolderID: folderID),
              let folder = courseFoldersByCourseID[courseID]?.first(where: { $0.id == folderID })
        else {
            continue
        }

        addFiles(
            in: folder,
            courseID: courseID,
            itemsByFileID: &itemsByFileID,
            skippedByFileID: &skippedByFileID
        )
    }

    for fileID in selection.selectedFileIDs {
        guard let match = fileLocation(fileID: fileID) else {
            continue
        }

        addFile(
            match.file,
            courseID: match.courseID,
            folderID: match.folderID,
            itemsByFileID: &itemsByFileID,
            skippedByFileID: &skippedByFileID
        )
    }

    return OfflineDownloadPlan(
        items: itemsByFileID.values.sorted {
            $0.file.name.localizedCaseInsensitiveCompare($1.file.name) == .orderedAscending
        },
        skippedFiles: skippedByFileID.values.sorted {
            $0.file.name.localizedCaseInsensitiveCompare($1.file.name) == .orderedAscending
        }
    )
}
```

Add private helpers below it:

```swift
private func selectedCourseIDs(from selection: OfflineDownloadSelection) -> [Int] {
    selection.selectedCourseIDs
        .filter { courseID in courses.contains { $0.id == courseID } }
        .sorted()
}

private func addFiles(
    in folder: CanvasFolder,
    courseID: Int,
    itemsByFileID: inout [Int: OfflineDownloadPlanItem],
    skippedByFileID: inout [Int: OfflineDownloadSkippedFile]
) {
    for file in courseFilesByFolderID[folder.id] ?? [] {
        addFile(
            file,
            courseID: courseID,
            folderID: folder.id,
            itemsByFileID: &itemsByFileID,
            skippedByFileID: &skippedByFileID
        )
    }
}

private func addFile(
    _ file: CanvasFile,
    courseID: Int,
    folderID: Int?,
    itemsByFileID: inout [Int: OfflineDownloadPlanItem],
    skippedByFileID: inout [Int: OfflineDownloadSkippedFile]
) {
    if itemsByFileID[file.id] != nil || skippedByFileID[file.id] != nil {
        return
    }

    if file.isUnavailable {
        skippedByFileID[file.id] = OfflineDownloadSkippedFile(courseID: courseID, folderID: folderID, file: file, reason: .unavailable)
        return
    }

    if file.url == nil {
        skippedByFileID[file.id] = OfflineDownloadSkippedFile(courseID: courseID, folderID: folderID, file: file, reason: .missingDownloadURL)
        return
    }

    if let record = fileDownloadSnapshot.recordsByFileID[file.id] {
        switch record.state {
        case .downloaded:
            skippedByFileID[file.id] = OfflineDownloadSkippedFile(courseID: courseID, folderID: folderID, file: file, reason: .alreadyDownloaded)
            return
        case .downloading:
            skippedByFileID[file.id] = OfflineDownloadSkippedFile(courseID: courseID, folderID: folderID, file: file, reason: .alreadyDownloading)
            return
        case .failed, .notDownloaded:
            break
        }
    }

    itemsByFileID[file.id] = OfflineDownloadPlanItem(courseID: courseID, folderID: folderID, file: file)
}

private func fileLocation(fileID: Int) -> (courseID: Int, folderID: Int?, file: CanvasFile)? {
    for (courseID, folders) in courseFoldersByCourseID {
        for folder in folders {
            if let file = courseFilesByFolderID[folder.id]?.first(where: { $0.id == fileID }) {
                return (courseID, folder.id, file)
            }
        }
    }

    return nil
}
```

- [ ] **Step 4: Add test harness helpers**

Update the existing `makeCanvasFolder` helper in `Events TrackerTests/Events_TrackerTests.swift` to accept `filesCount` while matching the current `CanvasFolder` initializer:

```swift
private func makeCanvasFolder(
    id: Int,
    name: String,
    parentFolderID: Int? = nil,
    filesCount: Int? = 0
) -> CanvasFolder {
    CanvasFolder(
        id: id,
        name: name,
        fullName: "Course Files/\(name)",
        parentFolderID: parentFolderID,
        filesCount: filesCount,
        foldersCount: nil,
        position: nil,
        locked: nil,
        hidden: nil
    )
}
```

If `makeCanvasFile` lacks `lockedForUser`, add a defaulted parameter and pass it into `CanvasFile`.

Add this test harness near the other test helpers so tests can seed private store state through existing persistence APIs:

```swift
private struct CanvasStoreHarness {
    let store: CanvasStore
    let cleanup: () -> Void
}

@MainActor
private func makeCanvasStoreHarness(
    courses: [Course],
    foldersByCourseID: [Int: [CanvasFolder]],
    filesByFolderID: [Int: [CanvasFile]],
    fileDownloadSnapshot: FileDownloadSnapshot = FileDownloadSnapshot(),
    config: CanvasConfig = CanvasConfig(
        baseURL: "https://canvas.example.edu",
        token: "token",
        lookaheadDays: 14
    ),
    session: URLSession = .shared
) throws -> CanvasStoreHarness {
    let configURL = makeCanvasConfigTempURL()
    let dashboardCacheURL = makeDashboardCacheTempURL()
    let courseDetailCacheURL = makeCourseDetailCacheTempURL()
    let fileMetadataURL = makeFileDownloadMetadataTempURL()
    let downloadsURL = makeDownloadsTempDirectoryURL()
    let urls = [configURL, dashboardCacheURL, courseDetailCacheURL, fileMetadataURL, downloadsURL]
    urls.forEach { try? FileManager.default.removeItem(at: $0) }

    let configManager = CanvasConfigManager(configURL: configURL, tokenStore: InMemoryCanvasTokenStore())
    try configManager.saveConfig(config)

    let databaseManager = DatabaseManager(cacheURL: dashboardCacheURL)
    try databaseManager.saveSnapshot(CanvasSnapshot(
        courses: courses,
        upcomingEvents: [],
        missingSubmissions: [],
        profile: nil,
        syncedAt: Date()
    ))

    let detailCacheManager = CourseDetailCacheManager(cacheURL: courseDetailCacheURL)
    try detailCacheManager.saveCache(CourseDetailCacheSnapshot(
        assignmentsByCourseID: [:],
        modulesByCourseID: [:],
        foldersByCourseID: foldersByCourseID,
        filesByFolderID: filesByFolderID,
        announcementsByCourseID: [:],
        syllabusByCourseID: [:],
        peopleByCourseID: [:],
        courseAccessedAtByCourseID: Dictionary(uniqueKeysWithValues: foldersByCourseID.keys.map { ($0, Date()) }),
        savedAt: Date()
    ))

    let fileDownloadManager = FileDownloadManager(
        metadataURL: fileMetadataURL,
        downloadsDirectory: downloadsURL,
        session: session
    )
    try fileDownloadManager.saveSnapshot(fileDownloadSnapshot)

    let store = CanvasStore(
        configManager: configManager,
        databaseManager: databaseManager,
        networkManager: .shared,
        detailCacheManager: detailCacheManager,
        fileDownloadManager: fileDownloadManager
    )

    return CanvasStoreHarness(
        store: store,
        cleanup: {
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    )
}
```

- [ ] **Step 5: Run selection tests and verify they pass**

Run the same command from Step 2.

Expected: both tests pass.

---

### Task 3: Validate Cache Limit Before Bulk Starts

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing test for blocking the whole plan**

Add:

```swift
@MainActor
@Test func canvasStoreBlocksOfflineBulkDownloadPlanThatExceedsCacheLimit() async throws {
    let configURL = makeCanvasConfigTempURL()
    let fileMetadataURL = makeFileDownloadMetadataTempURL()
    let downloadsURL = makeDownloadsTempDirectoryURL()
    let fileManager = FileManager.default
    [configURL, fileMetadataURL, downloadsURL].forEach { try? fileManager.removeItem(at: $0) }
    defer { [configURL, fileMetadataURL, downloadsURL].forEach { try? fileManager.removeItem(at: $0) } }

    let configManager = CanvasConfigManager(configURL: configURL, tokenStore: InMemoryCanvasTokenStore())
    try configManager.saveConfig(makeCanvasConfig(downloadCacheLimit: .oneGB))

    let manager = FileDownloadManager(metadataURL: fileMetadataURL, downloadsDirectory: downloadsURL)
    let existingFile = makeCanvasFile(id: 1, name: "Existing.pdf", size: 1_024)
    let existingURL = manager.localURL(for: existingFile, courseID: 42)
    try fileManager.createDirectory(at: existingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("existing".utf8).write(to: existingURL)
    try manager.saveSnapshot(FileDownloadSnapshot(recordsByFileID: [
        existingFile.id: FileDownloadRecord(
            fileID: existingFile.id,
            courseID: 42,
            folderID: 100,
            file: existingFile,
            state: .downloaded,
            localPath: existingURL.path,
            downloadedAt: Date(),
            byteCount: DownloadCacheLimitPreset.oneGB.byteLimit! - 512
        )
    ]))

    let store = CanvasStore(
        configManager: configManager,
        fileDownloadManager: manager
    )
    let file = makeCanvasFile(id: 2, name: "TooLarge.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/2/download"), size: 1_024)
    let plan = OfflineDownloadPlan(items: [
        OfflineDownloadPlanItem(courseID: 42, folderID: 100, file: file)
    ])

    await store.downloadOfflinePlan(plan)

    #expect(store.fileDownloadSnapshot.recordsByFileID[file.id] == nil)
    #expect(store.errorMessage?.contains("Download cache limit") == true)
}
```

- [ ] **Step 2: Run the cache-limit bulk test and verify it fails**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests/canvasStoreBlocksOfflineBulkDownloadPlanThatExceedsCacheLimit' test
```

Expected: build fails because `downloadOfflinePlan(_:)` is missing.

- [ ] **Step 3: Add bulk validation and progress state**

Add a published property near existing download state:

```swift
@Published private(set) var offlineBulkDownloadProgress: OfflineBulkDownloadProgress?
```

Initialize it in `CanvasStore.init`:

```swift
self.offlineBulkDownloadProgress = nil
```

Add bulk validation and runner near `downloadFile`:

```swift
func downloadOfflinePlan(_ plan: OfflineDownloadPlan) async {
    guard config.isComplete else {
        errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
        return
    }

    guard !plan.items.isEmpty else {
        errorMessage = "Choose at least one available file to download."
        return
    }

    if let limitError = downloadCacheLimitError(forAdditionalBytes: plan.estimatedByteCount) {
        errorMessage = limitError
        return
    }

    offlineBulkDownloadProgress = OfflineBulkDownloadProgress(
        totalCount: plan.items.count,
        completedCount: 0,
        failedCount: 0,
        skippedCount: plan.skippedCount
    )

    for item in plan.items {
        let beforeState = fileDownloadSnapshot.recordsByFileID[item.file.id]?.state
        await downloadFile(item.file, courseID: item.courseID)
        let afterState = fileDownloadSnapshot.recordsByFileID[item.file.id]?.state

        if afterState == .downloaded {
            offlineBulkDownloadProgress?.completedCount += 1
        } else if beforeState != afterState {
            offlineBulkDownloadProgress?.failedCount += 1
        } else {
            offlineBulkDownloadProgress?.failedCount += 1
        }
    }
}
```

Refactor limit math into a reusable helper:

```swift
private func downloadCacheLimitError(forAdditionalBytes additionalBytes: Int) -> String? {
    guard let byteLimit = config.downloadCacheLimit.byteLimit else {
        return nil
    }

    let reservedBytes = reservedDownloadByteCount(excludingFileID: -1)
    let projectedBytes = reservedBytes + additionalBytes
    guard projectedBytes > byteLimit else {
        return nil
    }

    let currentUsage = ByteCountFormatter.string(fromByteCount: Int64(reservedBytes), countStyle: .file)
    let limit = ByteCountFormatter.string(fromByteCount: Int64(byteLimit), countStyle: .file)
    return "Download cache limit reached (\(currentUsage) of \(limit)). Reduce the offline selection, clear downloaded files, or raise the limit in Settings."
}
```

Update `downloadCacheLimitError(for file:)` to call the new helper after checking `file.size`:

```swift
private func downloadCacheLimitError(for file: CanvasFile) -> String? {
    guard let fileSize = file.size else {
        return nil
    }

    let existingRecord = fileDownloadSnapshot.recordsByFileID[file.id]
    let existingBytes: Int
    if existingRecord?.state == .downloaded || existingRecord?.state == .downloading {
        existingBytes = existingRecord?.byteCount ?? existingRecord?.file.size ?? 0
    } else {
        existingBytes = 0
    }

    return downloadCacheLimitError(forAdditionalBytes: max(0, fileSize - existingBytes))
}
```

- [ ] **Step 4: Run the cache-limit bulk test and verify it passes**

Run the command from Step 2.

Expected: test passes and no network request starts.

---

### Task 4: Run Allowed Bulk Plans Through Existing Downloads

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing test for an allowed run**

Add:

```swift
@MainActor
@Test func canvasStoreDownloadsAllowedOfflineBulkPlanSerially() async throws {
    let configURL = makeCanvasConfigTempURL()
    let fileMetadataURL = makeFileDownloadMetadataTempURL()
    let downloadsURL = makeDownloadsTempDirectoryURL()
    let fileManager = FileManager.default
    [configURL, fileMetadataURL, downloadsURL].forEach { try? fileManager.removeItem(at: $0) }
    defer { [configURL, fileMetadataURL, downloadsURL].forEach { try? fileManager.removeItem(at: $0) } }

    let configManager = CanvasConfigManager(configURL: configURL, tokenStore: InMemoryCanvasTokenStore())
    try configManager.saveConfig(makeCanvasConfig(downloadCacheLimit: .oneGB))

    var requestedPaths: [String] = []
    let session = makeCapturingURLSession { request in
        requestedPaths.append(request.url?.path ?? "")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("download".utf8))
    }

    let store = CanvasStore(
        configManager: configManager,
        fileDownloadManager: FileDownloadManager(metadataURL: fileMetadataURL, downloadsDirectory: downloadsURL, session: session)
    )
    let first = makeCanvasFile(id: 1, name: "A.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/1/download"), size: 1_024)
    let second = makeCanvasFile(id: 2, name: "B.pdf", folderID: 100, url: URL(string: "https://canvas.example.edu/files/2/download"), size: 1_024)
    let plan = OfflineDownloadPlan(items: [
        OfflineDownloadPlanItem(courseID: 42, folderID: 100, file: first),
        OfflineDownloadPlanItem(courseID: 42, folderID: 100, file: second)
    ])

    await store.downloadOfflinePlan(plan)

    #expect(store.fileDownloadSnapshot.recordsByFileID[first.id]?.state == .downloaded)
    #expect(store.fileDownloadSnapshot.recordsByFileID[second.id]?.state == .downloaded)
    #expect(store.offlineBulkDownloadProgress?.completedCount == 2)
    #expect(store.offlineBulkDownloadProgress?.failedCount == 0)
    #expect(requestedPaths == ["/files/1/download", "/files/2/download"])
}
```

- [ ] **Step 2: Run allowed bulk test**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests/canvasStoreDownloadsAllowedOfflineBulkPlanSerially' test
```

Expected: it passes after Task 3 implementation. If it fails because `makeCapturingURLSession` shares static state, reset captured arrays in the handler and keep requests in local state.

- [ ] **Step 3: Preserve metadata-only preload behavior**

Keep the existing `canvasStorePreloadsOfflinePriorityMetadataWithoutDownloadingFileBodies` test passing. Do not call `downloadOfflinePlan(_:)` from `preloadOfflinePriorityCourseMetadata()` or `preloadCourseMetadata(courseID:)`.

- [ ] **Step 4: Run file download focused tests**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests/canvasStoreDownloadsAllowedOfflineBulkPlanSerially' -only-testing:'Events TrackerTests/canvasStorePreloadsOfflinePriorityMetadataWithoutDownloadingFileBodies' -only-testing:'Events TrackerTests/canvasStoreBlocksDownloadsThatWouldExceedConfiguredCacheLimit' test
```

Expected: all selected tests pass.

---

### Task 5: Add Sync Center Offline Download Planner UI

**Files:**
- Modify: `Events Tracker/Views/SyncCenterView.swift`

- [ ] **Step 1: Add planner state to `SyncCenterView`**

Add state near the existing Sync Center state:

```swift
@State private var offlineSelection = OfflineDownloadSelection()
```

Insert the planner in the main VStack after `actions`:

```swift
offlineDownloadPlanner
```

- [ ] **Step 2: Add planner view composition**

Add this computed view inside `SyncCenterView`:

```swift
private var offlineDownloadPlanner: some View {
    OfflineDownloadPlannerView(selection: $offlineSelection)
}
```

Add `OfflineDownloadPlannerView` below `CourseOfflineReadinessRow`:

```swift
private struct OfflineDownloadPlannerView: View {
    @EnvironmentObject private var store: CanvasStore
    @Binding var selection: OfflineDownloadSelection
    @State private var selectedCourseID: Int?
    @State private var isLoadingMetadata = false

    private var selectedCourse: Course? {
        selectedCourseID.flatMap { courseID in
            store.courses.first(where: { $0.id == courseID })
        } ?? store.preferredCourses().first
    }

    private var folders: [CanvasFolder] {
        store.folders(for: selectedCourse?.id)
    }

    private var plan: OfflineDownloadPlan {
        store.offlineDownloadPlan(selection: selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Offline Download Planner")
                        .font(.title2.weight(.semibold))

                    Text("Choose course files to download for offline use. Metadata preload remains separate from file downloads.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        isLoadingMetadata = true
                        if let courseID = selectedCourse?.id {
                            await store.preloadCourseMetadata(courseID: courseID)
                        }
                        isLoadingMetadata = false
                    }
                } label: {
                    if isLoadingMetadata {
                        ProgressView()
                    } else {
                        Text("Load Metadata")
                    }
                }
                .disabled(selectedCourse == nil || isLoadingMetadata)
            }

            plannerControls
            plannerSummary
            plannerTree
        }
        .onAppear {
            if selectedCourseID == nil {
                selectedCourseID = store.preferredCourses().first?.id
            }
        }
    }
}
```

- [ ] **Step 3: Add controls and summary**

Inside `OfflineDownloadPlannerView`, add:

```swift
private var plannerControls: some View {
    HStack(spacing: 12) {
        Picker("Course", selection: $selectedCourseID) {
            ForEach(store.preferredCourses()) { course in
                Text(course.name).tag(Optional(course.id))
            }
        }
        .frame(width: 260)

        Button("Select Course Files") {
            if let courseID = selectedCourse?.id {
                selection.selectedCourseIDs.insert(courseID)
            }
        }
        .disabled(selectedCourse == nil)

        Button("Clear Selection") {
            selection = OfflineDownloadSelection()
        }
        .disabled(selection.selectedCourseIDs.isEmpty && selection.selectedFolderIDs.isEmpty && selection.selectedFileIDs.isEmpty)

        Spacer()

        Button {
            Task {
                await store.downloadOfflinePlan(plan)
            }
        } label: {
            if let progress = store.offlineBulkDownloadProgress, !progress.isComplete {
                Text("\(progress.processedCount)/\(progress.totalCount)")
            } else {
                Text("Download Selected")
            }
        }
        .disabled(plan.isEmpty || store.offlineBulkDownloadProgress?.isComplete == false)
    }
}

private var plannerSummary: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
        SummaryCard(title: "Selected", value: "\(plan.fileCount)", detail: "Files queued for download.", systemImage: "checklist", tint: .blue)
        SummaryCard(title: "Estimated", value: ByteCountFormatter.string(fromByteCount: Int64(plan.estimatedByteCount), countStyle: .file), detail: "\(plan.unknownSizeCount) unknown-size files.", systemImage: "externaldrive", tint: .purple)
        SummaryCard(title: "Skipped", value: "\(plan.skippedCount)", detail: "Already downloaded, unavailable, or missing URLs.", systemImage: "forward.end", tint: .orange)
        SummaryCard(title: "Limit", value: store.localDataInventory.downloadCacheLimitLabel, detail: "Downloaded: \(ByteCountFormatter.string(fromByteCount: Int64(store.fileDownloadSnapshot.downloadedByteCount), countStyle: .file)).", systemImage: "gauge", tint: .green)
    }
}
```

- [ ] **Step 4: Add folder and file selection rows**

Inside `OfflineDownloadPlannerView`, add:

```swift
private var plannerTree: some View {
    VStack(alignment: .leading, spacing: 0) {
        if selectedCourse == nil {
            SetupPromptView(title: "No Course Selected", message: "Sync courses before planning offline downloads.")
        } else if folders.isEmpty {
            SetupPromptView(title: "No File Metadata Loaded", message: "Load metadata for this course before selecting files.")
        } else {
            ForEach(folders) { folder in
                OfflineFolderSelectionRow(
                    folder: folder,
                    files: store.files(for: folder.id),
                    selection: $selection
                )

                if folder.id != folders.last?.id {
                    Divider()
                }
            }
        }
    }
    .padding(16)
    .background(Color.primary.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
}
```

Add the row views:

```swift
private struct OfflineFolderSelectionRow: View {
    let folder: CanvasFolder
    let files: [CanvasFile]
    @Binding var selection: OfflineDownloadSelection

    private var isFolderSelected: Bool {
        selection.selectedFolderIDs.contains(folder.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    if isFolderSelected {
                        selection.selectedFolderIDs.remove(folder.id)
                    } else {
                        selection.selectedFolderIDs.insert(folder.id)
                    }
                } label: {
                    Label(folder.displayName, systemImage: isFolderSelected ? "checkmark.square" : "square")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(files.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(files) { file in
                OfflineFileSelectionRow(file: file, selection: $selection)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct OfflineFileSelectionRow: View {
    let file: CanvasFile
    @Binding var selection: OfflineDownloadSelection

    private var isSelected: Bool {
        selection.selectedFileIDs.contains(file.id)
    }

    var body: some View {
        HStack {
            Button {
                if isSelected {
                    selection.selectedFileIDs.remove(file.id)
                } else {
                    selection.selectedFileIDs.insert(file.id)
                }
            } label: {
                Label(file.name, systemImage: isSelected ? "checkmark.square" : "square")
            }
            .buttonStyle(.plain)
            .disabled(file.isUnavailable)

            Spacer()

            if let size = file.size {
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if file.isUnavailable {
                PillBadge(text: "Unavailable", tint: .orange)
            }
        }
    }
}
```

- [ ] **Step 5: Typecheck UI**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

Expected: exit 0.

---

### Task 6: Final Verification and Review

**Files:**
- Verify all touched files

- [ ] **Step 1: Run the full unit suite**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

Expected: all unit tests pass.

- [ ] **Step 2: Run source typecheck**

Run the `xcrun swiftc -typecheck ...` command from Task 5.

Expected: exit 0.

- [ ] **Step 3: Check diff health**

Run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` exits 0. `git status --short` shows only intentional source, test, spec, and plan changes.

- [ ] **Step 4: Request focused code review**

Ask the reviewer to inspect:

- plan selection expansion and duplicate handling
- cache-limit preflight behavior
- unknown-size file behavior
- serial bulk execution and progress accounting
- Sync Center planner usability and state consistency

Fix any Critical or Important issues before reporting completion.

- [ ] **Step 5: Report completion**

Report:

- what was implemented
- which verification commands passed
- whether any manual UI verification was skipped
- whether commits were created
