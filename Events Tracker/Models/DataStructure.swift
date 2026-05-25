//
//  DataStructure.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

struct TelegramReminderConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var botToken: String = ""
    var chatID: String = ""
    var reminderWindowHours: Int = 24
    var checkIntervalMinutes: Int = 30
    var repeatIntervalHours: Int = 24

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case botToken
        case chatID
        case reminderWindowHours
        case checkIntervalMinutes
        case repeatIntervalHours
    }

    init(
        isEnabled: Bool = false,
        botToken: String = "",
        chatID: String = "",
        reminderWindowHours: Int = 24,
        checkIntervalMinutes: Int = 30,
        repeatIntervalHours: Int = 24
    ) {
        self.isEnabled = isEnabled
        self.botToken = botToken
        self.chatID = chatID
        self.reminderWindowHours = reminderWindowHours
        self.checkIntervalMinutes = checkIntervalMinutes
        self.repeatIntervalHours = repeatIntervalHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        botToken = try container.decodeIfPresent(String.self, forKey: .botToken) ?? ""
        chatID = try container.decodeIfPresent(String.self, forKey: .chatID) ?? ""
        reminderWindowHours = try container.decodeIfPresent(Int.self, forKey: .reminderWindowHours) ?? 24
        checkIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .checkIntervalMinutes) ?? 30
        repeatIntervalHours = try container.decodeIfPresent(Int.self, forKey: .repeatIntervalHours) ?? 24
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(chatID, forKey: .chatID)
        try container.encode(reminderWindowHours, forKey: .reminderWindowHours)
        try container.encode(checkIntervalMinutes, forKey: .checkIntervalMinutes)
        try container.encode(repeatIntervalHours, forKey: .repeatIntervalHours)
    }

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

enum DownloadCacheLimitPreset: String, Codable, CaseIterable, Identifiable {
    case fiveHundredMB
    case oneGB
    case twoGB
    case fiveGB
    case unlimited

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveHundredMB:
            return "512 MB"
        case .oneGB:
            return "1 GB"
        case .twoGB:
            return "2 GB"
        case .fiveGB:
            return "5 GB"
        case .unlimited:
            return "Unlimited"
        }
    }

    var byteLimit: Int? {
        switch self {
        case .fiveHundredMB:
            return 512 * 1_024 * 1_024
        case .oneGB:
            return 1 * 1_024 * 1_024 * 1_024
        case .twoGB:
            return 2 * 1_024 * 1_024 * 1_024
        case .fiveGB:
            return 5 * 1_024 * 1_024 * 1_024
        case .unlimited:
            return nil
        }
    }
}

struct CanvasConfig: Codable, Equatable {
    var baseURL: String = ""
    var token: String = ""
    var lookaheadDays: Int = 14
    var telegramReminders: TelegramReminderConfig = TelegramReminderConfig()
    var downloadCacheLimit: DownloadCacheLimitPreset = .unlimited

    enum CodingKeys: String, CodingKey {
        case baseURL
        case token
        case lookaheadDays
        case telegramReminders
        case downloadCacheLimit
    }

    init(
        baseURL: String = "",
        token: String = "",
        lookaheadDays: Int = 14,
        telegramReminders: TelegramReminderConfig = TelegramReminderConfig(),
        downloadCacheLimit: DownloadCacheLimitPreset = .unlimited
    ) {
        self.baseURL = baseURL
        self.token = token
        self.lookaheadDays = lookaheadDays
        self.telegramReminders = telegramReminders
        self.downloadCacheLimit = downloadCacheLimit
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
        downloadCacheLimit = try container.decodeIfPresent(
            DownloadCacheLimitPreset.self,
            forKey: .downloadCacheLimit
        ) ?? .unlimited
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(lookaheadDays, forKey: .lookaheadDays)
        try container.encode(telegramReminders, forKey: .telegramReminders)
        try container.encode(downloadCacheLimit, forKey: .downloadCacheLimit)
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

    var supportsNativeDetail: Bool {
        switch type {
        case "Quiz", "Discussion", "Page":
            return true
        default:
            return false
        }
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

struct CourseModuleItemDetailKey: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    static func quiz(courseID: Int, quizID: Int) -> CourseModuleItemDetailKey {
        CourseModuleItemDetailKey(rawValue: "quiz:\(courseID):\(quizID)")
    }

    static func discussion(courseID: Int, discussionID: Int) -> CourseModuleItemDetailKey {
        CourseModuleItemDetailKey(rawValue: "discussion:\(courseID):\(discussionID)")
    }

    static func page(courseID: Int, pageURL: String) -> CourseModuleItemDetailKey {
        CourseModuleItemDetailKey(rawValue: "page:\(courseID):\(pageURL)")
    }

    static func key(courseID: Int, item: CourseModuleItem) -> CourseModuleItemDetailKey? {
        switch item.type {
        case "Quiz":
            guard let contentID = item.contentID else {
                return nil
            }

            return .quiz(courseID: courseID, quizID: contentID)
        case "Discussion":
            guard let contentID = item.contentID else {
                return nil
            }

            return .discussion(courseID: courseID, discussionID: contentID)
        case "Page":
            guard let pageURL = item.pageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !pageURL.isEmpty else {
                return nil
            }

            return .page(courseID: courseID, pageURL: pageURL)
        default:
            return nil
        }
    }

    var courseID: Int? {
        let parts = rawValue.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            return nil
        }

        return Int(parts[1])
    }

    var contentIdentifier: String? {
        let parts = rawValue.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3 else {
            return nil
        }

        return parts[2]
    }
}

struct CourseQuizDetail: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let htmlURL: URL?
    let quizType: String?
    let dueAt: Date?
    let unlockAt: Date?
    let lockAt: Date?
    let pointsPossible: Double?
    let questionCount: Int?
    let allowedAttempts: Int?
    let timeLimit: Int?
    let published: Bool?
    let lockedForUser: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case htmlURL = "html_url"
        case quizType = "quiz_type"
        case dueAt = "due_at"
        case unlockAt = "unlock_at"
        case lockAt = "lock_at"
        case pointsPossible = "points_possible"
        case questionCount = "question_count"
        case allowedAttempts = "allowed_attempts"
        case timeLimit = "time_limit"
        case published
        case lockedForUser = "locked_for_user"
    }

    var summaryText: String? {
        strippedCanvasHTML(description)
    }

    var displayTitle: String { title }
}

struct CourseDiscussionAuthor: Codable, Hashable {
    let id: Int?
    let displayName: String?
    let avatarImageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarImageURL = "avatar_image_url"
    }
}

struct CourseDiscussionDetail: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let message: String?
    let htmlURL: URL?
    let postedAt: Date?
    let delayedPostAt: Date?
    let lastReplyAt: Date?
    let discussionSubentryCount: Int?
    let unreadCount: Int?
    let locked: Bool?
    let lockedForUser: Bool?
    let pinned: Bool?
    let published: Bool?
    let requireInitialPost: Bool?
    let userName: String?
    let author: CourseDiscussionAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case htmlURL = "html_url"
        case postedAt = "posted_at"
        case delayedPostAt = "delayed_post_at"
        case lastReplyAt = "last_reply_at"
        case discussionSubentryCount = "discussion_subentry_count"
        case unreadCount = "unread_count"
        case locked
        case lockedForUser = "locked_for_user"
        case pinned
        case published
        case requireInitialPost = "require_initial_post"
        case userName = "user_name"
        case author
    }

    var summaryText: String? {
        strippedCanvasHTML(message)
    }

    var authorName: String? {
        author?.displayName ?? userName
    }

    var displayTitle: String { title }
}

struct CoursePageDetail: Codable, Identifiable, Hashable {
    let pageID: Int?
    let url: String
    let title: String
    let body: String?
    let htmlURL: URL?
    let frontPage: Bool?
    let published: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case pageID = "page_id"
        case url
        case title
        case body
        case htmlURL = "html_url"
        case frontPage = "front_page"
        case published
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var id: String { url }

    var summaryText: String? {
        strippedCanvasHTML(body)
    }

    var displayTitle: String { title }
}

enum CourseModuleItemDetail: Codable, Hashable {
    case quiz(CourseQuizDetail)
    case discussion(CourseDiscussionDetail)
    case page(CoursePageDetail)

    enum CodingKeys: String, CodingKey {
        case type
        case quiz
        case discussion
        case page
    }

    enum DetailType: String, Codable {
        case quiz
        case discussion
        case page
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DetailType.self, forKey: .type)

        switch type {
        case .quiz:
            self = .quiz(try container.decode(CourseQuizDetail.self, forKey: .quiz))
        case .discussion:
            self = .discussion(try container.decode(CourseDiscussionDetail.self, forKey: .discussion))
        case .page:
            self = .page(try container.decode(CoursePageDetail.self, forKey: .page))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .quiz(let detail):
            try container.encode(DetailType.quiz, forKey: .type)
            try container.encode(detail, forKey: .quiz)
        case .discussion(let detail):
            try container.encode(DetailType.discussion, forKey: .type)
            try container.encode(detail, forKey: .discussion)
        case .page(let detail):
            try container.encode(DetailType.page, forKey: .type)
            try container.encode(detail, forKey: .page)
        }
    }
}

struct CourseWorkspacePreference: Codable, Equatable {
    var searchQuery: String
    var filter: String
    var sort: String

    init(searchQuery: String = "", filter: String = "All", sort: String = "") {
        self.searchQuery = searchQuery
        self.filter = filter
        self.sort = sort
    }
}

struct SingleCoursePreference: Codable, Equatable {
    var workspaceSection: String
    var modules: CourseWorkspacePreference
    var files: CourseWorkspacePreference
    var announcements: CourseWorkspacePreference
    var assignments: CourseWorkspacePreference
    var grades: CourseWorkspacePreference
    var people: CourseWorkspacePreference

    init(
        workspaceSection: String = "Overview",
        modules: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Canvas Order"),
        files: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Canvas Order"),
        announcements: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Recent"),
        assignments: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Due Date"),
        grades: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Recent"),
        people: CourseWorkspacePreference = CourseWorkspacePreference(sort: "Role")
    ) {
        self.workspaceSection = workspaceSection
        self.modules = modules
        self.files = files
        self.announcements = announcements
        self.assignments = assignments
        self.grades = grades
        self.people = people
    }
}

struct CoursePreferencesSnapshot: Codable, Equatable {
    var pinnedCourseIDs: Set<Int>
    var hiddenCourseIDs: Set<Int>
    var offlinePriorityCourseIDs: Set<Int>
    var showsHiddenCourses: Bool
    var defaultCourseID: Int?
    var defaultEventsCourseID: Int?
    var preferencesByCourseID: [Int: SingleCoursePreference]

    enum CodingKeys: String, CodingKey {
        case pinnedCourseIDs
        case hiddenCourseIDs
        case offlinePriorityCourseIDs
        case showsHiddenCourses
        case defaultCourseID
        case defaultEventsCourseID
        case preferencesByCourseID
    }

    init(
        pinnedCourseIDs: Set<Int> = [],
        hiddenCourseIDs: Set<Int> = [],
        offlinePriorityCourseIDs: Set<Int> = [],
        showsHiddenCourses: Bool = false,
        defaultCourseID: Int? = nil,
        defaultEventsCourseID: Int? = nil,
        preferencesByCourseID: [Int: SingleCoursePreference] = [:]
    ) {
        self.pinnedCourseIDs = pinnedCourseIDs
        self.hiddenCourseIDs = hiddenCourseIDs
        self.offlinePriorityCourseIDs = offlinePriorityCourseIDs
        self.showsHiddenCourses = showsHiddenCourses
        self.defaultCourseID = defaultCourseID
        self.defaultEventsCourseID = defaultEventsCourseID
        self.preferencesByCourseID = preferencesByCourseID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pinnedCourseIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .pinnedCourseIDs) ?? []
        hiddenCourseIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .hiddenCourseIDs) ?? []
        offlinePriorityCourseIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .offlinePriorityCourseIDs) ?? []
        showsHiddenCourses = try container.decodeIfPresent(Bool.self, forKey: .showsHiddenCourses) ?? false
        defaultCourseID = try container.decodeIfPresent(Int.self, forKey: .defaultCourseID)
        defaultEventsCourseID = try container.decodeIfPresent(Int.self, forKey: .defaultEventsCourseID)
        preferencesByCourseID = try container.decodeIfPresent(
            [Int: SingleCoursePreference].self,
            forKey: .preferencesByCourseID
        ) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pinnedCourseIDs, forKey: .pinnedCourseIDs)
        try container.encode(hiddenCourseIDs, forKey: .hiddenCourseIDs)
        try container.encode(offlinePriorityCourseIDs, forKey: .offlinePriorityCourseIDs)
        try container.encode(showsHiddenCourses, forKey: .showsHiddenCourses)
        try container.encodeIfPresent(defaultCourseID, forKey: .defaultCourseID)
        try container.encodeIfPresent(defaultEventsCourseID, forKey: .defaultEventsCourseID)
        try container.encode(preferencesByCourseID, forKey: .preferencesByCourseID)
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

enum FileDownloadState: String, Codable, CaseIterable, Hashable, Identifiable {
    case notDownloaded
    case downloading
    case downloaded
    case failed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading:
            return "Downloading"
        case .downloaded:
            return "Downloaded"
        case .failed:
            return "Failed"
        }
    }
}

struct FileDownloadRecord: Codable, Identifiable, Hashable {
    let fileID: Int
    var courseID: Int?
    var folderID: Int?
    var file: CanvasFile
    var state: FileDownloadState
    var localPath: String?
    var downloadedAt: Date?
    var failureMessage: String?
    var byteCount: Int?

    var id: Int { fileID }

    init(
        fileID: Int,
        courseID: Int?,
        folderID: Int?,
        file: CanvasFile,
        state: FileDownloadState = .notDownloaded,
        localPath: String? = nil,
        downloadedAt: Date? = nil,
        failureMessage: String? = nil,
        byteCount: Int? = nil
    ) {
        self.fileID = fileID
        self.courseID = courseID
        self.folderID = folderID
        self.file = file
        self.state = state
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.failureMessage = failureMessage
        self.byteCount = byteCount
    }

    var isDownloaded: Bool {
        state == .downloaded && localPath != nil
    }

    var localPreviewURL: URL? {
        guard state == .downloaded, let localPath else {
            return nil
        }

        let url = URL(fileURLWithPath: localPath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var typeLabel: String {
        guard let contentType = file.contentType?.trimmingCharacters(in: .whitespacesAndNewlines), !contentType.isEmpty else {
            return "Unknown"
        }

        if contentType.contains("pdf") {
            return "PDF"
        }

        if contentType.hasPrefix("image/") {
            return "Image"
        }

        if contentType.hasPrefix("video/") {
            return "Video"
        }

        if contentType.hasPrefix("audio/") {
            return "Audio"
        }

        if contentType.contains("word") || contentType.contains("document") {
            return "Document"
        }

        if contentType.contains("spreadsheet") || contentType.contains("excel") {
            return "Spreadsheet"
        }

        if contentType.contains("presentation") || contentType.contains("powerpoint") {
            return "Presentation"
        }

        return contentType
    }

    var displaySize: String? {
        let size = byteCount ?? file.size
        guard let size else {
            return nil
        }

        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    func matchesSearch(_ query: String, courseName: String?) -> Bool {
        workspaceSearchMatches(query, in: file.name, file.filename, file.contentType, typeLabel, courseName, failureMessage)
    }

    static func safeFilename(for file: CanvasFile) -> String {
        let fallbackName = "file-\(file.id)"
        let rawName = file.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackName : file.name
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let components = rawName.components(separatedBy: invalidCharacters)
        let sanitized = components
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? fallbackName : sanitized
    }
}

struct FileDownloadSnapshot: Codable, Equatable {
    var recordsByFileID: [Int: FileDownloadRecord]
    var updatedAt: Date?

    init(recordsByFileID: [Int: FileDownloadRecord] = [:], updatedAt: Date? = nil) {
        self.recordsByFileID = recordsByFileID
        self.updatedAt = updatedAt
    }

    var records: [FileDownloadRecord] {
        recordsByFileID.values.sorted {
            $0.file.name.localizedCaseInsensitiveCompare($1.file.name) == .orderedAscending
        }
    }

    var downloadedRecords: [FileDownloadRecord] {
        records.filter { $0.state == .downloaded }
    }

    var downloadedByteCount: Int {
        downloadedRecords.reduce(0) { partialResult, record in
            partialResult + (record.byteCount ?? record.file.size ?? 0)
        }
    }
}

enum GlobalSearchResultKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case course = "Course"
    case assignment = "Assignment"
    case event = "Event"
    case missing = "Missing"
    case module = "Module"
    case moduleItem = "Module Item"
    case file = "File"
    case folder = "Folder"
    case announcement = "Announcement"
    case syllabus = "Syllabus"
    case person = "Person"
    case detail = "Detail"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .course: return "books.vertical"
        case .assignment: return "checklist"
        case .event: return "calendar"
        case .missing: return "exclamationmark.circle"
        case .module: return "rectangle.stack"
        case .moduleItem: return "doc.text"
        case .file: return "doc"
        case .folder: return "folder"
        case .announcement: return "megaphone"
        case .syllabus: return "doc.richtext"
        case .person: return "person"
        case .detail: return "doc.text.magnifyingglass"
        }
    }
}

struct GlobalSearchResult: Identifiable, Hashable {
    let id: String
    let kind: GlobalSearchResultKind
    let title: String
    let subtitle: String?
    let courseID: Int?
    let courseName: String?
    let url: URL?
    let searchableText: String
    let score: Int

    func matchesKind(_ kind: GlobalSearchResultKind?) -> Bool {
        guard let kind else {
            return true
        }

        return self.kind == kind
    }
}

struct CourseAnnouncement: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let message: String?
    let postedAt: Date?
    let delayedPostAt: Date?
    let contextCode: String?
    let htmlURL: URL?
    let readState: String?
    let lockedForUser: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case postedAt = "posted_at"
        case delayedPostAt = "delayed_post_at"
        case contextCode = "context_code"
        case htmlURL = "html_url"
        case readState = "read_state"
        case lockedForUser = "locked_for_user"
    }

    var summaryText: String? {
        strippedCanvasHTML(message)
    }

    var displayDate: Date? {
        postedAt ?? delayedPostAt
    }

    var courseID: Int? {
        guard let contextCode, contextCode.hasPrefix("course_") else {
            return nil
        }

        return Int(contextCode.replacingOccurrences(of: "course_", with: ""))
    }

    var isUnread: Bool {
        readState?.localizedCaseInsensitiveCompare("unread") == .orderedSame
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(
            query,
            in: title,
            summaryText,
            readState
        )
    }
}

struct CourseSyllabus: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let syllabusBody: String?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case syllabusBody = "syllabus_body"
        case htmlURL = "html_url"
    }

    var summaryText: String? {
        strippedCanvasHTML(syllabusBody)
    }

    var hasContent: Bool {
        summaryText?.isEmpty == false
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(query, in: name, summaryText)
    }
}

enum CoursePersonRole: String, Codable, CaseIterable, Hashable {
    case teacher
    case ta
    case student
    case observer
    case designer
    case other

    var label: String {
        switch self {
        case .teacher:
            return "Teacher"
        case .ta:
            return "TA"
        case .student:
            return "Student"
        case .observer:
            return "Observer"
        case .designer:
            return "Designer"
        case .other:
            return "Other"
        }
    }

    var sortPriority: Int {
        switch self {
        case .teacher:
            return 0
        case .ta:
            return 1
        case .designer:
            return 2
        case .student:
            return 3
        case .observer:
            return 4
        case .other:
            return 5
        }
    }

    static func normalized(from rawValues: [String]) -> CoursePersonRole {
        let roleText = rawValues
            .joined(separator: " ")
            .lowercased()

        if roleText.contains("teacher") {
            return .teacher
        }

        if roleText.contains("ta") || roleText.contains("assistant") {
            return .ta
        }

        if roleText.contains("student") {
            return .student
        }

        if roleText.contains("observer") {
            return .observer
        }

        if roleText.contains("designer") {
            return .designer
        }

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

    var displayName: String {
        shortName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? shortName! : name
    }

    var initials: String {
        let parts = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        let value = String(parts).uppercased()
        return value.isEmpty ? "?" : value
    }

    var primaryEnrollment: CoursePersonEnrollment? {
        enrollments?.first
    }

    var primaryRole: CoursePersonRole {
        CoursePersonRole.normalized(
            from: enrollments?.flatMap { enrollment in
                [enrollment.type, enrollment.role].compactMap { $0 }
            } ?? []
        )
    }

    var roleLabel: String {
        primaryRole.label
    }

    var sectionLabel: String? {
        primaryEnrollment?.sectionName?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var lastActivityAt: Date? {
        enrollments?.compactMap(\.lastActivityAt).max()
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(
            query,
            in: name,
            sortableName,
            shortName,
            email,
            loginID,
            sectionLabel,
            roleLabel
        )
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
        strippedCanvasHTML(details)
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

    var canvasURL: URL? {
        htmlURL
    }

    var submissionURL: URL? {
        guard let canvasURL else {
            return nil
        }

        let path = canvasURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = path.split(separator: "/")
        guard components.count >= 4,
              components[0] == "courses",
              components[2] == "assignments"
        else {
            return canvasURL
        }

        var submissionURL = canvasURL
        submissionURL.append(path: "submissions")
        return submissionURL
    }

    var showsSubmissionAction: Bool {
        if submission?.isSubmitted == true || hasSubmittedSubmissions == true {
            return submissionURL != nil
        }

        guard let submissionTypes else {
            return submissionURL != nil
        }

        let normalizedSubmissionTypes = Set(
            submissionTypes.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )
        let blockedSubmissionTypes: Set<String> = ["none", "on_paper"]
        return !normalizedSubmissionTypes.isDisjoint(with: blockedSubmissionTypes) ? false : submissionURL != nil
    }

    var submissionActionTitle: String {
        submission?.isSubmitted == true || hasSubmittedSubmissions == true ? "View Submission" : "Open Submission"
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

struct CalendarEventItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case upcoming(UpcomingEvent)
        case missing(MissingSubmission)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .upcoming(let event):
            return "upcoming-\(event.id)"
        case .missing(let submission):
            return "missing-\(submission.id)"
        }
    }

    var title: String {
        switch kind {
        case .upcoming(let event):
            return event.title
        case .missing(let submission):
            return submission.name
        }
    }

    var date: Date? {
        switch kind {
        case .upcoming(let event):
            return event.displayDate
        case .missing(let submission):
            return submission.dueAt
        }
    }

    var courseID: Int? {
        switch kind {
        case .upcoming(let event):
            return event.courseID
        case .missing(let submission):
            return submission.courseID
        }
    }

    var actionableURL: URL? {
        switch kind {
        case .upcoming(let event):
            return event.actionableURL
        case .missing(let submission):
            return submission.htmlURL
        }
    }

    var isMissing: Bool {
        if case .missing = kind {
            return true
        }

        return false
    }

    var isUpcoming: Bool {
        if case .upcoming = kind {
            return true
        }

        return false
    }

    var kindLabel: String {
        isMissing ? "Missing" : "Upcoming"
    }

    static func items(
        upcomingEvents: [UpcomingEvent],
        missingSubmissions: [MissingSubmission]
    ) -> [CalendarEventItem] {
        let items = upcomingEvents.map { CalendarEventItem(kind: .upcoming($0)) }
            + missingSubmissions.map { CalendarEventItem(kind: .missing($0)) }

        return items.sorted(by: sort)
    }

    static func datedItems(
        _ items: [CalendarEventItem],
        on day: Date,
        calendar: Calendar = .current
    ) -> [CalendarEventItem] {
        items.filter { item in
            guard let date = item.date else {
                return false
            }

            return calendar.isDate(date, inSameDayAs: day)
        }
    }

    static func groupByDay(
        _ items: [CalendarEventItem],
        calendar: Calendar = .current
    ) -> [Date: [CalendarEventItem]] {
        let pairs = items.compactMap { item -> (Date, CalendarEventItem)? in
            guard let date = item.date else {
                return nil
            }

            return (calendar.startOfDay(for: date), item)
        }

        return Dictionary(grouping: pairs, by: \.0)
            .mapValues { values in
                values.map(\.1).sorted(by: sort)
            }
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
        var currentDate = calendar.startOfDay(for: firstWeek.start)
        let endDate = calendar.startOfDay(for: lastWeek.end)

        while currentDate < endDate {
            days.append(currentDate)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }

            currentDate = nextDate
        }

        return days
    }

    static func visibleWeekDays(
        containing date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfMonth, for: date) else {
            return []
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: weekInterval.start))
        }
    }

    private static func sort(_ lhs: CalendarEventItem, _ rhs: CalendarEventItem) -> Bool {
        switch (lhs.date, rhs.date) {
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

        if lhs.isMissing != rhs.isMissing {
            return lhs.isMissing
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

enum CanvasConversationWorkflowState: String, Codable, CaseIterable, Hashable, Identifiable {
    case read
    case unread
    case archived

    var id: String { rawValue }

    var label: String {
        switch self {
        case .read:
            return "Read"
        case .unread:
            return "Unread"
        case .archived:
            return "Archived"
        }
    }
}

struct CanvasConversationParticipant: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case avatarURL = "avatar_url"
    }

    var displayName: String {
        let preferredName = fullName ?? name
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Unknown Participant" : trimmedName
    }
}

struct CanvasConversationAudienceContexts: Codable, Hashable {
    let courses: [String: [String]]
    let groups: [String: [String]]

    var courseIDs: [Int] {
        courses.keys.compactMap(Int.init).sorted()
    }
}

struct CanvasConversation: Codable, Identifiable, Hashable {
    let id: Int
    let subject: String?
    let workflowState: CanvasConversationWorkflowState
    let lastMessage: String?
    let lastMessageAt: Date?
    let messageCount: Int?
    let subscribed: Bool?
    let starred: Bool?
    let audienceContexts: CanvasConversationAudienceContexts?
    let avatarURL: URL?
    let participants: [CanvasConversationParticipant]?
    let visible: Bool?
    let contextName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case workflowState = "workflow_state"
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case messageCount = "message_count"
        case subscribed
        case starred
        case audienceContexts = "audience_contexts"
        case avatarURL = "avatar_url"
        case participants
        case visible
        case contextName = "context_name"
    }

    var displaySubject: String {
        let trimmedSubject = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedSubject.isEmpty ? "No Subject" : trimmedSubject
    }

    var isUnread: Bool {
        workflowState == .unread
    }

    var isArchived: Bool {
        workflowState == .archived
    }

    var courseIDs: [Int] {
        audienceContexts?.courseIDs ?? []
    }

    var participantSummary: String {
        let names = (participants ?? []).map(\.displayName).filter { !$0.isEmpty }
        return names.isEmpty ? "No participants" : names.joined(separator: ", ")
    }

    func canvasURL(baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        var basePath = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        if basePath.hasSuffix("/api/v1") {
            basePath = String(basePath.dropLast("/api/v1".count))
        }

        components.path = basePath + "/conversations/\(id)"
        components.queryItems = nil
        return components.url
    }

    func matchesSearch(_ query: String) -> Bool {
        workspaceSearchMatches(
            query,
            in: displaySubject,
            lastMessage,
            participantSummary,
            contextName,
            workflowState.label
        )
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

private func strippedCanvasHTML(_ html: String?) -> String? {
    guard let html, !html.isEmpty else {
        return nil
    }

    let strippedText = html
        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return strippedText.isEmpty ? nil : strippedText
}

private extension String {
    var normalizedWorkspaceSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
