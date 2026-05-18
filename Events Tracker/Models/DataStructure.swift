//
//  DataStructure.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

struct CanvasConfig: Codable, Equatable {
    var baseURL: String = ""
    var token: String = ""
    var lookaheadDays: Int = 14

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

struct EnrollmentTerm: Codable, Hashable {
    let name: String?
}

struct Course: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let courseCode: String?
    let workflowState: String?
    let htmlURL: URL?
    let enrollmentTerm: EnrollmentTerm?
    let enrollments: [CourseEnrollment]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case courseCode = "course_code"
        case workflowState = "workflow_state"
        case htmlURL = "html_url"
        case enrollmentTerm = "term"
        case enrollments
    }

    var studentEnrollment: CourseEnrollment? {
        if let studentEnrollment = enrollments?.first(where: { $0.isStudentEnrollment }) {
            return studentEnrollment
        }

        return enrollments?.first
    }
}

struct CourseEnrollment: Codable, Hashable {
    let type: String?
    let role: String?
    let enrollmentState: String?
    let computedCurrentScore: Double?
    let computedCurrentGrade: String?
    let computedFinalScore: Double?
    let computedFinalGrade: String?
    let currentGradingPeriodTitle: String?
    let hasGradingPeriods: Bool?
    let currentPeriodComputedCurrentScore: Double?
    let currentPeriodComputedCurrentGrade: String?
    let currentPeriodComputedFinalScore: Double?
    let currentPeriodComputedFinalGrade: String?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case enrollmentState = "enrollment_state"
        case computedCurrentScore = "computed_current_score"
        case computedCurrentGrade = "computed_current_grade"
        case computedFinalScore = "computed_final_score"
        case computedFinalGrade = "computed_final_grade"
        case currentGradingPeriodTitle = "current_grading_period_title"
        case hasGradingPeriods = "has_grading_periods"
        case currentPeriodComputedCurrentScore = "current_period_computed_current_score"
        case currentPeriodComputedCurrentGrade = "current_period_computed_current_grade"
        case currentPeriodComputedFinalScore = "current_period_computed_final_score"
        case currentPeriodComputedFinalGrade = "current_period_computed_final_grade"
    }

    var isStudentEnrollment: Bool {
        let descriptor = [type, role]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")

        return descriptor.localizedCaseInsensitiveContains("student")
    }

    var displayCurrentScore: String? {
        Self.formattedPercentage(computedCurrentScore)
    }

    var displayCurrentGrade: String? {
        normalizedGrade(computedCurrentGrade) ?? Self.formattedPercentage(computedCurrentScore)
    }

    var displayFinalScore: String? {
        Self.formattedPercentage(computedFinalScore)
    }

    var displayFinalGrade: String? {
        normalizedGrade(computedFinalGrade) ?? Self.formattedPercentage(computedFinalScore)
    }

    var displayCurrentPeriodScore: String? {
        Self.formattedPercentage(currentPeriodComputedCurrentScore)
    }

    var displayCurrentPeriodGrade: String? {
        normalizedGrade(currentPeriodComputedCurrentGrade) ?? Self.formattedPercentage(currentPeriodComputedCurrentScore)
    }

    private func normalizedGrade(_ grade: String?) -> String? {
        guard let trimmedGrade = grade?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedGrade.isEmpty else {
            return nil
        }

        return trimmedGrade
    }

    private static func formattedPercentage(_ value: Double?) -> String? {
        guard let value else {
            return nil
        }

        if value.rounded() == value {
            return "\(Int(value))%"
        }

        return String(format: "%.1f%%", value)
    }
}

struct CourseModule: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let position: Int?
    let workflowState: String?
    let unlockAt: Date?
    let itemsCount: Int?
    let published: Bool?
    var items: [CourseModuleItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case position
        case workflowState = "workflow_state"
        case unlockAt = "unlock_at"
        case itemsCount = "items_count"
        case published
        case items
    }

    var sortedItems: [CourseModuleItem] {
        (items ?? []).sorted { lhs, rhs in
            switch (lhs.position, rhs.position) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
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

    var visibleItemCount: Int {
        itemsCount ?? sortedItems.count
    }

    func withItems(_ items: [CourseModuleItem]) -> CourseModule {
        var copy = self
        copy.items = items
        return copy
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(
            query,
            in: name,
            workflowState,
            itemsCount.map { "\($0) items" }
        ) || sortedItems.contains { $0.matchesSearch(query) }
    }
}

struct CourseModuleItem: Codable, Identifiable, Hashable {
    let id: Int
    let moduleID: Int?
    let position: Int?
    let title: String
    let indent: Int?
    let type: String?
    let contentID: Int?
    let htmlURL: URL?
    let apiURL: URL?
    let pageURL: String?
    let published: Bool?
    let contentDetails: ModuleItemContentDetails?

    enum CodingKeys: String, CodingKey {
        case id
        case moduleID = "module_id"
        case position
        case title
        case indent
        case type
        case contentID = "content_id"
        case htmlURL = "html_url"
        case apiURL = "url"
        case pageURL = "page_url"
        case published
        case contentDetails = "content_details"
    }

    var itemTypeLabel: String {
        type ?? "Item"
    }

    var systemImageName: String {
        switch type {
        case "Assignment":
            return "doc.text"
        case "Discussion":
            return "bubble.left.and.bubble.right"
        case "Page":
            return "doc.plaintext"
        case "File":
            return "paperclip"
        case "Quiz":
            return "checklist"
        case "SubHeader":
            return "text.line.first.and.arrowtriangle.forward"
        case "ExternalUrl", "ExternalTool":
            return "link"
        default:
            return "circle.dashed"
        }
    }

    var actionableURL: URL? {
        contentDetails?.htmlURL ?? htmlURL
    }

    var dueAt: Date? {
        contentDetails?.dueAt
    }

    var isLockedForUser: Bool {
        contentDetails?.lockedForUser ?? false
    }

    var pointsDescription: String? {
        guard let points = contentDetails?.pointsPossible else {
            return nil
        }

        if points.rounded() == points {
            return "\(Int(points)) pts"
        }

        return String(format: "%.1f pts", points)
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(
            query,
            in: title,
            type,
            pageURL,
            contentDetails?.lockExplanation,
            pointsDescription
        )
    }
}

struct ModuleItemContentDetails: Codable, Hashable {
    let pointsPossible: Double?
    let dueAt: Date?
    let unlockAt: Date?
    let lockAt: Date?
    let lockedForUser: Bool?
    let lockExplanation: String?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case pointsPossible = "points_possible"
        case dueAt = "due_at"
        case unlockAt = "unlock_at"
        case lockAt = "lock_at"
        case lockedForUser = "locked_for_user"
        case lockExplanation = "lock_explanation"
        case htmlURL = "html_url"
    }
}

struct CanvasFolder: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String?
    let parentFolderID: Int?
    let filesCount: Int?
    let foldersCount: Int?
    let position: Int?
    let locked: Bool?
    let hidden: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case parentFolderID = "parent_folder_id"
        case filesCount = "files_count"
        case foldersCount = "folders_count"
        case position
        case locked
        case hidden
    }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Untitled Folder" : trimmedName
    }

    var sortName: String {
        (fullName ?? name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var itemCountDescription: String {
        let fileCount = filesCount ?? 0
        let folderCount = foldersCount ?? 0

        if fileCount == 0 && folderCount == 0 {
            return "No items"
        }

        let fileText = fileCount == 1 ? "1 file" : "\(fileCount) files"
        let folderText = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
        return "\(fileText) · \(folderText)"
    }

    var isUnavailable: Bool {
        locked == true || hidden == true
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(query, in: name, fullName, itemCountDescription)
    }
}

struct CanvasFile: Codable, Identifiable, Hashable {
    let id: Int
    let uuid: String?
    let folderID: Int?
    let displayName: String?
    let filename: String
    let contentType: String?
    let url: URL?
    let htmlURL: URL?
    let size: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let unlockAt: Date?
    let locked: Bool?
    let hidden: Bool?
    let lockedForUser: Bool?
    let hiddenForUser: Bool?
    let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case folderID = "folder_id"
        case displayName = "display_name"
        case filename
        case contentType = "content-type"
        case url
        case htmlURL = "html_url"
        case size
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case unlockAt = "unlock_at"
        case locked
        case hidden
        case lockedForUser = "locked_for_user"
        case hiddenForUser = "hidden_for_user"
        case thumbnailURL = "thumbnail_url"
    }

    var name: String {
        let preferredName = displayName ?? filename
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Untitled File" : trimmedName
    }

    var sizeDescription: String? {
        guard let size else {
            return nil
        }

        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var actionableURL: URL? {
        htmlURL ?? url
    }

    var isUnavailable: Bool {
        locked == true || hidden == true || lockedForUser == true || hiddenForUser == true
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(query, in: name, filename, contentType, sizeDescription)
    }
}

struct CanvasAssignment: Codable, Hashable {
    let id: Int
    let name: String
    let dueAt: Date?
    let courseID: Int?
    let htmlURL: URL?
    let pointsPossible: Double?

    init(
        id: Int,
        name: String,
        dueAt: Date?,
        courseID: Int?,
        htmlURL: URL?,
        pointsPossible: Double?
    ) {
        self.id = id
        self.name = name
        self.dueAt = dueAt
        self.courseID = courseID
        self.htmlURL = htmlURL
        self.pointsPossible = pointsPossible
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dueAt = "due_at"
        case courseID = "course_id"
        case htmlURL = "html_url"
        case pointsPossible = "points_possible"
    }
}

enum CourseAssignmentStatus: String, Codable, Hashable {
    case missing = "Missing"
    case late = "Late"
    case graded = "Graded"
    case submitted = "Submitted"
    case upcoming = "Upcoming"
    case unscheduled = "No Due Date"
    case excused = "Excused"
}

enum DashboardEventWindow: String, Codable, Hashable {
    case today
    case thisWeek
    case later
}

struct AssignmentSubmission: Codable, Hashable {
    let submittedAt: Date?
    let gradedAt: Date?
    let score: Double?
    let grade: String?
    let workflowState: String?
    let late: Bool?
    let missing: Bool?
    let excused: Bool?
    let submissionType: String?
    let attempt: Int?

    enum CodingKeys: String, CodingKey {
        case submittedAt = "submitted_at"
        case gradedAt = "graded_at"
        case score
        case grade
        case workflowState = "workflow_state"
        case late
        case missing
        case excused
        case submissionType = "submission_type"
        case attempt
    }

    var isSubmitted: Bool {
        if excused == true {
            return true
        }

        switch workflowState {
        case "submitted", "graded", "pending_review", "complete":
            return true
        default:
            return submittedAt != nil
        }
    }

    var isGraded: Bool {
        gradedAt != nil || score != nil || workflowState == "graded"
    }
}

struct CourseAssignment: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let details: String?
    let dueAt: Date?
    let unlockAt: Date?
    let lockAt: Date?
    let htmlURL: URL?
    let courseID: Int?
    let pointsPossible: Double?
    let submissionTypes: [String]?
    let hasSubmittedSubmissions: Bool?
    let published: Bool?
    let gradingType: String?
    let submission: AssignmentSubmission?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case details = "description"
        case dueAt = "due_at"
        case unlockAt = "unlock_at"
        case lockAt = "lock_at"
        case htmlURL = "html_url"
        case courseID = "course_id"
        case pointsPossible = "points_possible"
        case submissionTypes = "submission_types"
        case hasSubmittedSubmissions = "has_submitted_submissions"
        case published
        case gradingType = "grading_type"
        case submission
    }

    var status: CourseAssignmentStatus {
        if submission?.excused == true {
            return .excused
        }

        if submission?.missing == true {
            return .missing
        }

        if submission?.late == true, submission?.isGraded != true {
            return .late
        }

        if submission?.isGraded == true {
            return .graded
        }

        if submission?.isSubmitted == true || hasSubmittedSubmissions == true {
            return .submitted
        }

        guard let dueAt else {
            return .unscheduled
        }

        return dueAt < Date() ? .missing : .upcoming
    }

    var isCompleted: Bool {
        switch status {
        case .graded, .submitted, .excused:
            return true
        case .missing, .late, .upcoming, .unscheduled:
            return false
        }
    }

    var isUpcoming: Bool {
        guard let dueAt else {
            return false
        }

        return !isCompleted && dueAt >= Date()
    }

    var summaryText: String? {
        guard let details, !details.isEmpty else {
            return nil
        }

        let strippedText = details
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return strippedText.isEmpty ? nil : strippedText
    }

    var pointsDescription: String? {
        Self.formattedPoints(pointsPossible)
    }

    var scoreDescription: String? {
        guard let score = submission?.score else {
            return nil
        }

        let formattedScore = Self.formattedPoints(score) ?? "\(score)"

        if let pointsDescription {
            return "\(formattedScore) / \(pointsDescription)"
        }

        return formattedScore
    }

    var gradeDescription: String? {
        guard let grade = submission?.grade?.trimmingCharacters(in: .whitespacesAndNewlines), !grade.isEmpty else {
            return nil
        }

        return grade
    }

    var recentActivityDate: Date? {
        submission?.gradedAt ?? submission?.submittedAt ?? dueAt
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(
            query,
            in: name,
            summaryText,
            status.rawValue,
            pointsDescription,
            scoreDescription,
            gradeDescription,
            gradingType,
            submissionTypes?.joined(separator: " ")
        )
    }

    private static func formattedPoints(_ value: Double?) -> String? {
        guard let value else {
            return nil
        }

        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.1f", value)
    }
}

struct UpcomingEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let details: String?
    let startAt: Date?
    let endAt: Date?
    let allDay: Bool
    let contextCode: String?
    let htmlURL: URL?
    let workflowState: String?
    let assignment: CanvasAssignment?

    init(
        id: String,
        title: String,
        details: String?,
        startAt: Date?,
        endAt: Date?,
        allDay: Bool,
        contextCode: String?,
        htmlURL: URL?,
        workflowState: String?,
        assignment: CanvasAssignment?
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.contextCode = contextCode
        self.htmlURL = htmlURL
        self.workflowState = workflowState
        self.assignment = assignment
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case details = "description"
        case startAt = "start_at"
        case endAt = "end_at"
        case allDay = "all_day"
        case contextCode = "context_code"
        case htmlURL = "html_url"
        case workflowState = "workflow_state"
        case assignment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(FlexibleIdentifier.self, forKey: .id).stringValue
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        startAt = try container.decodeIfPresent(Date.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt)
        allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        contextCode = try container.decodeIfPresent(String.self, forKey: .contextCode)
        htmlURL = try container.decodeIfPresent(URL.self, forKey: .htmlURL)
        workflowState = try container.decodeIfPresent(String.self, forKey: .workflowState)
        assignment = try container.decodeIfPresent(CanvasAssignment.self, forKey: .assignment)
    }

    var courseID: Int? {
        if let courseID = assignment?.courseID {
            return courseID
        }

        guard let contextCode, contextCode.hasPrefix("course_") else {
            return nil
        }

        return Int(contextCode.replacingOccurrences(of: "course_", with: ""))
    }

    var actionableURL: URL? {
        assignment?.htmlURL ?? htmlURL
    }

    var displayDate: Date? {
        assignment?.dueAt ?? endAt ?? startAt
    }

    var isAssignment: Bool {
        assignment != nil
    }

    var kindLabel: String {
        isAssignment ? "Assignment" : "Event"
    }

    func dashboardWindow(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> DashboardEventWindow? {
        guard let displayDate else {
            return nil
        }

        if calendar.isDate(displayDate, inSameDayAs: referenceDate) {
            return .today
        }

        guard displayDate >= referenceDate else {
            return nil
        }

        guard let weekEndDate = calendar.date(byAdding: .day, value: 7, to: referenceDate) else {
            return .later
        }

        return displayDate <= weekEndDate ? .thisWeek : .later
    }
}

struct MissingSubmission: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let dueAt: Date?
    let courseID: Int?
    let htmlURL: URL?
    let pointsPossible: Double?

    init(
        id: Int,
        name: String,
        dueAt: Date?,
        courseID: Int?,
        htmlURL: URL?,
        pointsPossible: Double?
    ) {
        self.id = id
        self.name = name
        self.dueAt = dueAt
        self.courseID = courseID
        self.htmlURL = htmlURL
        self.pointsPossible = pointsPossible
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dueAt = "due_at"
        case courseID = "course_id"
        case htmlURL = "html_url"
        case pointsPossible = "points_possible"
    }

    func isOverdue(referenceDate: Date = Date()) -> Bool {
        guard let dueAt else {
            return false
        }

        return dueAt < referenceDate
    }
}

struct UserProfile: Codable, Hashable {
    let id: Int
    let name: String
    let shortName: String?
    let primaryEmail: String?
    let loginID: String?
    let avatarURL: URL?
    let title: String?
    let bio: String?
    let timeZone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case shortName = "short_name"
        case primaryEmail = "primary_email"
        case loginID = "login_id"
        case avatarURL = "avatar_url"
        case title
        case bio
        case timeZone = "time_zone"
    }
}

struct CanvasSnapshot: Codable {
    let courses: [Course]
    let upcomingEvents: [UpcomingEvent]
    let missingSubmissions: [MissingSubmission]
    let profile: UserProfile?
    let syncedAt: Date
}

private struct FlexibleIdentifier: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            stringValue = String(intValue)
            return
        }

        stringValue = try container.decode(String.self)
    }
}

private func workspaceSearchMatches(_ query: String, in values: String?...) -> Bool {
    let normalizedQuery = query.normalizedWorkspaceSearchText
    guard !normalizedQuery.isEmpty else {
        return true
    }

    return values.contains { value in
        value?.normalizedWorkspaceSearchText.contains(normalizedQuery) == true
    }
}

private extension String {
    var normalizedWorkspaceSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
