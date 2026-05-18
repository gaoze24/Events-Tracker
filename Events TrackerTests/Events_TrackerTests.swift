//
//  Events_TrackerTests.swift
//  Events TrackerTests
//
//  Created by Eddie Gao on 24/3/25.
//

import Foundation
import Testing
@testable import Events_Tracker

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

    private func makeCanvasConfig(telegramReminders: TelegramReminderConfig) -> CanvasConfig {
        CanvasConfig(
            baseURL: "https://canvas.example.edu",
            token: "token",
            lookaheadDays: 14,
            telegramReminders: telegramReminders
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
