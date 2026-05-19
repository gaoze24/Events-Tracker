# Native Module Details Course Preferences Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add read-only native Quiz, Discussion, and Page detail sheets for module items, plus persisted course preferences for workspace state, pinned/hidden/default courses, and Events defaults.

**Architecture:** Add detail models and Canvas API methods, cache module-item details through the existing course detail cache, and route module row taps through `CanvasStore`. Store non-secret course preferences in a dedicated Application Support JSON manager and expose small store helpers that `CoursesView` and `EventsView` bind to.

**Tech Stack:** Swift 5, SwiftUI, Foundation `URLSession`, Swift Testing, existing macOS Xcode project.

---

## File Structure

- Modify `Events Tracker/Models/DataStructure.swift`
  - Add `CourseQuizDetail`, `CourseDiscussionDetail`, `CoursePageDetail`, `CourseModuleItemDetail`, and `CourseModuleItemDetailKey`.
  - Add course preference model structs.
- Create `Events Tracker/Models/CoursePreferenceManager.swift`
  - Own `course-preferences.json` save/load/clear.
- Modify `Events Tracker/Models/NetworkManager.swift`
  - Add fetch methods for quiz, discussion, and page detail.
- Modify `Events Tracker/Models/CourseDetailCacheManager.swift`
  - Add module item details to `CourseDetailCacheSnapshot` and pruning.
- Modify `Events Tracker/Models/CanvasStore.swift`
  - Own course preferences.
  - Load and cache module item details.
  - Resolve sorted/visible courses and defaults.
- Create `Events Tracker/Views/ModuleItemDetailView.swift`
  - Read-only native detail sheet.
- Modify `Events Tracker/Views/SharedComponents.swift`
  - Allow module item rows/cards to receive a tap handler for supported native details.
- Modify `Events Tracker/Views/CoursesView.swift`
  - Bind workspace controls to preferences where practical.
  - Add pin/hide/default controls.
  - Open native detail sheet for supported module items.
- Modify `Events Tracker/Views/EventsView.swift`
  - Use preferred visible courses and saved Events default filter.
- Modify `Events TrackerTests/Events_TrackerTests.swift`
  - Add model, network, cache, and preference tests.

Do not create git commits unless the user explicitly asks for commits.

---

### Task 1: Models And Preference Manager

**Files:**
- Modify: `Events Tracker/Models/DataStructure.swift`
- Create: `Events Tracker/Models/CoursePreferenceManager.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Add tests for detail keys and preferences**

Add tests for:

```swift
@Test func moduleItemDetailKeysAreStable() async throws {
    #expect(CourseModuleItemDetailKey.quiz(courseID: 42, quizID: 9).rawValue == "quiz:42:9")
    #expect(CourseModuleItemDetailKey.discussion(courseID: 42, discussionID: 8).rawValue == "discussion:42:8")
    #expect(CourseModuleItemDetailKey.page(courseID: 42, pageURL: "week-1").rawValue == "page:42:week-1")
}

@Test func coursePreferenceManagerRoundTripsPreferences() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("EventsTracker-\(UUID().uuidString)-course-preferences.json")
    let manager = CoursePreferenceManager(preferencesURL: url)
    defer { try? FileManager.default.removeItem(at: url) }

    var snapshot = CoursePreferencesSnapshot()
    snapshot.pinnedCourseIDs = [10]
    snapshot.hiddenCourseIDs = [20]
    snapshot.defaultCourseID = 10
    snapshot.defaultEventsCourseID = 10
    snapshot.preferencesByCourseID[10] = SingleCoursePreference(
        workspaceSection: "Modules",
        modules: CourseWorkspacePreference(searchQuery: "quiz", filter: "Quizzes", sort: "Name")
    )

    try manager.savePreferences(snapshot)
    let loaded = manager.loadPreferences()

    #expect(loaded.pinnedCourseIDs == [10])
    #expect(loaded.hiddenCourseIDs == [20])
    #expect(loaded.defaultCourseID == 10)
    #expect(loaded.preferencesByCourseID[10]?.workspaceSection == "Modules")
    #expect(loaded.preferencesByCourseID[10]?.modules.searchQuery == "quiz")
}
```

- [ ] **Step 2: Implement detail and preference models**

Add native detail models and `CourseModuleItemDetailKey`/`CourseModuleItemDetail` to `DataStructure.swift`.

Add preference models with default values:

```swift
struct CourseWorkspacePreference: Codable, Equatable {
    var searchQuery: String = ""
    var filter: String = "All"
    var sort: String = ""
}

struct SingleCoursePreference: Codable, Equatable {
    var workspaceSection: String = "Overview"
    var modules: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Canvas Order")
    var files: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Canvas Order")
    var announcements: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Recent")
    var assignments: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Due Date")
    var grades: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Recent")
    var people: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Role")
}

struct CoursePreferencesSnapshot: Codable, Equatable {
    var pinnedCourseIDs: Set<Int> = []
    var hiddenCourseIDs: Set<Int> = []
    var defaultCourseID: Int?
    var defaultEventsCourseID: Int?
    var preferencesByCourseID: [Int: SingleCoursePreference] = [:]
}
```

- [ ] **Step 3: Implement `CoursePreferenceManager`**

Create a JSON manager mirroring existing Application Support manager patterns. If decode fails, clear the corrupt file and return defaults.

---

### Task 2: Native Detail Networking And Cache

**Files:**
- Modify: `Events Tracker/Models/NetworkManager.swift`
- Modify: `Events Tracker/Models/CourseDetailCacheManager.swift`
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Add network tests**

Add tests that verify request paths:

- quiz: `/api/v1/courses/42/quizzes/7`
- discussion: `/api/v1/courses/42/discussion_topics/8`
- page: `/api/v1/courses/42/pages/week-1`

Each test should assert decoded title/body summary fields.

- [ ] **Step 2: Add `NetworkManager` fetch methods**

Implement:

```swift
func fetchQuizDetail(courseID: Int, quizID: Int, using config: CanvasConfig) async throws -> CourseQuizDetail
func fetchDiscussionDetail(courseID: Int, discussionID: Int, using config: CanvasConfig) async throws -> CourseDiscussionDetail
func fetchPageDetail(courseID: Int, pageURL: String, using config: CanvasConfig) async throws -> CoursePageDetail
```

- [ ] **Step 3: Extend cache snapshot**

Add `moduleItemDetailsByKey: [String: CourseModuleItemDetail]` to `CourseDetailCacheSnapshot`, with default decoding to `[:]` and pruning by course ID encoded in each key.

- [ ] **Step 4: Extend `CanvasStore`**

Add:

```swift
@Published private(set) var moduleItemDetailsByKey: [String: CourseModuleItemDetail]
@Published private(set) var loadingModuleItemDetailKeys: Set<String>
```

Add detail access and load methods:

```swift
func moduleItemDetail(for key: CourseModuleItemDetailKey?) -> CourseModuleItemDetail?
func isLoadingModuleItemDetail(_ key: CourseModuleItemDetailKey?) -> Bool
func loadModuleItemDetailIfNeeded(courseID: Int, item: CourseModuleItem) async
```

Switch by item type and call the relevant network method.

---

### Task 3: Course Preferences Store Integration

**Files:**
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Add store preference tests**

Add tests for pinned/hidden/default resolution:

```swift
@MainActor
@Test func canvasStoreSortsPinnedCoursesAndHidesHiddenCourses() async throws {
    // Create store with three cached courses, pin course 3, hide course 2.
    // Expect preferredCourses(showingHidden: false).map(\.id) == [3, 1]
}
```

- [ ] **Step 2: Add `CoursePreferenceManager` dependency to `CanvasStore`**

Initialize `coursePreferences = preferenceManager.loadPreferences()` and clear preferences in `clearLocalData()`.

- [ ] **Step 3: Add helper methods**

Add helpers:

```swift
func preferredCourses(showingHidden: Bool = false) -> [Course]
func coursePreference(for courseID: Int?) -> SingleCoursePreference
func updateCoursePreference(courseID: Int, _ update: (inout SingleCoursePreference) -> Void)
func togglePinnedCourse(_ courseID: Int)
func toggleHiddenCourse(_ courseID: Int)
func setDefaultCourse(_ courseID: Int?)
func setDefaultEventsCourse(_ courseID: Int?)
```

Persist after each mutation.

---

### Task 4: Native Module Detail UI

**Files:**
- Create: `Events Tracker/Views/ModuleItemDetailView.swift`
- Modify: `Events Tracker/Views/SharedComponents.swift`
- Modify: `Events Tracker/Views/CoursesView.swift`

- [ ] **Step 1: Create detail sheet view**

Render the loading, loaded, and unsupported states. Loaded states should show metrics, body text, and Canvas link.

- [ ] **Step 2: Add module row tap support**

Change `CourseModuleCard` and `CourseModuleItemRow` to accept `onOpenNativeDetail: ((CourseModuleItem) -> Void)?`. For supported types, show `Details` button and call the handler. Keep the Canvas link.

- [ ] **Step 3: Wire CoursesView**

Track `selectedModuleDetailItem`, compute its key, present `ModuleItemDetailView`, and trigger `store.loadModuleItemDetailIfNeeded`.

---

### Task 5: Course Preference UI

**Files:**
- Modify: `Events Tracker/Views/CoursesView.swift`
- Modify: `Events Tracker/Views/EventsView.swift`
- Modify: `Events Tracker/Views/CoursePeopleView.swift` if needed

- [ ] **Step 1: Use preferred course lists**

Use `store.preferredCourses(showingHidden:)` in Courses and Events course pickers/lists.

- [ ] **Step 2: Add course controls**

Add show hidden toggle, pin/unpin, hide/unhide, and default course actions near the selected course header/list row.

- [ ] **Step 3: Persist workspace section**

On workspace selection change, update the selected course preference.

- [ ] **Step 4: Persist control state where practical**

Bind module search/filter/sort, files, announcements, assignments, grades, and people controls to preference helpers. Prefer incremental persistence over one large settings screen.

---

### Task 6: Verification

**Files:**
- All edited files

- [ ] **Step 1: Run IDE diagnostics**

Read lints for changed Swift files and fix introduced errors.

- [ ] **Step 2: Run source typecheck**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

- [ ] **Step 3: Run targeted tests**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:'Events TrackerTests' test
```

- [ ] **Step 4: Inspect git status**

Run `git status --short --branch` and verify only expected files changed.

---

## Self-Review

- Spec coverage: native quiz/discussion/page detail, module row behavior, cache/store, course preference persistence, hidden/pinned/default course behavior, and verification are covered.
- Placeholder scan: no unresolved TBD/TODO items remain.
- Type consistency: model, manager, store, and UI names match throughout the plan.
