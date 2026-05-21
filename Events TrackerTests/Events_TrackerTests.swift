//
//  Events_TrackerTests.swift
//  Events TrackerTests
//
//  Created by Eddie Gao on 24/3/25.
//

import Foundation
import Testing
@testable import Events_Tracker

@Suite(.serialized)
struct Events_TrackerTests {
    @Test func configNormalizationTrimsWhitespace() async throws {
        let config = CanvasConfig(
            baseURL: " https://canvas.example.edu/ ",
            token: " abc123 ",
            lookaheadDays: 21
        )

        #expect(config.normalizedBaseURL == "https://canvas.example.edu")
        #expect(config.trimmedToken == "abc123")
        #expect(config.isComplete)
    }

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

    @Test func reminderHistoryKeysCombineCourseAndAssignmentIDs() async throws {
        let key = ReminderHistoryManager.historyKey(courseID: 12, assignmentID: 34)

        #expect(key == "12:34")
    }

    @Test func reminderHistorySaveLoadRoundTripPreservesDates() async throws {
        let historyURL = makeReminderHistoryTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: historyURL)
        defer { try? fileManager.removeItem(at: historyURL) }

        let history = [
            ReminderHistoryManager.historyKey(courseID: 12, assignmentID: 34): Date(timeIntervalSince1970: 1_710_000_000),
            ReminderHistoryManager.historyKey(courseID: 56, assignmentID: 78): Date(timeIntervalSince1970: 1_720_000_000)
        ]

        let manager = ReminderHistoryManager(historyURL: historyURL)
        try manager.saveHistory(history)

        #expect(manager.loadHistory() == history)
    }

    @Test func reminderHistoryMissingFileReturnsEmptyHistory() async throws {
        let historyURL = makeReminderHistoryTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: historyURL)
        defer { try? fileManager.removeItem(at: historyURL) }

        let manager = ReminderHistoryManager(historyURL: historyURL)

        #expect(manager.loadHistory() == [:])
    }

    @Test func reminderHistoryCorruptJSONReturnsEmptyHistory() async throws {
        let historyURL = makeReminderHistoryTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: historyURL)
        defer { try? fileManager.removeItem(at: historyURL) }

        try Data("{ corrupt json".utf8).write(to: historyURL, options: .atomic)

        let manager = ReminderHistoryManager(historyURL: historyURL)

        #expect(manager.loadHistory() == [:])
    }

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

    @Test func reminderEvaluatorSkipsUnpublishedAndNonActionableSubmissionTypes() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let config = makeTelegramReminderConfig()

        let candidates = ReminderEvaluator.reminderCandidates(
            assignments: [
                makeCourseAssignment(
                    id: 1,
                    name: "Unpublished",
                    dueAt: Date(timeInterval: 3_600, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["online_upload"],
                    published: false
                ),
                makeCourseAssignment(
                    id: 2,
                    name: "No Submission Types",
                    dueAt: Date(timeInterval: 7_200, since: referenceDate),
                    courseID: 10,
                    submissionTypes: nil
                ),
                makeCourseAssignment(
                    id: 3,
                    name: "On Paper",
                    dueAt: Date(timeInterval: 10_800, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["on_paper"]
                ),
                makeCourseAssignment(
                    id: 4,
                    name: "No Submission",
                    dueAt: Date(timeInterval: 14_400, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["none"]
                ),
                makeCourseAssignment(
                    id: 5,
                    name: "Online Text",
                    dueAt: Date(timeInterval: 18_000, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["online_text_entry"]
                ),
                makeCourseAssignment(
                    id: 6,
                    name: "Online URL",
                    dueAt: Date(timeInterval: 21_600, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["online_url"]
                ),
                makeCourseAssignment(
                    id: 7,
                    name: "Online Quiz",
                    dueAt: Date(timeInterval: 25_200, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["online_quiz"]
                ),
                makeCourseAssignment(
                    id: 8,
                    name: "Discussion",
                    dueAt: Date(timeInterval: 28_800, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["discussion_topic"]
                ),
                makeCourseAssignment(
                    id: 9,
                    name: "External Tool",
                    dueAt: Date(timeInterval: 32_400, since: referenceDate),
                    courseID: 10,
                    submissionTypes: ["external_tool"]
                )
            ],
            courseNamesByID: [10: "Biology"],
            config: config,
            reminderHistory: [:],
            referenceDate: referenceDate
        )

        #expect(candidates.map(\.assignmentID) == [5, 6, 7, 8, 9])
    }

    @Test func telegramManagerSendsMessagesAsPostFormBody() async throws {
        let session = makeCapturingURLSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"ok":true,"result":{"chat":{"id":456}}}"#.utf8)
            return (response, data)
        }
        let manager = TelegramManager(session: session)
        let message = "Hello from Events Tracker & friends"

        try await manager.sendMessage(botToken: "123:abc", chatID: "456", text: message)

        let request = try #require(CapturingURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.query == nil)

        let body = try #require(httpBodyData(from: request))
        let bodyItems = formBodyItems(from: body)
        #expect(bodyItems["chat_id"] == "456")
        #expect(bodyItems["text"] == message)
        #expect(bodyItems["disable_web_page_preview"] == "false")
    }

    @Test func telegramChatSelectionStateClearsStaleChatsWhenTokenChangesOrDiscoveryFails() async throws {
        var state = TelegramChatSelectionState(
            chats: [TelegramChat(id: "111", title: "Old Chat")],
            selectedChatID: "111"
        )

        state.clearIfBotTokenChanged(from: "old-token", to: "new-token")

        #expect(state.chats.isEmpty)
        #expect(state.selectedChatID.isEmpty)

        state.applyDiscoveredChats([TelegramChat(id: "222", title: "New Chat")], botToken: "new-token")
        state.clearAfterDiscoveryFailure()

        #expect(state.chats.isEmpty)
        #expect(state.selectedChatID.isEmpty)
    }

    @MainActor
    @Test func assignmentReminderServiceStartsAndStopsWithReminderConfig() async throws {
        let service = AssignmentReminderService(config: makeCanvasConfig(telegramReminders: makeTelegramReminderConfig(isEnabled: false)))

        service.start()
        #expect(!hasActiveReminderTask(in: service))

        service.updateConfig(makeCanvasConfig(telegramReminders: makeTelegramReminderConfig(isEnabled: true)))
        #expect(hasActiveReminderTask(in: service))

        service.updateConfig(makeCanvasConfig(telegramReminders: makeTelegramReminderConfig(isEnabled: false)))
        #expect(!hasActiveReminderTask(in: service))
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

    @Test func canvasConfigDecodesPartialNestedTelegramSettingsWithDefaults() async throws {
        let data = """
        {
          "baseURL" : "https://canvas.example.edu",
          "lookaheadDays" : 14,
          "telegramReminders" : {
            "isEnabled" : true,
            "botToken" : " 123:abc "
          },
          "token" : "abc123"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(CanvasConfig.self, from: data)

        #expect(config.telegramReminders.isEnabled)
        #expect(config.telegramReminders.trimmedBotToken == "123:abc")
        #expect(config.telegramReminders.chatID == "")
        #expect(config.telegramReminders.reminderWindowHours == 24)
        #expect(config.telegramReminders.checkIntervalMinutes == 30)
        #expect(config.telegramReminders.repeatIntervalHours == 24)
    }

    @Test func canvasConfigManagerMigratesSensitiveTokensOutOfJSON() async throws {
        let configURL = makeCanvasConfigTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: configURL)
        defer { try? fileManager.removeItem(at: configURL) }

        let legacyConfig = """
        {
          "baseURL" : "https://canvas.example.edu",
          "lookaheadDays" : 14,
          "telegramReminders" : {
            "isEnabled" : true,
            "botToken" : " 123:abc ",
            "chatID" : "456",
            "reminderWindowHours" : 24,
            "checkIntervalMinutes" : 30,
            "repeatIntervalHours" : 24
          },
          "token" : " abc123 "
        }
        """
        try legacyConfig.data(using: .utf8)?.write(to: configURL)

        let tokenStore = InMemoryCanvasTokenStore()
        let manager = CanvasConfigManager(configURL: configURL, tokenStore: tokenStore)

        let config = manager.loadConfig()
        let storedJSON = try #require(String(data: Data(contentsOf: configURL), encoding: .utf8))

        #expect(config.trimmedToken == "abc123")
        #expect(config.telegramReminders.trimmedBotToken == "123:abc")
        #expect(try tokenStore.token(for: .canvasAccessToken) == "abc123")
        #expect(try tokenStore.token(for: .telegramBotToken) == "123:abc")
        #expect(!storedJSON.contains("abc123"))
        #expect(!storedJSON.contains("123:abc"))
        #expect(!storedJSON.contains("\"token\""))
        #expect(!storedJSON.contains("\"botToken\""))
    }

    @Test func canvasConfigManagerStoresSensitiveTokensOutsideJSONWhenSaving() async throws {
        let configURL = makeCanvasConfigTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: configURL)
        defer { try? fileManager.removeItem(at: configURL) }

        let tokenStore = InMemoryCanvasTokenStore()
        let manager = CanvasConfigManager(configURL: configURL, tokenStore: tokenStore)
        let config = CanvasConfig(
            baseURL: "https://canvas.example.edu",
            token: " abc123 ",
            lookaheadDays: 14,
            telegramReminders: TelegramReminderConfig(
                isEnabled: true,
                botToken: " 123:abc ",
                chatID: "456",
                reminderWindowHours: 24,
                checkIntervalMinutes: 30,
                repeatIntervalHours: 24
            )
        )

        try manager.saveConfig(config)
        let storedJSON = try #require(String(data: Data(contentsOf: configURL), encoding: .utf8))

        #expect(try tokenStore.token(for: .canvasAccessToken) == "abc123")
        #expect(try tokenStore.token(for: .telegramBotToken) == "123:abc")
        #expect(storedJSON.contains("canvas.example.edu"))
        #expect(storedJSON.contains("\"chatID\""))
        #expect(!storedJSON.contains("abc123"))
        #expect(!storedJSON.contains("123:abc"))
        #expect(!storedJSON.contains("\"token\""))
        #expect(!storedJSON.contains("\"botToken\""))
    }

    @Test func upcomingEventPrefersAssignmentDueDate() async throws {
        let dueDate = Date(timeIntervalSince1970: 1_710_000_000)
        let startDate = Date(timeIntervalSince1970: 1_709_000_000)

        let event = UpcomingEvent(
            id: "assignment_42",
            title: "Lab Report",
            details: nil,
            startAt: startDate,
            endAt: startDate,
            allDay: false,
            contextCode: "course_99",
            htmlURL: nil,
            workflowState: "published",
            assignment: CanvasAssignment(
                id: 42,
                name: "Lab Report",
                dueAt: dueDate,
                courseID: 99,
                htmlURL: nil,
                pointsPossible: 100
            )
        )

        #expect(event.displayDate == dueDate)
        #expect(event.courseID == 99)
        #expect(event.kindLabel == "Assignment")
    }

    @Test func moduleItemPrefersContentDetailURLAndMapsTypeIcon() async throws {
        let moduleItem = CourseModuleItem(
            id: 12,
            moduleID: 4,
            position: 1,
            title: "Week 1 Quiz",
            indent: 0,
            type: "Quiz",
            contentID: 77,
            htmlURL: URL(string: "https://canvas.example.edu/modules/items/12"),
            apiURL: nil,
            pageURL: nil,
            published: true,
            contentDetails: ModuleItemContentDetails(
                pointsPossible: 25,
                dueAt: nil,
                unlockAt: nil,
                lockAt: nil,
                lockedForUser: false,
                lockExplanation: nil,
                htmlURL: URL(string: "https://canvas.example.edu/courses/1/quizzes/77")
            )
        )

        #expect(moduleItem.actionableURL?.absoluteString == "https://canvas.example.edu/courses/1/quizzes/77")
        #expect(moduleItem.systemImageName == "checklist")
        #expect(moduleItem.pointsDescription == "25 pts")
    }

    @Test func courseAnnouncementBuildsSummaryAndSearchMetadata() async throws {
        let postedAt = Date(timeIntervalSince1970: 1_710_000_000)
        let announcement = CourseAnnouncement(
            id: 88,
            title: "Week 2 Update",
            message: "<p>Read <strong>chapter</strong>&nbsp;2 before lab.</p>",
            postedAt: postedAt,
            delayedPostAt: nil,
            contextCode: "course_42",
            htmlURL: URL(string: "https://canvas.example.edu/courses/42/discussion_topics/88"),
            readState: "unread",
            lockedForUser: false
        )

        #expect(announcement.summaryText == "Read chapter 2 before lab.")
        #expect(announcement.displayDate == postedAt)
        #expect(announcement.courseID == 42)
        #expect(announcement.isUnread)
        #expect(announcement.matchesSearch("chapter 2"))
        #expect(announcement.matchesSearch("unread"))
    }

    @Test func courseSyllabusBuildsReadableSummaryFromHTML() async throws {
        let syllabus = CourseSyllabus(
            id: 42,
            name: "Biology",
            syllabusBody: "<h1>Course Policy</h1><p>Bring a notebook&nbsp;daily.</p>",
            htmlURL: URL(string: "https://canvas.example.edu/courses/42")
        )

        #expect(syllabus.summaryText == "Course Policy Bring a notebook daily.")
        #expect(syllabus.hasContent)
        #expect(syllabus.matchesSearch("notebook daily"))
    }

    @Test func calendarEventItemsBucketUpcomingAndMissingByDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 19, hour: 12))!
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
        #expect(days.contains { calendar.component(.month, from: $0) == 5 })
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

    @Test func canvasConversationBuildsMetadataAndMatchesSearch() async throws {
        let conversation = CanvasConversation(
            id: 2,
            subject: "Lab feedback",
            workflowState: .unread,
            lastMessage: "Please review the attached rubric.",
            lastMessageAt: Date(timeIntervalSince1970: 1_710_000_000),
            messageCount: 3,
            subscribed: true,
            starred: false,
            audienceContexts: CanvasConversationAudienceContexts(
                courses: ["42": ["StudentEnrollment"]],
                groups: [:]
            ),
            avatarURL: nil,
            participants: [
                CanvasConversationParticipant(id: 1, name: "Jane", fullName: "Jane Teacher", avatarURL: nil),
                CanvasConversationParticipant(id: 2, name: "Alex", fullName: "Alex Student", avatarURL: nil)
            ],
            visible: true,
            contextName: "Biology"
        )

        #expect(conversation.isUnread)
        #expect(!conversation.isArchived)
        #expect(conversation.courseIDs == [42])
        #expect(conversation.participantSummary == "Jane Teacher, Alex Student")
        #expect(conversation.matchesSearch("rubric"))
        #expect(conversation.matchesSearch("biology"))
        #expect(conversation.matchesSearch("teacher"))
        #expect(!conversation.matchesSearch("chemistry"))
        #expect(conversation.canvasURL(baseURL: "https://canvas.example.edu")?.absoluteString == "https://canvas.example.edu/conversations/2")
    }

    @Test func moduleItemDetailKeysAreStable() async throws {
        #expect(CourseModuleItemDetailKey.quiz(courseID: 42, quizID: 9).rawValue == "quiz:42:9")
        #expect(CourseModuleItemDetailKey.discussion(courseID: 42, discussionID: 8).rawValue == "discussion:42:8")
        #expect(CourseModuleItemDetailKey.page(courseID: 42, pageURL: "week-1").rawValue == "page:42:week-1")
        #expect(CourseModuleItemDetailKey.page(courseID: 42, pageURL: "week-1").courseID == 42)
        #expect(CourseModuleItemDetailKey.page(courseID: 42, pageURL: "week-1").contentIdentifier == "week-1")
    }

    @Test func coursePreferenceManagerRoundTripsPreferences() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-course-preferences.json"
        )
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
        #expect(loaded.defaultEventsCourseID == 10)
        #expect(loaded.preferencesByCourseID[10]?.workspaceSection == "Modules")
        #expect(loaded.preferencesByCourseID[10]?.modules.searchQuery == "quiz")
    }

    @Test func networkManagerFetchesAnnouncementsWithCourseContext() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            [
              {
                "id" : 1,
                "title" : "Older",
                "message" : "<p>Older note</p>",
                "posted_at" : "2024-03-01T12:00:00Z",
                "context_code" : "course_42",
                "html_url" : "https://canvas.example.edu/courses/42/discussion_topics/1",
                "read_state" : "read",
                "locked_for_user" : false
              },
              {
                "id" : 2,
                "title" : "Newer",
                "message" : "<p>Newer note</p>",
                "posted_at" : "2024-03-02T12:00:00Z",
                "context_code" : "course_42",
                "html_url" : "https://canvas.example.edu/courses/42/discussion_topics/2",
                "read_state" : "unread",
                "locked_for_user" : false
              }
            ]
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let announcements = try await manager.fetchAnnouncements(courseID: 42, using: makeCanvasConfig())
        let request = try #require(CapturingURLProtocol.lastRequest)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.path == "/api/v1/announcements")
        #expect(queryItems.contains(URLQueryItem(name: "context_codes[]", value: "course_42")))
        #expect(queryItems.contains(URLQueryItem(name: "per_page", value: "100")))
        #expect(announcements.map(\.id) == [2, 1])
    }

    @Test func networkManagerFetchesCourseSyllabusBody() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            {
              "id" : 42,
              "name" : "Biology",
              "syllabus_body" : "<p>Welcome to class.</p>",
              "html_url" : "https://canvas.example.edu/courses/42"
            }
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let syllabus = try await manager.fetchSyllabus(courseID: 42, using: makeCanvasConfig())
        let request = try #require(CapturingURLProtocol.lastRequest)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.path == "/api/v1/courses/42")
        #expect(queryItems.contains(URLQueryItem(name: "include[]", value: "syllabus_body")))
        #expect(syllabus.summaryText == "Welcome to class.")
    }

    @Test func networkManagerFetchesCoursePeopleWithEnrollments() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
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
                "email": "smith@example.edu",
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

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let people = try await manager.fetchPeople(courseID: 42, using: makeCanvasConfig())
        let request = try #require(CapturingURLProtocol.lastRequest)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.path == "/api/v1/courses/42/users")
        #expect(queryItems.contains(URLQueryItem(name: "include[]", value: "enrollments")))
        #expect(queryItems.contains(URLQueryItem(name: "include[]", value: "avatar_url")))
        #expect(queryItems.contains(URLQueryItem(name: "per_page", value: "100")))
        #expect(people.count == 1)
        #expect(people.first?.primaryRole == .teacher)
        #expect(people.first?.sectionLabel == "Lecture")
    }

    @Test func networkManagerFetchesConversationsWithCourseFilter() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            [
              {
                "id": 1,
                "subject": "Older",
                "workflow_state": "read",
                "last_message": "Older note",
                "last_message_at": "2024-03-01T12:00:00Z",
                "message_count": 1,
                "subscribed": true,
                "starred": false,
                "audience_contexts": { "courses": { "42": ["StudentEnrollment"] }, "groups": {} },
                "participants": [
                  { "id": 10, "name": "Jane", "full_name": "Jane Teacher" }
                ],
                "visible": true,
                "context_name": "Biology"
              },
              {
                "id": 2,
                "subject": "Newer",
                "workflow_state": "unread",
                "last_message": "Newer note",
                "last_message_at": "2024-03-02T12:00:00Z",
                "message_count": 2,
                "subscribed": true,
                "starred": false,
                "audience_contexts": { "courses": { "42": ["StudentEnrollment"] }, "groups": {} },
                "participants": [
                  { "id": 11, "name": "Dr. Smith", "full_name": "Dr. Smith" }
                ],
                "visible": true,
                "context_name": "Biology"
              }
            ]
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let conversations = try await manager.fetchConversations(scope: .unread, filterCourseID: 42, using: makeCanvasConfig())
        let request = try #require(CapturingURLProtocol.lastRequest)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.path == "/api/v1/conversations")
        #expect(queryItems.contains(URLQueryItem(name: "scope", value: "unread")))
        #expect(queryItems.contains(URLQueryItem(name: "filter[]", value: "course_42")))
        #expect(queryItems.contains(URLQueryItem(name: "include[]", value: "participant_avatars")))
        #expect(queryItems.contains(URLQueryItem(name: "per_page", value: "100")))
        #expect(conversations.map(\.id) == [2, 1])
        #expect(conversations.first?.isUnread == true)
    }

    @Test func networkManagerUpdatesConversationWorkflowState() async throws {
        let session = makeCapturingURLSession { request in
            #expect(request.httpMethod == "PUT")
            let body = try #require(httpBodyData(from: request))
            let formItems = formBodyItems(from: body)
            #expect(formItems["conversation[workflow_state]"] == "read")

            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            {
              "id": 2,
              "subject": "Lab feedback",
              "workflow_state": "read",
              "last_message": "Thanks",
              "last_message_at": "2024-03-02T12:00:00Z",
              "message_count": 2,
              "subscribed": true,
              "starred": false,
              "audience_contexts": { "courses": { "42": ["StudentEnrollment"] }, "groups": {} },
              "participants": [
                { "id": 11, "name": "Dr. Smith", "full_name": "Dr. Smith" }
              ],
              "visible": true,
              "context_name": "Biology"
            }
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let updated = try await manager.updateConversationWorkflowState(
            conversationID: 2,
            state: .read,
            using: makeCanvasConfig()
        )
        let requestURL = try #require(CapturingURLProtocol.lastRequest?.url)

        #expect(requestURL.path == "/api/v1/conversations/2")
        #expect(updated.workflowState == .read)
    }

    @Test func networkManagerFetchesQuizDetail() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            {
              "id": 7,
              "title": "Unit Quiz",
              "description": "<p>Review chapters 1 and 2.</p>",
              "html_url": "https://canvas.example.edu/courses/42/quizzes/7",
              "quiz_type": "assignment",
              "points_possible": 20,
              "question_count": 10,
              "allowed_attempts": 2,
              "time_limit": 30,
              "published": true,
              "locked_for_user": false
            }
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let quiz = try await manager.fetchQuizDetail(courseID: 42, quizID: 7, using: makeCanvasConfig())
        let requestURL = try #require(CapturingURLProtocol.lastRequest?.url)

        #expect(requestURL.path == "/api/v1/courses/42/quizzes/7")
        #expect(quiz.summaryText == "Review chapters 1 and 2.")
        #expect(quiz.questionCount == 10)
    }

    @Test func networkManagerFetchesDiscussionDetail() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            {
              "id": 8,
              "title": "Week 1 Discussion",
              "message": "<p>Introduce yourself.</p>",
              "html_url": "https://canvas.example.edu/courses/42/discussion_topics/8",
              "discussion_subentry_count": 3,
              "unread_count": 1,
              "require_initial_post": true,
              "author": {
                "id": 2,
                "display_name": "Dr. Smith"
              }
            }
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let discussion = try await manager.fetchDiscussionDetail(courseID: 42, discussionID: 8, using: makeCanvasConfig())
        let requestURL = try #require(CapturingURLProtocol.lastRequest?.url)

        #expect(requestURL.path == "/api/v1/courses/42/discussion_topics/8")
        #expect(discussion.summaryText == "Introduce yourself.")
        #expect(discussion.authorName == "Dr. Smith")
    }

    @Test func networkManagerFetchesPageDetail() async throws {
        let session = makeCapturingURLSession { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else {
                throw CanvasServiceError.invalidResponse
            }

            let data = """
            {
              "page_id": 9,
              "url": "week-1",
              "title": "Week 1",
              "body": "<h1>Welcome</h1><p>Read the overview.</p>",
              "html_url": "https://canvas.example.edu/courses/42/pages/week-1",
              "front_page": false,
              "published": true
            }
            """.data(using: .utf8)!

            return (response, data)
        }
        let manager = NetworkManager(session: session)

        let page = try await manager.fetchPageDetail(courseID: 42, pageURL: "week-1", using: makeCanvasConfig())
        let requestURL = try #require(CapturingURLProtocol.lastRequest?.url)

        #expect(requestURL.path == "/api/v1/courses/42/pages/week-1")
        #expect(page.summaryText == "Welcome Read the overview.")
        #expect(page.published == true)
    }

    @Test func courseStudentEnrollmentPrefersStudentScores() async throws {
        let course = Course(
            id: 14,
            name: "Biology",
            courseCode: "BIO-101",
            workflowState: "available",
            htmlURL: nil,
            enrollmentTerm: EnrollmentTerm(name: "Spring"),
            enrollments: [
                CourseEnrollment(
                    type: "TeacherEnrollment",
                    role: "TeacherEnrollment",
                    enrollmentState: "active",
                    computedCurrentScore: nil,
                    computedCurrentGrade: nil,
                    computedFinalScore: nil,
                    computedFinalGrade: nil,
                    currentGradingPeriodTitle: nil,
                    hasGradingPeriods: nil,
                    currentPeriodComputedCurrentScore: nil,
                    currentPeriodComputedCurrentGrade: nil,
                    currentPeriodComputedFinalScore: nil,
                    currentPeriodComputedFinalGrade: nil
                ),
                CourseEnrollment(
                    type: "StudentEnrollment",
                    role: "StudentEnrollment",
                    enrollmentState: "active",
                    computedCurrentScore: 94.5,
                    computedCurrentGrade: "A",
                    computedFinalScore: 93.8,
                    computedFinalGrade: "A",
                    currentGradingPeriodTitle: "Unit 2",
                    hasGradingPeriods: true,
                    currentPeriodComputedCurrentScore: 96,
                    currentPeriodComputedCurrentGrade: "A",
                    currentPeriodComputedFinalScore: 96,
                    currentPeriodComputedFinalGrade: "A"
                )
            ]
        )

        #expect(course.studentEnrollment?.isStudentEnrollment == true)
        #expect(course.studentEnrollment?.displayCurrentGrade == "A")
        #expect(course.studentEnrollment?.displayCurrentScore == "94.5%")
        #expect(course.studentEnrollment?.displayCurrentPeriodScore == "96%")
    }

    @Test func courseAssignmentBuildsSubmissionSummaryAndStatus() async throws {
        let assignment = CourseAssignment(
            id: 77,
            name: "Essay Draft",
            details: "<p>Upload a <strong>draft</strong> before peer review.</p>",
            dueAt: Date(timeIntervalSinceNow: 3_600),
            unlockAt: nil,
            lockAt: nil,
            htmlURL: URL(string: "https://canvas.example.edu/courses/1/assignments/77"),
            courseID: 1,
            pointsPossible: 50,
            submissionTypes: ["online_upload"],
            hasSubmittedSubmissions: true,
            published: true,
            gradingType: "points",
            submission: AssignmentSubmission(
                submittedAt: Date(),
                gradedAt: Date(),
                score: 47.5,
                grade: "95%",
                workflowState: "graded",
                late: false,
                missing: false,
                excused: false,
                submissionType: "online_upload",
                attempt: 1
            )
        )

        #expect(assignment.status == CourseAssignmentStatus.graded)
        #expect(assignment.isCompleted)
        #expect(assignment.summaryText == "Upload a draft before peer review.")
        #expect(assignment.scoreDescription == "47.5 / 50")
        #expect(assignment.gradeDescription == "95%")
    }

    @Test func canvasFileFormatsSizeAndPrefersCanvasURL() async throws {
        let file = CanvasFile(
            id: 10,
            uuid: "file-uuid",
            folderID: 5,
            displayName: "Lecture Slides.pdf",
            filename: "lecture-slides.pdf",
            contentType: "application/pdf",
            url: URL(string: "https://files.example.edu/download/10"),
            htmlURL: URL(string: "https://canvas.example.edu/files/10"),
            size: 1_572_864,
            createdAt: nil,
            updatedAt: Date(timeIntervalSince1970: 1_710_000_000),
            unlockAt: nil,
            locked: false,
            hidden: false,
            lockedForUser: false,
            hiddenForUser: false,
            thumbnailURL: nil
        )

        #expect(file.name == "Lecture Slides.pdf")
        #expect(file.sizeDescription == "1.6 MB")
        #expect(file.actionableURL?.absoluteString == "https://canvas.example.edu/files/10")
        #expect(!file.isUnavailable)
    }

    @Test func canvasFolderBuildsItemSummaryAndUnavailableState() async throws {
        let folder = CanvasFolder(
            id: 42,
            name: "Week 1",
            fullName: "Course Files/Week 1",
            parentFolderID: 1,
            filesCount: 3,
            foldersCount: 2,
            position: 4,
            locked: true,
            hidden: false
        )

        #expect(folder.displayName == "Week 1")
        #expect(folder.itemCountDescription == "3 files · 2 folders")
        #expect(folder.isUnavailable)
        #expect(folder.sortName == "course files/week 1")
    }

    @Test func courseWorkspaceModelsMatchSearchAcrossUsefulFields() async throws {
        let module = CourseModule(
            id: 7,
            name: "Week 2",
            position: 2,
            workflowState: "active",
            unlockAt: nil,
            itemsCount: 1,
            published: true,
            items: [
                CourseModuleItem(
                    id: 70,
                    moduleID: 7,
                    position: 1,
                    title: "Linear Algebra Notes",
                    indent: 0,
                    type: "Page",
                    contentID: nil,
                    htmlURL: nil,
                    apiURL: nil,
                    pageURL: nil,
                    published: true,
                    contentDetails: nil
                )
            ]
        )

        let file = CanvasFile(
            id: 11,
            uuid: nil,
            folderID: 4,
            displayName: "Project Rubric",
            filename: "rubric.pdf",
            contentType: "application/pdf",
            url: nil,
            htmlURL: nil,
            size: nil,
            createdAt: nil,
            updatedAt: nil,
            unlockAt: nil,
            locked: nil,
            hidden: nil,
            lockedForUser: nil,
            hiddenForUser: nil,
            thumbnailURL: nil
        )

        let assignment = CourseAssignment(
            id: 99,
            name: "Midterm Reflection",
            details: "<p>Write about matrix proofs.</p>",
            dueAt: Date(timeIntervalSinceNow: 3_600),
            unlockAt: nil,
            lockAt: nil,
            htmlURL: nil,
            courseID: 1,
            pointsPossible: 20,
            submissionTypes: nil,
            hasSubmittedSubmissions: false,
            published: true,
            gradingType: "points",
            submission: nil
        )

        #expect(module.matchesSearch("algebra"))
        #expect(file.matchesSearch("PDF"))
        #expect(assignment.matchesSearch("matrix"))
        #expect(assignment.matchesSearch("upcoming"))
        #expect(!module.matchesSearch("biology"))
    }

    @Test func canvasFolderSortNamesSupportPathBasedOrdering() async throws {
        let folders = [
            CanvasFolder(
                id: 2,
                name: "Week 10",
                fullName: "Course Files/Week 10",
                parentFolderID: nil,
                filesCount: nil,
                foldersCount: nil,
                position: nil,
                locked: nil,
                hidden: nil
            ),
            CanvasFolder(
                id: 1,
                name: "Week 01",
                fullName: "Course Files/Week 01",
                parentFolderID: nil,
                filesCount: nil,
                foldersCount: nil,
                position: nil,
                locked: nil,
                hidden: nil
            )
        ]

        let sortedFolders = folders.sorted {
            $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending
        }

        #expect(sortedFolders.map(\.id) == [1, 2])
    }

    @Test func courseDetailCacheSnapshotPrunesExpiredAndLeastRecentCourses() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let expiredAccessDate = Date(timeInterval: -3_600, since: referenceDate)
        let middleAccessDate = Date(timeInterval: -240, since: referenceDate)
        let recentAccessDate = Date(timeInterval: -60, since: referenceDate)
        let snapshot = CourseDetailCacheSnapshot(
            assignmentsByCourseID: [
                1: [makeCourseAssignment(id: 1, name: "Protected", dueAt: referenceDate, courseID: 1)],
                2: [makeCourseAssignment(id: 2, name: "Middle", dueAt: referenceDate, courseID: 2)],
                3: [makeCourseAssignment(id: 3, name: "Recent", dueAt: referenceDate, courseID: 3)]
            ],
            modulesByCourseID: [:],
            foldersByCourseID: [
                1: [makeCanvasFolder(id: 101, name: "Protected Files")],
                2: [makeCanvasFolder(id: 201, name: "Middle Files")],
                3: [makeCanvasFolder(id: 301, name: "Recent Files")]
            ],
            filesByFolderID: [
                101: [makeCanvasFile(id: 1001, name: "protected.pdf")],
                201: [makeCanvasFile(id: 2001, name: "middle.pdf")],
                301: [makeCanvasFile(id: 3001, name: "recent.pdf")]
            ],
            announcementsByCourseID: [:],
            syllabusByCourseID: [:],
            peopleByCourseID: [
                1: [makeCoursePerson(id: 1, name: "Protected Teacher", role: "TeacherEnrollment")],
                2: [makeCoursePerson(id: 2, name: "Middle Student", role: "StudentEnrollment")],
                3: [makeCoursePerson(id: 3, name: "Recent Student", role: "StudentEnrollment")]
            ],
            courseAccessedAtByCourseID: [
                1: expiredAccessDate,
                2: middleAccessDate,
                3: recentAccessDate
            ],
            savedAt: referenceDate
        )

        let pruned = snapshot.prunedForMemory(
            now: referenceDate,
            timeToLive: 30 * 60,
            maximumCourses: 2,
            alwaysKeepingCourseIDs: [1]
        )

        #expect(pruned.assignmentsByCourseID.keys.sorted() == [1, 3])
        #expect(pruned.foldersByCourseID.keys.sorted() == [1, 3])
        #expect(pruned.filesByFolderID.keys.sorted() == [101, 301])
        #expect(pruned.peopleByCourseID.keys.sorted() == [1, 3])
        #expect(pruned.courseAccessedAtByCourseID.keys.sorted() == [1, 3])
    }

    @Test func courseDetailCacheManagerDropsExpiredDiskCache() async throws {
        let cacheURL = makeCourseDetailCacheTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: cacheURL)
        defer { try? fileManager.removeItem(at: cacheURL) }

        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let manager = CourseDetailCacheManager(cacheURL: cacheURL)
        let snapshot = CourseDetailCacheSnapshot(
            assignmentsByCourseID: [
                42: [makeCourseAssignment(id: 10, name: "Lab", dueAt: referenceDate, courseID: 42)]
            ],
            modulesByCourseID: [:],
            foldersByCourseID: [:],
            filesByFolderID: [:],
            announcementsByCourseID: [:],
            syllabusByCourseID: [:],
            courseAccessedAtByCourseID: [42: referenceDate],
            savedAt: Date(timeInterval: -86_401, since: referenceDate)
        )

        try manager.saveCache(snapshot)

        #expect(manager.loadCache(validAt: referenceDate, maximumAge: 86_400) == nil)
        #expect(!fileManager.fileExists(atPath: cacheURL.path))
    }

    @MainActor
    @Test func canvasStoreRestoresFreshCourseDetailCacheFromDisk() async throws {
        let configURL = makeCanvasConfigTempURL()
        let dashboardCacheURL = makeDashboardCacheTempURL()
        let courseDetailCacheURL = makeCourseDetailCacheTempURL()
        let fileManager = FileManager.default
        [configURL, dashboardCacheURL, courseDetailCacheURL].forEach { url in
            try? fileManager.removeItem(at: url)
        }
        defer {
            [configURL, dashboardCacheURL, courseDetailCacheURL].forEach { url in
                try? fileManager.removeItem(at: url)
            }
        }

        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let databaseManager = DatabaseManager(cacheURL: dashboardCacheURL)
        try databaseManager.saveSnapshot(
            CanvasSnapshot(
                courses: [makeCourse(id: 42, name: "Biology")],
                upcomingEvents: [],
                missingSubmissions: [],
                profile: nil,
                syncedAt: referenceDate
            )
        )

        let detailCacheManager = CourseDetailCacheManager(cacheURL: courseDetailCacheURL)
        try detailCacheManager.saveCache(
            CourseDetailCacheSnapshot(
                assignmentsByCourseID: [
                    42: [makeCourseAssignment(id: 10, name: "Lab", dueAt: referenceDate, courseID: 42)]
                ],
                modulesByCourseID: [:],
                foldersByCourseID: [:],
                filesByFolderID: [:],
                announcementsByCourseID: [:],
                syllabusByCourseID: [:],
                courseAccessedAtByCourseID: [42: referenceDate],
                savedAt: referenceDate
            )
        )

        let store = CanvasStore(
            configManager: CanvasConfigManager(configURL: configURL, tokenStore: InMemoryCanvasTokenStore()),
            databaseManager: databaseManager,
            networkManager: .shared,
            detailCacheManager: detailCacheManager,
            cachePolicy: CanvasCachePolicy(
                memoryTimeToLive: 30 * 60,
                diskTimeToLive: 24 * 60 * 60,
                maintenanceInterval: 60 * 60,
                maximumMemoryCourses: 5
            ),
            now: { referenceDate }
        )

        #expect(store.hasLoadedAssignments(for: 42))
        #expect(store.assignments(for: 42).map(\.name) == ["Lab"])
    }

    @MainActor
    @Test func canvasStoreCacheHitDoesNotRefreshDiskExpiration() async throws {
        let configURL = makeCanvasConfigTempURL()
        let dashboardCacheURL = makeDashboardCacheTempURL()
        let courseDetailCacheURL = makeCourseDetailCacheTempURL()
        let fileManager = FileManager.default
        [configURL, dashboardCacheURL, courseDetailCacheURL].forEach { url in
            try? fileManager.removeItem(at: url)
        }
        defer {
            [configURL, dashboardCacheURL, courseDetailCacheURL].forEach { url in
                try? fileManager.removeItem(at: url)
            }
        }

        let savedAt = Date(timeIntervalSince1970: 1_710_000_000)
        let laterDate = Date(timeInterval: 600, since: savedAt)
        let databaseManager = DatabaseManager(cacheURL: dashboardCacheURL)
        try databaseManager.saveSnapshot(
            CanvasSnapshot(
                courses: [makeCourse(id: 42, name: "Biology")],
                upcomingEvents: [],
                missingSubmissions: [],
                profile: nil,
                syncedAt: savedAt
            )
        )

        let detailCacheManager = CourseDetailCacheManager(cacheURL: courseDetailCacheURL)
        try detailCacheManager.saveCache(
            CourseDetailCacheSnapshot(
                assignmentsByCourseID: [
                    42: [makeCourseAssignment(id: 10, name: "Lab", dueAt: savedAt, courseID: 42)]
                ],
                modulesByCourseID: [:],
                foldersByCourseID: [:],
                filesByFolderID: [:],
                announcementsByCourseID: [:],
                syllabusByCourseID: [:],
                courseAccessedAtByCourseID: [42: savedAt],
                savedAt: savedAt
            )
        )

        let store = CanvasStore(
            configManager: CanvasConfigManager(configURL: configURL, tokenStore: InMemoryCanvasTokenStore()),
            databaseManager: databaseManager,
            networkManager: .shared,
            detailCacheManager: detailCacheManager,
            cachePolicy: CanvasCachePolicy(
                memoryTimeToLive: 30 * 60,
                diskTimeToLive: 24 * 60 * 60,
                maintenanceInterval: 60 * 60,
                maximumMemoryCourses: 5
            ),
            now: { laterDate }
        )

        await store.loadAssignmentsIfNeeded(for: 42)
        let reloadedSnapshot = try #require(detailCacheManager.loadCache(validAt: laterDate, maximumAge: 24 * 60 * 60))

        #expect(reloadedSnapshot.savedAt == savedAt)
    }

    @MainActor
    @Test func canvasStorePrunesExpiredInMemoryCourseDetails() async throws {
        let configURL = makeCanvasConfigTempURL()
        let dashboardCacheURL = makeDashboardCacheTempURL()
        let courseDetailCacheURL = makeCourseDetailCacheTempURL()
        let fileManager = FileManager.default
        [configURL, dashboardCacheURL, courseDetailCacheURL].forEach { url in
            try? fileManager.removeItem(at: url)
        }
        defer {
            [configURL, dashboardCacheURL, courseDetailCacheURL].forEach { url in
                try? fileManager.removeItem(at: url)
            }
        }

        var currentDate = Date(timeIntervalSince1970: 1_710_000_000)
        let databaseManager = DatabaseManager(cacheURL: dashboardCacheURL)
        try databaseManager.saveSnapshot(
            CanvasSnapshot(
                courses: [
                    makeCourse(id: 1, name: "Selected"),
                    makeCourse(id: 2, name: "Stale")
                ],
                upcomingEvents: [],
                missingSubmissions: [],
                profile: nil,
                syncedAt: currentDate
            )
        )

        let detailCacheManager = CourseDetailCacheManager(cacheURL: courseDetailCacheURL)
        try detailCacheManager.saveCache(
            CourseDetailCacheSnapshot(
                assignmentsByCourseID: [
                    1: [makeCourseAssignment(id: 1, name: "Selected Lab", dueAt: currentDate, courseID: 1)],
                    2: [makeCourseAssignment(id: 2, name: "Stale Lab", dueAt: currentDate, courseID: 2)]
                ],
                modulesByCourseID: [:],
                foldersByCourseID: [:],
                filesByFolderID: [:],
                announcementsByCourseID: [:],
                syllabusByCourseID: [:],
                courseAccessedAtByCourseID: [
                    1: currentDate,
                    2: currentDate
                ],
                savedAt: currentDate
            )
        )

        let store = CanvasStore(
            configManager: CanvasConfigManager(configURL: configURL, tokenStore: InMemoryCanvasTokenStore()),
            databaseManager: databaseManager,
            networkManager: .shared,
            detailCacheManager: detailCacheManager,
            cachePolicy: CanvasCachePolicy(
                memoryTimeToLive: 60,
                diskTimeToLive: 24 * 60 * 60,
                maintenanceInterval: 60 * 60,
                maximumMemoryCourses: 5
            ),
            now: { currentDate }
        )

        #expect(store.hasLoadedAssignments(for: 1))
        #expect(store.hasLoadedAssignments(for: 2))

        currentDate = Date(timeInterval: 120, since: currentDate)
        store.pruneCourseDetailMemoryCache(referenceDate: currentDate)

        #expect(store.hasLoadedAssignments(for: 1))
        #expect(!store.hasLoadedAssignments(for: 2))
    }

    @Test func upcomingEventsClassifyDashboardWindow() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let todayDate = calendar.date(byAdding: .hour, value: 2, to: referenceDate)!
        let thisWeekDate = calendar.date(byAdding: .day, value: 4, to: referenceDate)!
        let laterDate = calendar.date(byAdding: .day, value: 10, to: referenceDate)!

        #expect(makeUpcomingEvent(date: todayDate).dashboardWindow(referenceDate: referenceDate, calendar: calendar) == .today)
        #expect(makeUpcomingEvent(date: thisWeekDate).dashboardWindow(referenceDate: referenceDate, calendar: calendar) == .thisWeek)
        #expect(makeUpcomingEvent(date: laterDate).dashboardWindow(referenceDate: referenceDate, calendar: calendar) == .later)
    }

    @Test func missingSubmissionDetectsOverdueForDashboard() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let overdue = MissingSubmission(
            id: 1,
            name: "Late Essay",
            dueAt: Date(timeInterval: -3_600, since: referenceDate),
            courseID: 1,
            htmlURL: nil,
            pointsPossible: 10
        )
        let upcoming = MissingSubmission(
            id: 2,
            name: "Future Essay",
            dueAt: Date(timeInterval: 3_600, since: referenceDate),
            courseID: 1,
            htmlURL: nil,
            pointsPossible: 10
        )

        #expect(overdue.isOverdue(referenceDate: referenceDate))
        #expect(!upcoming.isOverdue(referenceDate: referenceDate))
    }

    @Test func fileDownloadRecordSanitizesUnsafeFilenames() async throws {
        let file = makeCanvasFile(id: 10, name: " Week 1 / Intro: Notes?.pdf ")

        #expect(FileDownloadRecord.safeFilename(for: file) == "Week 1 - Intro- Notes-.pdf")
    }

    @Test func fileDownloadManagerRoundTripsSnapshotAndClearsCorruptJSON() async throws {
        let metadataURL = makeFileDownloadMetadataTempURL()
        let downloadsURL = makeDownloadsTempDirectoryURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: metadataURL)
        try? fileManager.removeItem(at: downloadsURL)
        defer {
            try? fileManager.removeItem(at: metadataURL)
            try? fileManager.removeItem(at: downloadsURL)
        }

        let manager = FileDownloadManager(metadataURL: metadataURL, downloadsDirectory: downloadsURL)
        let file = makeCanvasFile(id: 1, name: "Slides.pdf")
        let localURL = manager.localURL(for: file, courseID: 2)
        try fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("slides".utf8).write(to: localURL)
        let snapshot = FileDownloadSnapshot(
            recordsByFileID: [
                file.id: FileDownloadRecord(
                    fileID: file.id,
                    courseID: 2,
                    folderID: 3,
                    file: file,
                    state: .downloaded,
                    localPath: localURL.path,
                    downloadedAt: Date(timeIntervalSince1970: 1_710_000_001),
                    byteCount: 6
                )
            ],
            updatedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )

        try manager.saveSnapshot(snapshot)

        #expect(manager.loadSnapshot() == snapshot)

        try Data("{ nope".utf8).write(to: metadataURL, options: .atomic)

        #expect(manager.loadSnapshot().recordsByFileID.isEmpty)
    }

    @Test func fileDownloadManagerDownloadsWithBearerToken() async throws {
        let metadataURL = makeFileDownloadMetadataTempURL()
        let downloadsURL = makeDownloadsTempDirectoryURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: metadataURL)
        try? fileManager.removeItem(at: downloadsURL)
        defer {
            try? fileManager.removeItem(at: metadataURL)
            try? fileManager.removeItem(at: downloadsURL)
        }

        let session = makeCapturingURLSession { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("hello".utf8))
        }
        let manager = FileDownloadManager(metadataURL: metadataURL, downloadsDirectory: downloadsURL, session: session)
        let file = makeCanvasFile(
            id: 5,
            name: "Reading.pdf",
            url: URL(string: "https://canvas.example.edu/files/5/download")
        )

        let record = try await manager.download(file: file, courseID: 10, using: makeCanvasConfig())

        #expect(record.state == .downloaded)
        #expect(record.byteCount == 5)
        #expect(CapturingURLProtocol.lastRequest?.url?.absoluteString == "https://canvas.example.edu/files/5/download")
        #expect(record.localPath.map { fileManager.fileExists(atPath: $0) } == true)
    }

    @Test func fileDownloadManagerDoesNotDownloadCanvasHTMLFallback() async throws {
        let manager = FileDownloadManager(
            metadataURL: makeFileDownloadMetadataTempURL(),
            downloadsDirectory: makeDownloadsTempDirectoryURL()
        )
        let file = CanvasFile(
            id: 12,
            uuid: nil,
            folderID: nil,
            displayName: "Preview Only",
            filename: "preview.html",
            contentType: "text/html",
            url: nil,
            htmlURL: URL(string: "https://canvas.example.edu/files/12"),
            size: nil,
            createdAt: nil,
            updatedAt: nil,
            unlockAt: nil,
            locked: nil,
            hidden: nil,
            lockedForUser: nil,
            hiddenForUser: nil,
            thumbnailURL: nil
        )

        do {
            _ = try await manager.download(file: file, courseID: 1, using: makeCanvasConfig())
            Issue.record("Expected missing direct download URL to throw")
        } catch FileDownloadError.missingDownloadURL {
            // Expected path.
        } catch {
            Issue.record("Expected missing direct download URL, got \(error)")
        }
    }

    @Test func fileDownloadRecordValidatesLocalPreviewURL() async throws {
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-preview.pdf"
        )
        defer { try? FileManager.default.removeItem(at: localURL) }

        let file = makeCanvasFile(id: 30, name: "Preview.pdf")
        let record = FileDownloadRecord(
            fileID: file.id,
            courseID: 1,
            folderID: nil,
            file: file,
            state: .downloaded,
            localPath: localURL.path,
            downloadedAt: Date(),
            failureMessage: nil,
            byteCount: 7
        )

        #expect(record.localPreviewURL == nil)

        try Data("preview".utf8).write(to: localURL)

        #expect(record.localPreviewURL == localURL)
    }

    @Test func fileDownloadManagerReconcilesInterruptedAndMissingLocalRecords() async throws {
        let file = makeCanvasFile(id: 20, name: "Reading.pdf")
        let interrupted = FileDownloadRecord(
            fileID: file.id,
            courseID: 1,
            folderID: nil,
            file: file,
            state: .downloading
        )
        let missing = FileDownloadRecord(
            fileID: 21,
            courseID: 1,
            folderID: nil,
            file: makeCanvasFile(id: 21, name: "Missing.pdf"),
            state: .downloaded,
            localPath: "/tmp/does-not-exist-\(UUID().uuidString).pdf",
            downloadedAt: Date(),
            failureMessage: nil,
            byteCount: 100
        )
        let manager = FileDownloadManager(
            metadataURL: makeFileDownloadMetadataTempURL(),
            downloadsDirectory: makeDownloadsTempDirectoryURL()
        )

        let snapshot = manager.reconciledSnapshot(
            FileDownloadSnapshot(recordsByFileID: [
                interrupted.fileID: interrupted,
                missing.fileID: missing
            ])
        )

        #expect(snapshot.recordsByFileID[interrupted.fileID]?.state == .failed)
        #expect(snapshot.recordsByFileID[missing.fileID]?.state == .failed)
        #expect(snapshot.recordsByFileID[missing.fileID]?.localPath == nil)
    }

    @Test func clearingDownloadedDirectoryPreservesDownloadMetadata() async throws {
        let metadataURL = makeFileDownloadMetadataTempURL()
        let downloadsURL = makeDownloadsTempDirectoryURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: metadataURL)
        try? fileManager.removeItem(at: downloadsURL)
        defer {
            try? fileManager.removeItem(at: metadataURL)
            try? fileManager.removeItem(at: downloadsURL)
        }

        let manager = FileDownloadManager(metadataURL: metadataURL, downloadsDirectory: downloadsURL)
        let file = makeCanvasFile(id: 22, name: "Known.pdf")
        let snapshot = FileDownloadSnapshot(recordsByFileID: [
            file.id: FileDownloadRecord(fileID: file.id, courseID: 1, folderID: nil, file: file)
        ])
        try manager.saveSnapshot(snapshot)

        try manager.clearDownloadedFilesDirectory()

        #expect(manager.loadSnapshot().recordsByFileID[file.id]?.file.name == "Known.pdf")
    }

    @Test func globalSearchRanksTitleMatchesBeforeMetadataMatches() async throws {
        let course = makeCourse(id: 10, name: "Biology")
        let results = GlobalSearchIndex.results(
            query: "biology",
            courses: [course],
            upcomingEvents: [],
            missingSubmissions: [],
            assignmentsByCourseID: [
                10: [
                    makeCourseAssignment(id: 1, name: "Biology Lab", dueAt: nil, courseID: 10),
                    makeCourseAssignment(id: 2, name: "Weekly Notes", dueAt: nil, courseID: 10)
                ]
            ],
            modulesByCourseID: [:],
            foldersByCourseID: [:],
            filesByFolderID: [:],
            announcementsByCourseID: [:],
            syllabusByCourseID: [:],
            peopleByCourseID: [:],
            moduleItemDetailsByKey: [:]
        )

        #expect(results.first?.title == "Biology")
        #expect(results.contains { $0.kind == .assignment && $0.title == "Biology Lab" })
        #expect(results.contains { $0.title == "Weekly Notes" })
    }

    @Test func recentSearchManagerSavesCapsAndClearsTerms() async throws {
        let storageURL = makeRecentSearchTempURL()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: storageURL)
        defer { try? fileManager.removeItem(at: storageURL) }

        let manager = RecentSearchManager(storageURL: storageURL)
        try manager.saveTerms((1...12).map { "term-\($0)" })

        #expect(manager.loadTerms().count == 10)

        try manager.clearTerms()

        #expect(manager.loadTerms().isEmpty)
    }

    private func makeUpcomingEvent(date: Date) -> UpcomingEvent {
        UpcomingEvent(
            id: UUID().uuidString,
            title: "Quiz",
            details: nil,
            startAt: date,
            endAt: date,
            allDay: false,
            contextCode: "course_1",
            htmlURL: nil,
            workflowState: "published",
            assignment: nil
        )
    }

    private func makeCourseAssignment(
        id: Int,
        name: String,
        dueAt: Date?,
        courseID: Int?,
        submissionTypes: [String]? = ["online_upload"],
        published: Bool? = true,
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
            submissionTypes: submissionTypes,
            hasSubmittedSubmissions: false,
            published: published,
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

    private func makeReminderHistoryTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-telegram-reminder-history.json"
        )
    }

    private func makeDashboardCacheTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-dashboard-cache.json"
        )
    }

    private func makeCourseDetailCacheTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-course-detail-cache.json"
        )
    }

    private func makeCanvasConfigTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-canvas-config.json"
        )
    }

    private func makeTelegramReminderConfig(isEnabled: Bool = true) -> TelegramReminderConfig {
        TelegramReminderConfig(
            isEnabled: isEnabled,
            botToken: "123:abc",
            chatID: "456",
            reminderWindowHours: 24,
            checkIntervalMinutes: 30,
            repeatIntervalHours: 24
        )
    }

    private func makeCanvasConfig(telegramReminders: TelegramReminderConfig = TelegramReminderConfig()) -> CanvasConfig {
        CanvasConfig(
            baseURL: "https://canvas.example.edu",
            token: "token",
            lookaheadDays: 14,
            telegramReminders: telegramReminders
        )
    }

    private func makeCourse(id: Int, name: String) -> Course {
        Course(
            id: id,
            name: name,
            courseCode: nil,
            workflowState: "available",
            htmlURL: nil,
            enrollmentTerm: nil,
            enrollments: nil
        )
    }

    private func makeCoursePerson(id: Int, name: String, role: String) -> CoursePerson {
        CoursePerson(
            id: id,
            name: name,
            sortableName: name,
            shortName: name,
            avatarURL: nil,
            htmlURL: nil,
            email: nil,
            loginID: nil,
            enrollments: [
                CoursePersonEnrollment(
                    type: role,
                    role: role,
                    roleID: nil,
                    sectionID: nil,
                    sectionName: "Lecture",
                    enrollmentState: "active",
                    lastActivityAt: nil
                )
            ]
        )
    }

    private func makeCanvasFolder(id: Int, name: String) -> CanvasFolder {
        CanvasFolder(
            id: id,
            name: name,
            fullName: "Course Files/\(name)",
            parentFolderID: nil,
            filesCount: nil,
            foldersCount: nil,
            position: nil,
            locked: nil,
            hidden: nil
        )
    }

    private func makeCanvasFile(
        id: Int,
        name: String,
        folderID: Int? = nil,
        url: URL? = nil
    ) -> CanvasFile {
        CanvasFile(
            id: id,
            uuid: nil,
            folderID: folderID,
            displayName: name,
            filename: name,
            contentType: "application/pdf",
            url: url,
            htmlURL: nil,
            size: 1_024,
            createdAt: nil,
            updatedAt: nil,
            unlockAt: nil,
            locked: nil,
            hidden: nil,
            lockedForUser: nil,
            hiddenForUser: nil,
            thumbnailURL: nil
        )
    }

    private func makeFileDownloadMetadataTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-file-downloads.json"
        )
    }

    private func makeDownloadsTempDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-downloads",
            isDirectory: true
        )
    }

    private func makeRecentSearchTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "EventsTracker-\(UUID().uuidString)-recent-searches.json"
        )
    }

    private func makeCapturingURLSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        CapturingURLProtocol.handler = handler
        CapturingURLProtocol.lastRequest = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapturingURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func formBodyItems(from data: Data) -> [String: String] {
        guard
            let body = String(data: data, encoding: .utf8),
            let components = URLComponents(string: "https://example.invalid?\(body)")
        else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            guard let value = item.value else {
                return nil
            }

            return (item.name, value)
        })
    }

    private func httpBodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer {
            stream.close()
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                return nil
            } else {
                break
            }
        }

        return data
    }

    private func hasActiveReminderTask(in service: AssignmentReminderService) -> Bool {
        let mirror = Mirror(reflecting: service)
        guard let taskValue = mirror.children.first(where: { $0.label == "reminderTask" })?.value else {
            return false
        }

        return !Mirror(reflecting: taskValue).children.isEmpty
    }
}

private final class CapturingURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: TelegramServiceError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class InMemoryCanvasTokenStore: CanvasTokenStore {
    private var tokens: [CanvasTokenKind: String] = [:]

    func token(for kind: CanvasTokenKind) throws -> String? {
        tokens[kind]
    }

    func setToken(_ token: String?, for kind: CanvasTokenKind) throws {
        tokens[kind] = token
    }
}
