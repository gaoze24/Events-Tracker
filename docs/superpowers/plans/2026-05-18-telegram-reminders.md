# Telegram Assignment Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Telegram reminders for Canvas assignments that are due soon and still unsubmitted while the macOS app is running.

**Architecture:** Extend `CanvasConfig` with a nested Telegram reminder config, keep reminder de-duplication in a separate JSON history file, and add a small in-process `AssignmentReminderService` that periodically fetches Canvas assignments, filters reminder candidates, and sends Telegram messages. Keep deadline selection in `ReminderEvaluator` so most behavior is covered by unit tests without Canvas or Telegram network access.

**Tech Stack:** Swift 5, SwiftUI, Foundation `URLSession`, Swift Testing, existing macOS app target with file-system synchronized Xcode groups.

---

## File Structure

- Modify `Events Tracker/Models/DataStructure.swift`
  - Add `TelegramReminderConfig`.
  - Update `CanvasConfig` with custom Codable compatibility for older config files.
  - Add normalized/clamped helper properties used by Settings and the reminder service.
- Modify `Events Tracker/Models/CanvasConfigManager.swift`
  - Keep existing save/load API; no new config file path.
- Create `Events Tracker/Models/ReminderHistoryManager.swift`
  - Persist `[String: Date]` reminder history to Application Support.
- Create `Events Tracker/Models/ReminderEvaluator.swift`
  - Pure reminder filtering and message candidate generation.
- Create `Events Tracker/Models/TelegramManager.swift`
  - Telegram Bot API chat discovery and message sending.
- Create `Events Tracker/Models/AssignmentReminderService.swift`
  - In-app periodic reminder loop and send orchestration.
- Modify `Events Tracker/Models/CanvasStore.swift`
  - Own reminder service lifecycle.
  - Expose Telegram setup actions to Settings.
  - Update `saveConfiguration` to include Telegram reminder config.
- Modify `Events Tracker/Events_TrackerApp.swift`
  - Start reminder service when the app scene appears.
- Modify `Events Tracker/Views/SettingsView.swift`
  - Add Telegram reminder fields, chat wizard controls, test message button, and save wiring.
- Modify `Events TrackerTests/Events_TrackerTests.swift`
  - Add focused unit tests for config defaults, legacy config decoding, reminder selection, repeat suppression, and history keying.

New files under `Events Tracker/Models/` and test edits under `Events TrackerTests/` will be picked up by the project because the Xcode project uses `PBXFileSystemSynchronizedRootGroup`.

Do not create git commits unless the user explicitly asks for commits.

---

### Task 1: Telegram Config Model

**Files:**
- Modify: `Events Tracker/Models/DataStructure.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing config tests**

Append these tests inside `Events_TrackerTests`:

```swift
@Test func telegramReminderConfigDefaultsDisabledAndClampsRanges() async throws {
    let defaults = TelegramReminderConfig()

    #expect(!defaults.isEnabled)
    #expect(defaults.trimmedBotToken.isEmpty)
    #expect(defaults.trimmedChatID.isEmpty)
    #expect(defaults.normalizedReminderWindowHours == 24)
    #expect(defaults.normalizedCheckIntervalMinutes == 30)
    #expect(defaults.normalizedRepeatIntervalHours == 24)
    #expect(!defaults.isComplete)

    let config = TelegramReminderConfig(
        isEnabled: true,
        botToken: " 123:abc ",
        chatID: " 456 ",
        reminderWindowHours: 999,
        checkIntervalMinutes: 1,
        repeatIntervalHours: 0
    )

    #expect(config.trimmedBotToken == "123:abc")
    #expect(config.trimmedChatID == "456")
    #expect(config.normalizedReminderWindowHours == 168)
    #expect(config.normalizedCheckIntervalMinutes == 5)
    #expect(config.normalizedRepeatIntervalHours == 1)
    #expect(config.isComplete)
}

@Test func canvasConfigDecodesLegacyConfigWithoutTelegramSettings() async throws {
    let data = """
    {
      "baseURL" : "https://canvas.example.edu",
      "lookaheadDays" : 14,
      "token" : "abc123"
    }
    """.data(using: .utf8)!

    let config = try JSONDecoder().decode(CanvasConfig.self, from: data)

    #expect(config.normalizedBaseURL == "https://canvas.example.edu")
    #expect(config.trimmedToken == "abc123")
    #expect(config.telegramReminders == TelegramReminderConfig())
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -only-testing:'Events TrackerTests' test
```

Expected: fails because `TelegramReminderConfig` and `CanvasConfig.telegramReminders` do not exist.

- [ ] **Step 3: Implement config model**

In `DataStructure.swift`, replace the current `CanvasConfig` definition with:

```swift
struct TelegramReminderConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var botToken: String = ""
    var chatID: String = ""
    var reminderWindowHours: Int = 24
    var checkIntervalMinutes: Int = 30
    var repeatIntervalHours: Int = 24

    var trimmedBotToken: String {
        botToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedChatID: String {
        chatID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedReminderWindowHours: Int {
        min(max(reminderWindowHours, 1), 168)
    }

    var normalizedCheckIntervalMinutes: Int {
        min(max(checkIntervalMinutes, 5), 240)
    }

    var normalizedRepeatIntervalHours: Int {
        min(max(repeatIntervalHours, 1), 168)
    }

    var isComplete: Bool {
        !trimmedBotToken.isEmpty && !trimmedChatID.isEmpty
    }
}

struct CanvasConfig: Codable, Equatable {
    var baseURL: String = ""
    var token: String = ""
    var lookaheadDays: Int = 14
    var telegramReminders: TelegramReminderConfig = TelegramReminderConfig()

    enum CodingKeys: String, CodingKey {
        case baseURL
        case token
        case lookaheadDays
        case telegramReminders
    }

    init(
        baseURL: String = "",
        token: String = "",
        lookaheadDays: Int = 14,
        telegramReminders: TelegramReminderConfig = TelegramReminderConfig()
    ) {
        self.baseURL = baseURL
        self.token = token
        self.lookaheadDays = lookaheadDays
        self.telegramReminders = telegramReminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        lookaheadDays = try container.decodeIfPresent(Int.self, forKey: .lookaheadDays) ?? 14
        telegramReminders = try container.decodeIfPresent(
            TelegramReminderConfig.self,
            forKey: .telegramReminders
        ) ?? TelegramReminderConfig()
    }

    var normalizedBaseURL: String {
        baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isComplete: Bool {
        !normalizedBaseURL.isEmpty && !trimmedToken.isEmpty
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run the same targeted test command.

Expected: config tests pass; any unrelated failures should be investigated before continuing.

- [ ] **Step 5: Checkpoint**

Run:

```bash
git diff -- 'Events Tracker/Models/DataStructure.swift' 'Events TrackerTests/Events_TrackerTests.swift'
```

Expected: only the config model and config tests changed.

---

### Task 2: Reminder History Storage

**Files:**
- Create: `Events Tracker/Models/ReminderHistoryManager.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing history test**

Append this test inside `Events_TrackerTests`:

```swift
@Test func reminderHistoryKeysCombineCourseAndAssignmentIDs() async throws {
    let key = ReminderHistoryManager.historyKey(courseID: 12, assignmentID: 34)

    #expect(key == "12:34")
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -only-testing:'Events TrackerTests' test
```

Expected: fails because `ReminderHistoryManager` does not exist.

- [ ] **Step 3: Add history manager**

Create `Events Tracker/Models/ReminderHistoryManager.swift`:

```swift
//
//  ReminderHistoryManager.swift
//  Events Tracker
//

import Foundation

final class ReminderHistoryManager {
    static let shared = ReminderHistoryManager()

    private let historyURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(historyURL: URL? = nil) {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.historyURL = historyURL ?? appDirectory.appendingPathComponent("telegram-reminder-history.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    static func historyKey(courseID: Int, assignmentID: Int) -> String {
        "\(courseID):\(assignmentID)"
    }

    func loadHistory() -> [String: Date] {
        guard let data = try? Data(contentsOf: historyURL) else {
            return [:]
        }

        return (try? decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    func saveHistory(_ history: [String: Date]) throws {
        let data = try encoder.encode(history)
        try data.write(to: historyURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run the targeted unit test command.

Expected: history key test passes.

- [ ] **Step 5: Checkpoint**

Run:

```bash
git diff -- 'Events Tracker/Models/ReminderHistoryManager.swift' 'Events TrackerTests/Events_TrackerTests.swift'
```

Expected: new history manager and one focused test.

---

### Task 3: Reminder Evaluator

**Files:**
- Create: `Events Tracker/Models/ReminderEvaluator.swift`
- Test: `Events TrackerTests/Events_TrackerTests.swift`

- [ ] **Step 1: Write failing evaluator tests**

Append these tests inside `Events_TrackerTests`:

```swift
@Test func reminderEvaluatorSelectsDueSoonUnsubmittedAssignments() async throws {
    let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
    let dueSoon = Date(timeInterval: 3_600, since: referenceDate)
    let later = Date(timeInterval: 90_000, since: referenceDate)
    let config = TelegramReminderConfig(
        isEnabled: true,
        botToken: "123:abc",
        chatID: "456",
        reminderWindowHours: 24,
        checkIntervalMinutes: 30,
        repeatIntervalHours: 24
    )

    let candidates = ReminderEvaluator.reminderCandidates(
        assignments: [
            makeCourseAssignment(id: 1, name: "Due Soon", dueAt: dueSoon, courseID: 10),
            makeCourseAssignment(id: 2, name: "Later", dueAt: later, courseID: 10),
            makeCourseAssignment(id: 3, name: "No Due Date", dueAt: nil, courseID: 10)
        ],
        courseNamesByID: [10: "Biology"],
        config: config,
        reminderHistory: [:],
        referenceDate: referenceDate
    )

    #expect(candidates.map(\.assignmentID) == [1])
    #expect(candidates.first?.courseName == "Biology")
    #expect(candidates.first?.historyKey == "10:1")
}

@Test func reminderEvaluatorSkipsSubmittedGradedExcusedAndRecentlyRemindedAssignments() async throws {
    let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
    let dueSoon = Date(timeInterval: 3_600, since: referenceDate)
    let config = TelegramReminderConfig(
        isEnabled: true,
        botToken: "123:abc",
        chatID: "456",
        reminderWindowHours: 24,
        checkIntervalMinutes: 30,
        repeatIntervalHours: 24
    )

    let recentlyRemindedKey = ReminderHistoryManager.historyKey(courseID: 10, assignmentID: 4)
    let candidates = ReminderEvaluator.reminderCandidates(
        assignments: [
            makeCourseAssignment(
                id: 1,
                name: "Submitted",
                dueAt: dueSoon,
                courseID: 10,
                submission: makeSubmission(workflowState: "submitted")
            ),
            makeCourseAssignment(
                id: 2,
                name: "Graded",
                dueAt: dueSoon,
                courseID: 10,
                submission: makeSubmission(gradedAt: referenceDate, workflowState: "graded")
            ),
            makeCourseAssignment(
                id: 3,
                name: "Excused",
                dueAt: dueSoon,
                courseID: 10,
                submission: makeSubmission(excused: true)
            ),
            makeCourseAssignment(id: 4, name: "Recent", dueAt: dueSoon, courseID: 10),
            makeCourseAssignment(id: 5, name: "Allowed", dueAt: dueSoon, courseID: 10)
        ],
        courseNamesByID: [10: "Biology"],
        config: config,
        reminderHistory: [
            recentlyRemindedKey: Date(timeInterval: -3_600, since: referenceDate)
        ],
        referenceDate: referenceDate
    )

    #expect(candidates.map(\.assignmentID) == [5])
}
```

Add these helpers inside `Events_TrackerTests`:

```swift
private func makeCourseAssignment(
    id: Int,
    name: String,
    dueAt: Date?,
    courseID: Int?,
    submission: AssignmentSubmission? = nil
) -> CourseAssignment {
    CourseAssignment(
        id: id,
        name: name,
        details: nil,
        dueAt: dueAt,
        unlockAt: nil,
        lockAt: nil,
        htmlURL: URL(string: "https://canvas.example.edu/courses/\(courseID ?? 0)/assignments/\(id)"),
        courseID: courseID,
        pointsPossible: 10,
        submissionTypes: ["online_upload"],
        hasSubmittedSubmissions: false,
        published: true,
        gradingType: "points",
        submission: submission
    )
}

private func makeSubmission(
    submittedAt: Date? = nil,
    gradedAt: Date? = nil,
    workflowState: String? = nil,
    late: Bool? = false,
    missing: Bool? = false,
    excused: Bool? = false
) -> AssignmentSubmission {
    AssignmentSubmission(
        submittedAt: submittedAt,
        gradedAt: gradedAt,
        score: nil,
        grade: nil,
        workflowState: workflowState,
        late: late,
        missing: missing,
        excused: excused,
        submissionType: "online_upload",
        attempt: nil
    )
}
```

- [ ] **Step 2: Run tests and verify failure**

Run the targeted unit test command.

Expected: fails because `ReminderEvaluator` and `ReminderCandidate` do not exist.

- [ ] **Step 3: Add evaluator**

Create `Events Tracker/Models/ReminderEvaluator.swift`:

```swift
//
//  ReminderEvaluator.swift
//  Events Tracker
//

import Foundation

struct ReminderCandidate: Identifiable, Hashable {
    let id: String
    let historyKey: String
    let assignmentID: Int
    let assignmentName: String
    let courseID: Int
    let courseName: String
    let dueAt: Date
    let htmlURL: URL?

    init(assignment: CourseAssignment, courseName: String, dueAt: Date, historyKey: String) {
        let courseID = assignment.courseID ?? 0
        self.id = historyKey
        self.historyKey = historyKey
        self.assignmentID = assignment.id
        self.assignmentName = assignment.name
        self.courseID = courseID
        self.courseName = courseName
        self.dueAt = dueAt
        self.htmlURL = assignment.htmlURL
    }
}

enum ReminderEvaluator {
    static func reminderCandidates(
        assignments: [CourseAssignment],
        courseNamesByID: [Int: String],
        config: TelegramReminderConfig,
        reminderHistory: [String: Date],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderCandidate] {
        guard config.isEnabled, config.isComplete else {
            return []
        }

        guard let windowEnd = calendar.date(
            byAdding: .hour,
            value: config.normalizedReminderWindowHours,
            to: referenceDate
        ) else {
            return []
        }

        return assignments.compactMap { assignment in
            guard
                let courseID = assignment.courseID,
                let dueAt = assignment.dueAt,
                dueAt >= referenceDate,
                dueAt <= windowEnd,
                !assignment.isCompleted
            else {
                return nil
            }

            let historyKey = ReminderHistoryManager.historyKey(courseID: courseID, assignmentID: assignment.id)
            if isSuppressed(
                historyKey: historyKey,
                reminderHistory: reminderHistory,
                config: config,
                referenceDate: referenceDate,
                calendar: calendar
            ) {
                return nil
            }

            return ReminderCandidate(
                assignment: assignment,
                courseName: courseNamesByID[courseID] ?? "Course \(courseID)",
                dueAt: dueAt,
                historyKey: historyKey
            )
        }
        .sorted { lhs, rhs in
            if lhs.dueAt != rhs.dueAt {
                return lhs.dueAt < rhs.dueAt
            }

            return lhs.assignmentName.localizedCaseInsensitiveCompare(rhs.assignmentName) == .orderedAscending
        }
    }

    private static func isSuppressed(
        historyKey: String,
        reminderHistory: [String: Date],
        config: TelegramReminderConfig,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard
            let lastSentAt = reminderHistory[historyKey],
            let nextAllowedAt = calendar.date(
                byAdding: .hour,
                value: config.normalizedRepeatIntervalHours,
                to: lastSentAt
            )
        else {
            return false
        }

        return nextAllowedAt > referenceDate
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run the targeted unit test command.

Expected: evaluator tests pass.

- [ ] **Step 5: Checkpoint**

Run:

```bash
git diff -- 'Events Tracker/Models/ReminderEvaluator.swift' 'Events TrackerTests/Events_TrackerTests.swift'
```

Expected: evaluator and tests only.

---

### Task 4: Telegram Bot API Client

**Files:**
- Create: `Events Tracker/Models/TelegramManager.swift`
- Modify: `Events Tracker/Models/NetworkManager.swift` is not needed.

- [ ] **Step 1: Add Telegram API types and client**

Create `Events Tracker/Models/TelegramManager.swift`:

```swift
//
//  TelegramManager.swift
//  Events Tracker
//

import Foundation

enum TelegramServiceError: LocalizedError {
    case incompleteConfiguration
    case invalidBotToken
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .incompleteConfiguration:
            return "Add a Telegram bot token and chat before enabling reminders."
        case .invalidBotToken:
            return "Telegram bot token is invalid. Check the token from BotFather and try again."
        case .requestFailed(let message):
            return "Telegram request failed: \(message)"
        case .invalidResponse:
            return "Telegram returned an unexpected response."
        }
    }
}

struct TelegramChat: Identifiable, Hashable {
    let id: String
    let title: String

    var displayName: String {
        title.isEmpty ? id : "\(title) (\(id))"
    }
}

final class TelegramManager {
    static let shared = TelegramManager()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchRecentChats(botToken: String) async throws -> [TelegramChat] {
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw TelegramServiceError.incompleteConfiguration
        }

        let response: TelegramResponse<[TelegramUpdate]> = try await request(
            botToken: token,
            method: "getUpdates",
            queryItems: []
        )

        var chatsByID: [String: TelegramChat] = [:]
        for update in response.result {
            guard let chat = update.message?.chat ?? update.channelPost?.chat else {
                continue
            }

            chatsByID[String(chat.id)] = TelegramChat(
                id: String(chat.id),
                title: chat.displayTitle
            )
        }

        return chatsByID.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func sendMessage(botToken: String, chatID: String, text: String) async throws {
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatID = chatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !chatID.isEmpty else {
            throw TelegramServiceError.incompleteConfiguration
        }

        let _: TelegramResponse<TelegramMessage> = try await request(
            botToken: token,
            method: "sendMessage",
            queryItems: [
                URLQueryItem(name: "chat_id", value: chatID),
                URLQueryItem(name: "text", value: text),
                URLQueryItem(name: "disable_web_page_preview", value: "false")
            ]
        )
    }

    private func request<T: Decodable>(
        botToken: String,
        method: String,
        queryItems: [URLQueryItem]
    ) async throws -> TelegramResponse<T> {
        guard var components = URLComponents(string: "https://api.telegram.org/bot\(botToken)/\(method)") else {
            throw TelegramServiceError.invalidBotToken
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw TelegramServiceError.invalidBotToken
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TelegramServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? decoder.decode(TelegramErrorResponse.self, from: data)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 404 {
                throw TelegramServiceError.invalidBotToken
            }

            throw TelegramServiceError.requestFailed(errorResponse?.description ?? "HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try decoder.decode(TelegramResponse<T>.self, from: data)
            guard decoded.ok else {
                throw TelegramServiceError.requestFailed(decoded.description ?? "Unknown Telegram error")
            }

            return decoded
        } catch let error as TelegramServiceError {
            throw error
        } catch {
            throw TelegramServiceError.invalidResponse
        }
    }
}

private struct TelegramResponse<T: Decodable>: Decodable {
    let ok: Bool
    let result: T
    let description: String?
}

private struct TelegramErrorResponse: Decodable {
    let ok: Bool
    let description: String?
}

private struct TelegramUpdate: Decodable {
    let message: TelegramMessage?
    let channelPost: TelegramMessage?

    enum CodingKeys: String, CodingKey {
        case message
        case channelPost = "channel_post"
    }
}

private struct TelegramMessage: Decodable {
    let chat: TelegramChatPayload
}

private struct TelegramChatPayload: Decodable {
    let id: Int64
    let type: String?
    let title: String?
    let username: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case username
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }

        if let username, !username.isEmpty {
            return "@\(username)"
        }

        return [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
```

- [ ] **Step 2: Typecheck**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

Expected: typecheck passes or reports only issues introduced in this task.

- [ ] **Step 3: Checkpoint**

Run:

```bash
git diff -- 'Events Tracker/Models/TelegramManager.swift'
```

Expected: Telegram API client only.

---

### Task 5: Assignment Reminder Service

**Files:**
- Create: `Events Tracker/Models/AssignmentReminderService.swift`
- Modify: `Events Tracker/Models/CanvasStore.swift`
- Modify: `Events Tracker/Events_TrackerApp.swift`

- [ ] **Step 1: Add reminder service**

Create `Events Tracker/Models/AssignmentReminderService.swift`:

```swift
//
//  AssignmentReminderService.swift
//  Events Tracker
//

import Foundation

@MainActor
final class AssignmentReminderService: ObservableObject {
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastCheckedAt: Date?

    private let networkManager: NetworkManager
    private let telegramManager: TelegramManager
    private let historyManager: ReminderHistoryManager
    private var config: CanvasConfig
    private var reminderTask: Task<Void, Never>?
    private var isChecking = false

    init(
        config: CanvasConfig,
        networkManager: NetworkManager = .shared,
        telegramManager: TelegramManager = .shared,
        historyManager: ReminderHistoryManager = .shared
    ) {
        self.config = config
        self.networkManager = networkManager
        self.telegramManager = telegramManager
        self.historyManager = historyManager
    }

    func start() {
        guard reminderTask == nil else {
            return
        }

        reminderTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        reminderTask?.cancel()
        reminderTask = nil
        isChecking = false
    }

    func updateConfig(_ config: CanvasConfig) {
        self.config = config
    }

    func runCheckNow() async {
        guard !isChecking else {
            return
        }

        isChecking = true
        defer {
            isChecking = false
        }

        let currentConfig = config
        guard currentConfig.isComplete, currentConfig.telegramReminders.isEnabled, currentConfig.telegramReminders.isComplete else {
            lastErrorMessage = nil
            lastCheckedAt = Date()
            return
        }

        do {
            let courses = try await networkManager.fetchCourses(using: currentConfig)
            let courseNamesByID = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name) })
            var assignments: [CourseAssignment] = []

            for course in courses {
                assignments += try await networkManager.fetchAssignments(courseID: course.id, using: currentConfig)
            }

            var history = historyManager.loadHistory()
            let candidates = ReminderEvaluator.reminderCandidates(
                assignments: assignments,
                courseNamesByID: courseNamesByID,
                config: currentConfig.telegramReminders,
                reminderHistory: history,
                referenceDate: Date()
            )

            for candidate in candidates {
                try await telegramManager.sendMessage(
                    botToken: currentConfig.telegramReminders.trimmedBotToken,
                    chatID: currentConfig.telegramReminders.trimmedChatID,
                    text: Self.messageText(for: candidate)
                )
                history[candidate.historyKey] = Date()
                try historyManager.saveHistory(history)
            }

            lastCheckedAt = Date()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await runCheckNow()

            let minutes = config.telegramReminders.normalizedCheckIntervalMinutes
            let nanoseconds = UInt64(minutes) * 60 * 1_000_000_000
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    private static func messageText(for candidate: ReminderCandidate) -> String {
        let dueText = DateFormatter.telegramReminderFormatter.string(from: candidate.dueAt)
        var lines = [
            "Upcoming Canvas deadline",
            "",
            "Course: \(candidate.courseName)",
            "Assignment: \(candidate.assignmentName)",
            "Due: \(dueText)",
            "Status: Not submitted"
        ]

        if let htmlURL = candidate.htmlURL {
            lines.append("Link: \(htmlURL.absoluteString)")
        }

        return lines.joined(separator: "\n")
    }
}

private extension DateFormatter {
    static let telegramReminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
```

- [ ] **Step 2: Wire service into store**

In `CanvasStore.swift`:

1. Add a property near the managers:

```swift
    private let reminderService: AssignmentReminderService
```

2. Initialize it in `init` after `savedConfig` is loaded:

```swift
        reminderService = AssignmentReminderService(
            config: savedConfig,
            networkManager: networkManager,
            telegramManager: .shared,
            historyManager: .shared
        )
```

3. Add methods before `private func applySnapshot`:

```swift
    func startTelegramReminderService() {
        reminderService.start()
    }

    func stopTelegramReminderService() {
        reminderService.stop()
    }

    func runTelegramReminderCheckNow() async {
        await reminderService.runCheckNow()
        errorMessage = reminderService.lastErrorMessage
    }

    func discoverTelegramChats(botToken: String) async throws -> [TelegramChat] {
        try await TelegramManager.shared.fetchRecentChats(botToken: botToken)
    }

    func sendTelegramTestMessage(botToken: String, chatID: String) async throws {
        try await TelegramManager.shared.sendMessage(
            botToken: botToken,
            chatID: chatID,
            text: "Events Tracker Telegram reminders are connected."
        )
    }
```

4. In `saveConfiguration`, after `config = updatedConfig`, add:

```swift
        reminderService.updateConfig(updatedConfig)
```

5. Update the `saveConfiguration` signature in Task 6 to accept Telegram settings before compiling this file.

- [ ] **Step 3: Start service from app**

In `Events_TrackerApp.swift`, update the task:

```swift
                .task {
                    store.startTelegramReminderService()
                    await store.refreshIfNeeded()
                }
```

- [ ] **Step 4: Typecheck after Task 6 signature update**

Do not run typecheck until Task 6 updates `saveConfiguration` signature and call sites.

- [ ] **Step 5: Checkpoint**

Run:

```bash
git diff -- 'Events Tracker/Models/AssignmentReminderService.swift' 'Events Tracker/Models/CanvasStore.swift' 'Events Tracker/Events_TrackerApp.swift'
```

Expected: reminder service and lifecycle wiring only.

---

### Task 6: Settings UI and Save Flow

**Files:**
- Modify: `Events Tracker/Views/SettingsView.swift`
- Modify: `Events Tracker/Models/CanvasStore.swift`

- [ ] **Step 1: Extend Settings state**

In `SettingsView.swift`, add these `@State` properties below the current Canvas fields:

```swift
    @State private var telegramRemindersEnabled = false
    @State private var telegramBotToken = ""
    @State private var telegramChatID = ""
    @State private var telegramReminderWindowHours = 24
    @State private var telegramCheckIntervalMinutes = 30
    @State private var telegramRepeatIntervalHours = 24
    @State private var telegramChats: [TelegramChat] = []
    @State private var selectedTelegramChatID = ""
    @State private var isLoadingTelegramChats = false
    @State private var isSendingTelegramTest = false
```

- [ ] **Step 2: Add Telegram section to the form**

Insert this section after `Canvas Connection`:

```swift
                    Section("Telegram Reminders") {
                        Toggle("Enable Telegram reminders", isOn: $telegramRemindersEnabled)

                        SecureField("Bot Token", text: $telegramBotToken)
                            .textFieldStyle(.roundedBorder)

                        TextField("Chat ID", text: $telegramChatID)
                            .textFieldStyle(.roundedBorder)

                        Stepper(value: $telegramReminderWindowHours, in: 1...168) {
                            Text("Remind about assignments due within \(telegramReminderWindowHours) hours")
                        }

                        Stepper(value: $telegramCheckIntervalMinutes, in: 5...240, step: 5) {
                            Text("Check every \(telegramCheckIntervalMinutes) minutes while the app is open")
                        }

                        Stepper(value: $telegramRepeatIntervalHours, in: 1...168) {
                            Text("Repeat the same assignment reminder after \(telegramRepeatIntervalHours) hours")
                        }

                        Text("Reminders only run while Events Tracker is open. Minimized windows still count as open.")
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                await loadTelegramChats()
                            }
                        } label: {
                            if isLoadingTelegramChats {
                                ProgressView()
                            } else {
                                Text("Load Recent Telegram Chats")
                            }
                        }
                        .disabled(telegramBotToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingTelegramChats)

                        if !telegramChats.isEmpty {
                            Picker("Recent Chats", selection: $selectedTelegramChatID) {
                                ForEach(telegramChats) { chat in
                                    Text(chat.displayName).tag(chat.id)
                                }
                            }

                            Button("Use Selected Chat") {
                                telegramChatID = selectedTelegramChatID
                            }
                            .disabled(selectedTelegramChatID.isEmpty)
                        }

                        Button {
                            Task {
                                await sendTelegramTestMessage()
                            }
                        } label: {
                            if isSendingTelegramTest {
                                ProgressView()
                            } else {
                                Text("Send Test Message")
                            }
                        }
                        .disabled(
                            telegramBotToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSendingTelegramTest
                        )
                    }
```

- [ ] **Step 3: Populate Telegram fields**

In `populateFieldsIfNeeded`, after existing Canvas field assignments, add:

```swift
        let telegramConfig = store.config.telegramReminders
        telegramRemindersEnabled = telegramConfig.isEnabled
        telegramBotToken = telegramConfig.botToken
        telegramChatID = telegramConfig.chatID
        selectedTelegramChatID = telegramConfig.chatID
        telegramReminderWindowHours = telegramConfig.normalizedReminderWindowHours
        telegramCheckIntervalMinutes = telegramConfig.normalizedCheckIntervalMinutes
        telegramRepeatIntervalHours = telegramConfig.normalizedRepeatIntervalHours
```

- [ ] **Step 4: Update store save signature**

In `CanvasStore.swift`, replace `saveConfiguration(baseURL:token:lookaheadDays:)` with:

```swift
    @discardableResult
    func saveConfiguration(
        baseURL: String,
        token: String,
        lookaheadDays: Int,
        telegramReminders: TelegramReminderConfig
    ) throws -> Bool {
        let updatedConfig = CanvasConfig(
            baseURL: baseURL,
            token: token,
            lookaheadDays: lookaheadDays,
            telegramReminders: telegramReminders
        )

        let credentialsChanged = updatedConfig.normalizedBaseURL != config.normalizedBaseURL
            || updatedConfig.trimmedToken != config.trimmedToken

        try configManager.saveConfig(updatedConfig)
        config = updatedConfig
        reminderService.updateConfig(updatedConfig)
        errorMessage = nil

        if credentialsChanged {
            clearLocalData()
        }

        return credentialsChanged
    }
```

- [ ] **Step 5: Update Settings save call**

In `SettingsView.saveConfiguration`, replace the store call with:

```swift
            let telegramConfig = TelegramReminderConfig(
                isEnabled: telegramRemindersEnabled,
                botToken: telegramBotToken,
                chatID: telegramChatID,
                reminderWindowHours: telegramReminderWindowHours,
                checkIntervalMinutes: telegramCheckIntervalMinutes,
                repeatIntervalHours: telegramRepeatIntervalHours
            )

            let credentialsChanged = try store.saveConfiguration(
                baseURL: baseURL,
                token: token,
                lookaheadDays: lookaheadDays,
                telegramReminders: telegramConfig
            )
```

- [ ] **Step 6: Add Settings async helpers**

Add these methods inside `SettingsView`:

```swift
    private func loadTelegramChats() async {
        isLoadingTelegramChats = true
        defer {
            isLoadingTelegramChats = false
        }

        do {
            let chats = try await store.discoverTelegramChats(botToken: telegramBotToken)
            telegramChats = chats
            selectedTelegramChatID = chats.first?.id ?? ""
            statusMessage = chats.isEmpty
                ? "No recent Telegram chats found. Send a message to your bot, then load chats again."
                : "Loaded \(chats.count) recent Telegram chat\(chats.count == 1 ? "" : "s")."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func sendTelegramTestMessage() async {
        isSendingTelegramTest = true
        defer {
            isSendingTelegramTest = false
        }

        do {
            try await store.sendTelegramTestMessage(
                botToken: telegramBotToken,
                chatID: telegramChatID
            )
            statusMessage = "Telegram test message sent."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
```

- [ ] **Step 7: Typecheck**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

Expected: typecheck passes. If the compiler complains about `ReminderHistoryManager.shared` with a custom initializer, make `shared` explicit and keep the initializer internal as written.

- [ ] **Step 8: Checkpoint**

Run:

```bash
git diff -- 'Events Tracker/Views/SettingsView.swift' 'Events Tracker/Models/CanvasStore.swift'
```

Expected: Settings UI and save flow only.

---

### Task 7: Final Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run unit tests**

Run:

```bash
xcodebuild -project 'Events Tracker.xcodeproj' -scheme 'Events Tracker' -destination 'platform=macOS' -only-testing:'Events TrackerTests' test
```

Expected: all unit tests pass.

- [ ] **Step 2: Run source typecheck**

Run:

```bash
xcrun swiftc -typecheck -module-cache-path /tmp/swift-module-cache -sdk $(xcrun --show-sdk-path --sdk macosx) -target arm64-apple-macos15.0 -module-name Events_Tracker 'Events Tracker/Events_TrackerApp.swift' 'Events Tracker/Models/'*.swift 'Events Tracker/Views/'*.swift
```

Expected: typecheck passes.

- [ ] **Step 3: Read lints**

Use the IDE lints for:

- `Events Tracker/Models/DataStructure.swift`
- `Events Tracker/Models/ReminderHistoryManager.swift`
- `Events Tracker/Models/ReminderEvaluator.swift`
- `Events Tracker/Models/TelegramManager.swift`
- `Events Tracker/Models/AssignmentReminderService.swift`
- `Events Tracker/Models/CanvasStore.swift`
- `Events Tracker/Views/SettingsView.swift`
- `Events Tracker/Events_TrackerApp.swift`
- `Events TrackerTests/Events_TrackerTests.swift`

Expected: no new diagnostics from these changes.

- [ ] **Step 4: Manual smoke test**

In Xcode or the built app:

1. Open Settings.
2. Confirm existing Canvas URL/token/lookahead fields still populate.
3. Enter a Telegram bot token.
4. Send a message to the bot from Telegram.
5. Click `Load Recent Telegram Chats`.
6. Select the chat and click `Use Selected Chat`.
7. Click `Send Test Message`.
8. Save configuration.
9. Leave the app open and minimized; confirm reminders are eligible to run on the configured check interval.

Expected: Settings saves without clearing Canvas cache unless Canvas URL/token changed; test message appears in Telegram.

- [ ] **Step 5: Final git diff review**

Run:

```bash
git status --short
git diff -- 'Events Tracker' 'Events TrackerTests' 'docs/superpowers'
```

Expected: only intended source, tests, and docs changes are present. Do not stage `.DS_Store`, `.build`, or local build artifacts.
