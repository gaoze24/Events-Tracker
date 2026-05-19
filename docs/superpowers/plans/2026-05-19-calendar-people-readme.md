# Calendar People README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the `Events` section into a hybrid calendar workspace, add course-scoped `People`, and refresh the README.

**Architecture:** Reuse existing dashboard event data for calendar views, add lazy course People loading through the same `NetworkManager` -> `CanvasStore` -> SwiftUI path as modules/files/announcements, and include People in course detail caching. Keep date grouping and role normalization as small model helpers so unit tests cover behavior without UI automation.

**Tech Stack:** Swift 5, SwiftUI, Foundation `URLSession`, Swift Testing, existing Xcode project with file-system synchronized groups.

---

## File Structure

- Modify `Events Tracker/Models/DataStructure.swift`
  - Add `CoursePerson`, `CoursePersonEnrollment`, `CoursePersonRole`, and `CalendarEventItem`.
  - Add search, role normalization, date bucketing, and display helpers.
- Modify `Events Tracker/Models/NetworkManager.swift`
  - Add `fetchPeople(courseID:using:)`.
  - Keep existing paginated request flow and sorting style.
- Modify `Events Tracker/Models/CourseDetailCacheManager.swift`
  - Persist People data in `CourseDetailCacheSnapshot`.
  - Include People in pruning and course-presence checks.
- Modify `Events Tracker/Models/CanvasStore.swift`
  - Add course People dictionaries, loading state, accessors, and load methods.
  - Include People in cache restore/save/apply/clear logic.
- Modify `Events Tracker/Views/EventsView.swift`
  - Replace the current two-list view with Calendar, Week, and Agenda modes.
  - Preserve course filtering.
- Modify `Events Tracker/Views/CoursesView.swift`
  - Add `People` as a course workspace tab.
  - Load People lazily when the tab opens.
- Create `Events Tracker/Views/CoursePeopleView.swift`
  - Render summary cards, filters, search, roster rows, and detail sheet.
- Modify `Events TrackerTests/Events_TrackerTests.swift`
  - Add focused tests for calendar bucketing, month generation, People role normalization/search, cache, and network requests.
- Modify `README.md`
  - Update feature list, data/security notes, and current roadmap.

Do not create git commits unless the user explicitly asks for commits.

---

### Task 1: Calendar And People Model Tests

**Files:**
- Modify: `Events TrackerTests/Events_TrackerTests.swift`
- Modify: `Events Tracker/Models/DataStructure.swift`

- [ ] **Step 1: Add failing model tests**

Append tests for:

```swift
@Test func calendarEventItemsBucketUpcomingAndMissingByDay() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let dueDate = Date(timeIntervalSince1970: 1_710_028_800)
    let upcoming = makeUpcomingEvent(date: dueDate)
    let missing = MissingSubmission(
        id: 44,
        name: "Late Essay",
        dueAt: dueDate,
        courseID: 10,
        htmlURL: nil,
        pointsPossible: 10
    )

    let items = CalendarEventItem.items(upcomingEvents: [upcoming], missingSubmissions: [missing])
    let grouped = CalendarEventItem.groupByDay(items, calendar: calendar)

    #expect(items.count == 2)
    #expect(grouped.count == 1)
    #expect(grouped.values.first?.contains { $0.isMissing } == true)
    #expect(grouped.values.first?.contains { $0.isUpcoming } == true)
}

@Test func calendarMonthBuildsFullWeeksAroundMonthBoundaries() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let month = calendar.date(from: DateComponents(year: 2026, month: 5, day: 19))!

    let days = CalendarEventItem.visibleMonthDays(containing: month, calendar: calendar)

    #expect(days.count % 7 == 0)
    #expect(days.count >= 35)
    #expect(calendar.component(.month, from: days[10]) == 5)
}

@Test func coursePersonNormalizesRolesAndMatchesSearch() async throws {
    let teacher = CoursePerson(
        id: 1,
        name: "Dr. Smith",
        sortableName: "Smith, Dr.",
        shortName: "Dr. Smith",
        avatarURL: nil,
        htmlURL: nil,
        email: "smith@example.edu",
        loginID: "smith",
        enrollments: [
            CoursePersonEnrollment(
                type: "TeacherEnrollment",
                role: "TeacherEnrollment",
                roleID: nil,
                sectionID: nil,
                sectionName: "Lecture",
                enrollmentState: "active",
                lastActivityAt: nil
            )
        ]
    )

    #expect(teacher.primaryRole == .teacher)
    #expect(teacher.roleLabel == "Teacher")
    #expect(teacher.matchesSearch("smith"))
    #expect(teacher.matchesSearch("lecture"))
    #expect(!teacher.matchesSearch("biology"))
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -only-testing:'Events TrackerTests' test
```

Expected: fails because `CalendarEventItem`, `CoursePerson`, and related helpers do not exist.

- [ ] **Step 3: Implement model helpers**

Add the models and helpers in `DataStructure.swift` after `CourseSyllabus` and before `CourseAssignment`:

```swift
enum CoursePersonRole: String, Codable, CaseIterable, Hashable {
    case teacher
    case ta
    case student
    case observer
    case designer
    case other

    var label: String {
        switch self {
        case .teacher: return "Teacher"
        case .ta: return "TA"
        case .student: return "Student"
        case .observer: return "Observer"
        case .designer: return "Designer"
        case .other: return "Other"
        }
    }

    static func normalized(from rawValues: [String]) -> CoursePersonRole {
        let joined = rawValues.joined(separator: " ").lowercased()
        if joined.contains("teacher") { return .teacher }
        if joined.contains("ta") || joined.contains("assistant") { return .ta }
        if joined.contains("student") { return .student }
        if joined.contains("observer") { return .observer }
        if joined.contains("designer") { return .designer }
        return .other
    }
}

struct CoursePersonEnrollment: Codable, Hashable {
    let type: String?
    let role: String?
    let roleID: Int?
    let sectionID: Int?
    let sectionName: String?
    let enrollmentState: String?
    let lastActivityAt: Date?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case roleID = "role_id"
        case sectionID = "course_section_id"
        case sectionName = "course_section_name"
        case enrollmentState = "enrollment_state"
        case lastActivityAt = "last_activity_at"
    }
}

struct CoursePerson: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let sortableName: String?
    let shortName: String?
    let avatarURL: URL?
    let htmlURL: URL?
    let email: String?
    let loginID: String?
    let enrollments: [CoursePersonEnrollment]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortableName = "sortable_name"
        case shortName = "short_name"
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case email
        case loginID = "login_id"
        case enrollments
    }

    var primaryEnrollment: CoursePersonEnrollment? {
        enrollments?.first
    }

    var primaryRole: CoursePersonRole {
        CoursePersonRole.normalized(
            from: enrollments?.flatMap { [$0.type, $0.role].compactMap { $0 } } ?? []
        )
    }

    var roleLabel: String {
        primaryRole.label
    }

    var sectionLabel: String? {
        primaryEnrollment?.sectionName
    }

    var lastActivityAt: Date? {
        enrollments?.compactMap(\.lastActivityAt).max()
    }

    func matchesSearch(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        return [
            name,
            sortableName,
            shortName,
            email,
            loginID,
            sectionLabel,
            roleLabel
        ]
        .compactMap { $0 }
        .contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
    }
}

struct CalendarEventItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case upcoming(UpcomingEvent)
        case missing(MissingSubmission)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .upcoming(let event): return "upcoming-\(event.id)"
        case .missing(let submission): return "missing-\(submission.id)"
        }
    }

    var title: String {
        switch kind {
        case .upcoming(let event): return event.title
        case .missing(let submission): return submission.name
        }
    }

    var date: Date? {
        switch kind {
        case .upcoming(let event): return event.displayDate
        case .missing(let submission): return submission.dueAt
        }
    }

    var courseID: Int? {
        switch kind {
        case .upcoming(let event): return event.courseID
        case .missing(let submission): return submission.courseID
        }
    }

    var url: URL? {
        switch kind {
        case .upcoming(let event): return event.actionableURL
        case .missing(let submission): return submission.htmlURL
        }
    }

    var isMissing: Bool {
        if case .missing = kind { return true }
        return false
    }

    var isUpcoming: Bool {
        if case .upcoming = kind { return true }
        return false
    }

    static func items(
        upcomingEvents: [UpcomingEvent],
        missingSubmissions: [MissingSubmission]
    ) -> [CalendarEventItem] {
        (upcomingEvents.map { CalendarEventItem(kind: .upcoming($0)) }
            + missingSubmissions.map { CalendarEventItem(kind: .missing($0)) })
            .sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (left?, right?):
                    if left != right { return left < right }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    static func groupByDay(
        _ items: [CalendarEventItem],
        calendar: Calendar = .current
    ) -> [Date: [CalendarEventItem]] {
        Dictionary(grouping: items.compactMap { item -> (Date, CalendarEventItem)? in
            guard let date = item.date else {
                return nil
            }
            return (calendar.startOfDay(for: date), item)
        }, by: \.0)
        .mapValues { values in values.map(\.1) }
    }

    static func visibleMonthDays(
        containing date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastMonthDay = calendar.date(byAdding: DateComponents(day: -1), to: monthInterval.end),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastMonthDay)
        else {
            return []
        }

        var days: [Date] = []
        var current = calendar.startOfDay(for: firstWeek.start)
        let end = calendar.startOfDay(for: lastWeek.end)
        while current < end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        return days
    }
}
```

- [ ] **Step 4: Run model tests**

Run the same `xcodebuild ... -only-testing:'Events TrackerTests' test` command.

Expected: model tests compile and pass; unrelated failures should be investigated before continuing.

---

### Task 2: People Networking, Store, And Cache

**Files:**
- Modify: `Events TrackerTests/Events_TrackerTests.swift`
- Modify: `Events Tracker/Models/NetworkManager.swift`
- Modify: `Events Tracker/Models/CourseDetailCacheManager.swift`
- Modify: `Events Tracker/Models/CanvasStore.swift`

- [ ] **Step 1: Add failing network/cache tests**

Add tests that verify:

```swift
@Test func networkManagerFetchesCoursePeopleWithEnrollments() async throws {
    let session = makeCapturingURLSession { request in
        guard
            let url = request.url,
            url.path == "/api/v1/courses/42/users",
            url.query?.contains("include%5B%5D=enrollments") == true
        else {
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let data = """
        [
          {
            "id": 7,
            "name": "Dr. Smith",
            "sortable_name": "Smith, Dr.",
            "short_name": "Dr. Smith",
            "avatar_url": "https://canvas.example.edu/avatar.png",
            "html_url": "https://canvas.example.edu/courses/42/users/7",
            "enrollments": [
              {
                "type": "TeacherEnrollment",
                "role": "TeacherEnrollment",
                "course_section_name": "Lecture",
                "enrollment_state": "active"
              }
            ]
          }
        ]
        """.data(using: .utf8)!

        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }

    let manager = NetworkManager(session: session)
    let people = try await manager.fetchPeople(courseID: 42, using: makeCanvasConfig())

    #expect(people.count == 1)
    #expect(people.first?.primaryRole == .teacher)
    #expect(people.first?.sectionLabel == "Lecture")
}
```

Add a cache round-trip assertion by extending the existing course detail cache tests to save and reload `peopleByCourseID: [42: [teacher]]`.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -only-testing:'Events TrackerTests' test
```

Expected: fails because `fetchPeople` and cache fields do not exist.

- [ ] **Step 3: Implement `NetworkManager.fetchPeople`**

Add:

```swift
func fetchPeople(courseID: Int, using config: CanvasConfig) async throws -> [CoursePerson] {
    let people: [CoursePerson] = try await requestPaginatedArray(
        path: "/api/v1/courses/\(courseID)/users",
        queryItems: [
            URLQueryItem(name: "include[]", value: "enrollments"),
            URLQueryItem(name: "include[]", value: "avatar_url"),
            URLQueryItem(name: "per_page", value: "100")
        ],
        config: config
    )

    return people.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}
```

- [ ] **Step 4: Extend course detail cache**

Add `peopleByCourseID: [Int: [CoursePerson]]` to `CourseDetailCacheSnapshot`, initialize it in tests and call sites, include it in prune/apply checks, and keep default decoding compatibility by adding a custom `init(from:)` that defaults missing People data to `[:]`.

- [ ] **Step 5: Extend `CanvasStore`**

Add published state:

```swift
@Published private(set) var coursePeopleByCourseID: [Int: [CoursePerson]]
@Published private(set) var loadingCoursePeopleIDs: Set<Int>
```

Add accessors and loading methods matching existing assignment/module patterns:

```swift
func people(for courseID: Int?) -> [CoursePerson]
func isLoadingPeople(for courseID: Int?) -> Bool
func hasLoadedPeople(for courseID: Int?) -> Bool
func loadPeopleIfNeeded(for courseID: Int?) async
func loadPeople(for courseID: Int) async
```

Update `restoreCourseDetailCache`, `snapshotCourseDetailCache`, `applyCourseDetailCache`, `clearCourseDetailMemoryCache`, and cache pruning integration.

- [ ] **Step 6: Run tests**

Run the targeted test command again.

Expected: People network/cache/store changes compile and related tests pass.

---

### Task 3: Course People UI

**Files:**
- Create: `Events Tracker/Views/CoursePeopleView.swift`
- Modify: `Events Tracker/Views/CoursesView.swift`

- [ ] **Step 1: Add People tab wiring**

In `CourseWorkspaceSection`, add:

```swift
case people = "People"
```

Add selected course computed properties for People, pass them into a new `CoursePeopleContent`, and update the `.task(id:)` switch:

```swift
case .people:
    await store.loadPeopleIfNeeded(for: selectedCourse.id)
```

- [ ] **Step 2: Implement `CoursePeopleView.swift`**

Create `CoursePeopleContent` with:

- search field;
- role filter picker;
- sort picker for name, role, and recent activity;
- summary cards for total, teachers/TAs, students, and other;
- roster rows;
- detail sheet.

Use `SummaryCard`, `PillBadge`, and `SetupPromptView` from shared components. Display optional fields only when present.

- [ ] **Step 3: Run typecheck**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

Expected: typecheck succeeds or reports UI compile issues introduced in this task.

---

### Task 4: Events Calendar UI

**Files:**
- Modify: `Events Tracker/Views/EventsView.swift`

- [ ] **Step 1: Replace list-only state**

Add local state:

```swift
private enum EventsDisplayMode: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case week = "Week"
    case agenda = "Agenda"
    var id: String { rawValue }
}

@State private var displayMode: EventsDisplayMode = .calendar
@State private var selectedDate = Date()
@State private var visibleMonth = Date()
```

- [ ] **Step 2: Build combined item computations**

Use `CalendarEventItem.items(upcomingEvents:missingSubmissions:)` from filtered store data. Add computed properties for selected-day items, current-week items, undated items, and visible month days.

- [ ] **Step 3: Implement three modes**

Calendar mode: month grid with day cells, item count dots, missing badge, and selected-day detail panel.

Week mode: seven columns or stacked day cards depending available width; list items under each day.

Agenda mode: grouped chronological list with an attention section for missing/undated items.

Rows should reuse links and course names from `CalendarEventItem`.

- [ ] **Step 4: Run typecheck**

Run the same `xcrun swiftc -typecheck ...` command.

Expected: typecheck succeeds or reports issues introduced in `EventsView.swift`.

---

### Task 5: README Update

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update feature list**

Describe the app as a student Canvas companion with:

- Canvas connection and token storage;
- dashboard planner;
- assignments and grades;
- course workspace with overview/modules/announcements/syllabus/files/people/assignments/grades;
- calendar workspace;
- profile/settings;
- local cache and Telegram reminders.

- [ ] **Step 2: Update current direction**

Replace the outdated roadmap with:

- richer assignment workflows;
- native quiz/discussion/page detail views;
- Inbox/notifications;
- polish, filters, preferences, and cache clarity.

- [ ] **Step 3: Review README**

Read the README and verify it no longer claims modules/announcements/grades/People are future work after this implementation.

---

### Task 6: Final Verification

**Files:**
- All changed files

- [ ] **Step 1: Run lints for edited files**

Use IDE diagnostics for edited files and fix introduced issues.

- [ ] **Step 2: Run targeted tests**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -only-testing:'Events TrackerTests' test
```

Expected: unit tests pass. If environment or signing issues block the command, capture the exact failure.

- [ ] **Step 3: Run source typecheck**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

Expected: no compiler errors.

- [ ] **Step 4: Inspect git status**

Run:

```bash
git status --short
```

Expected: only planned files are modified.

---

## Self-Review

- Spec coverage: Events calendar, course-scoped People, caching, networking, README, errors, and tests are each mapped to tasks.
- Placeholder scan: no task contains unresolved placeholders for implementation behavior.
- Type consistency: `CoursePerson`, `CoursePersonEnrollment`, `CoursePersonRole`, `CalendarEventItem`, `fetchPeople`, and store People methods use the same names throughout.
