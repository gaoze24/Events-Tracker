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
}
