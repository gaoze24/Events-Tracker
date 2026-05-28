//
//  CanvasStore.swift
//  Events Tracker
//
//  Created by Codex on 13/4/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class CanvasStore: ObservableObject {
    enum BootstrapMode {
        case normal
        case uiTests
    }

    struct DashboardPriorityItem: Identifiable, Hashable {
        enum Kind: Hashable {
            case missing(MissingSubmission)
            case upcoming(UpcomingEvent)
        }

        let kind: Kind
        let score: Int

        var id: String {
            switch kind {
            case .missing(let submission):
                return "missing-\(submission.id)"
            case .upcoming(let event):
                return "event-\(event.id)"
            }
        }

        var title: String {
            switch kind {
            case .missing(let submission):
                return submission.name
            case .upcoming(let event):
                return event.title
            }
        }

        var subtitle: String {
            switch kind {
            case .missing:
                return "Missing Work"
            case .upcoming(let event):
                return event.kindLabel
            }
        }

        var courseID: Int? {
            switch kind {
            case .missing(let submission):
                return submission.courseID
            case .upcoming(let event):
                return event.courseID
            }
        }

        var date: Date? {
            switch kind {
            case .missing(let submission):
                return submission.dueAt
            case .upcoming(let event):
                return event.displayDate
            }
        }

        var actionableURL: URL? {
            switch kind {
            case .missing(let submission):
                return submission.htmlURL
            case .upcoming(let event):
                return event.actionableURL
            }
        }

        var isMissing: Bool {
            if case .missing = kind {
                return true
            }

            return false
        }

        var isAssignmentBackedEvent: Bool {
            if case .upcoming(let event) = kind {
                return event.isAssignment
            }

            return false
        }
    }

    @Published var config: CanvasConfig
    @Published private(set) var courses: [Course]
    @Published private(set) var courseAssignmentsByCourseID: [Int: [CourseAssignment]]
    @Published private(set) var loadingCourseAssignmentIDs: Set<Int>
    @Published private(set) var courseModulesByCourseID: [Int: [CourseModule]]
    @Published private(set) var loadingCourseModuleIDs: Set<Int>
    @Published private(set) var courseFoldersByCourseID: [Int: [CanvasFolder]]
    @Published private(set) var courseFilesByFolderID: [Int: [CanvasFile]]
    @Published private(set) var loadingCourseFolderIDs: Set<Int>
    @Published private(set) var loadingFolderFileIDs: Set<Int>
    @Published private(set) var courseAnnouncementsByCourseID: [Int: [CourseAnnouncement]]
    @Published private(set) var loadingCourseAnnouncementIDs: Set<Int>
    @Published private(set) var courseSyllabusByCourseID: [Int: CourseSyllabus]
    @Published private(set) var loadingCourseSyllabusIDs: Set<Int>
    @Published private(set) var coursePeopleByCourseID: [Int: [CoursePerson]]
    @Published private(set) var loadingCoursePeopleIDs: Set<Int>
    @Published private(set) var moduleItemDetailsByKey: [String: CourseModuleItemDetail]
    @Published private(set) var loadingModuleItemDetailKeys: Set<String>
    @Published private(set) var coursePreferences: CoursePreferencesSnapshot
    @Published private(set) var fileDownloadSnapshot: FileDownloadSnapshot
    @Published private(set) var downloadingFileIDs: Set<Int>
    @Published private(set) var offlineBulkDownloadProgress: OfflineBulkDownloadProgress?
    @Published private(set) var preloadingCourseIDs: Set<Int>
    @Published private(set) var recentSearchTerms: [String]
    @Published private(set) var inboxConversations: [CanvasConversation]
    @Published private(set) var loadingInbox: Bool
    @Published private(set) var inboxLastLoadedAt: Date?
    @Published private(set) var upcomingEvents: [UpcomingEvent]
    @Published private(set) var missingSubmissions: [MissingSubmission]
    @Published private(set) var profile: UserProfile?
    @Published private(set) var lastSyncedAt: Date?
    @Published var selectedCourseID: Int?
    @Published var isSyncing = false
    @Published var errorMessage: String?

    private let configManager: CanvasConfigManager
    private let databaseManager: DatabaseManager
    private let networkManager: NetworkManager
    private let detailCacheManager: CourseDetailCacheManager
    private let preferenceManager: CoursePreferenceManager
    private let fileDownloadManager: FileDownloadManager
    private let recentSearchManager: RecentSearchManager
    private let cachePolicy: CanvasCachePolicy
    private let reminderService: AssignmentReminderService
    private let relativeFormatter = RelativeDateTimeFormatter()
    private let now: () -> Date
    private var courseDetailAccessDates: [Int: Date]
    private var cacheMaintenanceTask: Task<Void, Never>?
    private var autoSyncTask: Task<Void, Never>?

    init(
        configManager: CanvasConfigManager = .shared,
        databaseManager: DatabaseManager = .shared,
        networkManager: NetworkManager = .shared,
        detailCacheManager: CourseDetailCacheManager = .shared,
        preferenceManager: CoursePreferenceManager = .shared,
        fileDownloadManager: FileDownloadManager = .shared,
        recentSearchManager: RecentSearchManager = .shared,
        cachePolicy: CanvasCachePolicy = .default,
        now: @escaping () -> Date = Date.init,
        bootstrapMode: BootstrapMode = .normal
    ) {
        self.configManager = configManager
        self.databaseManager = databaseManager
        self.networkManager = networkManager
        self.detailCacheManager = detailCacheManager
        self.preferenceManager = preferenceManager
        self.fileDownloadManager = fileDownloadManager
        self.recentSearchManager = recentSearchManager
        self.cachePolicy = cachePolicy
        self.now = now
        courseDetailAccessDates = [:]

        let savedConfig: CanvasConfig
        switch bootstrapMode {
        case .normal:
            savedConfig = configManager.loadConfig()
            coursePreferences = preferenceManager.loadPreferences()
            fileDownloadSnapshot = fileDownloadManager.loadSnapshot()
            recentSearchTerms = recentSearchManager.loadTerms()
        case .uiTests:
            savedConfig = CanvasConfig()
            coursePreferences = CoursePreferencesSnapshot()
            fileDownloadSnapshot = FileDownloadSnapshot()
            recentSearchTerms = []
        }

        config = savedConfig
        downloadingFileIDs = []
        offlineBulkDownloadProgress = nil
        preloadingCourseIDs = []
        inboxConversations = []
        loadingInbox = false
        inboxLastLoadedAt = nil
        reminderService = AssignmentReminderService(
            config: savedConfig,
            networkManager: networkManager,
            telegramManager: .shared,
            historyManager: .shared
        )
        courseAssignmentsByCourseID = [:]
        loadingCourseAssignmentIDs = []
        courseModulesByCourseID = [:]
        loadingCourseModuleIDs = []
        courseFoldersByCourseID = [:]
        courseFilesByFolderID = [:]
        loadingCourseFolderIDs = []
        loadingFolderFileIDs = []
        courseAnnouncementsByCourseID = [:]
        loadingCourseAnnouncementIDs = []
        courseSyllabusByCourseID = [:]
        loadingCourseSyllabusIDs = []
        coursePeopleByCourseID = [:]
        loadingCoursePeopleIDs = []
        moduleItemDetailsByKey = [:]
        loadingModuleItemDetailKeys = []

        switch bootstrapMode {
        case .normal:
            if let snapshot = databaseManager.loadSnapshot() {
                courses = snapshot.courses
                upcomingEvents = snapshot.upcomingEvents
                missingSubmissions = snapshot.missingSubmissions
                profile = snapshot.profile
                lastSyncedAt = snapshot.syncedAt
            } else {
                courses = []
                upcomingEvents = []
                missingSubmissions = []
                profile = nil
                lastSyncedAt = nil
            }
        case .uiTests:
            courses = []
            upcomingEvents = []
            missingSubmissions = []
            profile = nil
            lastSyncedAt = nil
        }

        selectedCourseID = courses.first?.id
        relativeFormatter.unitsStyle = .full

        if bootstrapMode == .normal {
            restoreCourseDetailCache()
        }
    }

    deinit {
        cacheMaintenanceTask?.cancel()
        autoSyncTask?.cancel()
    }

    var isConfigured: Bool {
        config.isComplete
    }

    var nextUpcomingEvent: UpcomingEvent? {
        upcomingEvents.first(where: { event in
            guard let date = event.displayDate else {
                return false
            }

            return date >= Date()
        })
    }

    var eventsDueThisWeekCount: Int {
        let now = Date()
        guard let endOfWindow = Calendar.current.date(byAdding: .day, value: 7, to: now) else {
            return 0
        }

        return upcomingEvents.filter { event in
            guard let date = event.displayDate else {
                return false
            }

            return date >= now && date <= endOfWindow
        }.count
    }

    var selectedCourseName: String? {
        courseName(for: selectedCourseID)
    }

    var selectedCourse: Course? {
        guard let selectedCourseID else {
            return nil
        }

        return courses.first(where: { $0.id == selectedCourseID })
    }

    var hostLabel: String {
        URL(string: config.normalizedBaseURL)?.host ?? config.normalizedBaseURL
    }

    var lastSyncDescription: String? {
        guard let lastSyncedAt else {
            return nil
        }

        return relativeFormatter.localizedString(for: lastSyncedAt, relativeTo: Date())
    }

    var localDataInventory: LocalDataInventory {
        LocalDataInventory(
            isConfigured: isConfigured,
            lastDashboardSync: lastSyncedAt,
            courseDetailCourseCount: cachedCourseDetailIDs.count,
            knownFileCount: fileDownloadSnapshot.recordsByFileID.count,
            downloadedFileCount: fileDownloadSnapshot.downloadedRecords.count,
            downloadedByteCount: fileDownloadSnapshot.downloadedByteCount,
            downloadCacheLimitBytes: config.downloadCacheLimit.byteLimit,
            downloadCacheLimitLabel: config.downloadCacheLimit.label,
            recentSearchCount: recentSearchTerms.count,
            pinnedCourseCount: coursePreferences.pinnedCourseIDs.count,
            hiddenCourseCount: coursePreferences.hiddenCourseIDs.count,
            offlinePriorityCourseCount: coursePreferences.offlinePriorityCourseIDs.count
        )
    }

    var courseOfflineReadiness: [CourseOfflineReadiness] {
        preferredCourses(showingHidden: true).map { course in
            let courseFolderIDs = Set((courseFoldersByCourseID[course.id] ?? []).map(\.id))
            let hasFilesMetadata = !courseFolderIDs.isEmpty
                && courseFolderIDs.contains { courseFilesByFolderID[$0] != nil }

            return CourseOfflineReadiness(
                courseID: course.id,
                courseName: course.name,
                isOfflinePriority: coursePreferences.offlinePriorityCourseIDs.contains(course.id),
                hasAssignments: courseAssignmentsByCourseID[course.id] != nil,
                hasModules: courseModulesByCourseID[course.id] != nil,
                hasFilesMetadata: hasFilesMetadata,
                hasAnnouncements: courseAnnouncementsByCourseID[course.id] != nil,
                hasSyllabus: courseSyllabusByCourseID[course.id] != nil,
                hasPeople: coursePeopleByCourseID[course.id] != nil,
                lastAccessedAt: courseDetailAccessDates[course.id]
            )
        }
    }

    func refreshIfNeeded() async {
        guard isConfigured, courses.isEmpty, upcomingEvents.isEmpty, missingSubmissions.isEmpty else {
            return
        }

        await refresh()
    }

    func refresh() async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        isSyncing = true
        errorMessage = nil

        do {
            let snapshot = try await networkManager.fetchDashboardSnapshot(using: config)
            guard !Task.isCancelled else {
                isSyncing = false
                return
            }

            applySnapshot(snapshot)
            try databaseManager.saveSnapshot(snapshot)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                isSyncing = false
                return
            }

            displayError(error)
        }

        isSyncing = false
    }

    func refreshDashboardAndCachedDetails() async {
        let cachedCourseIDsToRefresh = cachedCourseDetailIDs
        let offlinePriorityCourseIDsToRefresh = coursePreferences.offlinePriorityCourseIDs
        let courseIDsToRefresh = cachedCourseIDsToRefresh.union(offlinePriorityCourseIDsToRefresh)

        await refresh()

        guard !Task.isCancelled, errorMessage == nil, !courseIDsToRefresh.isEmpty else {
            return
        }

        isSyncing = true
        defer {
            isSyncing = false
        }

        let availableCourseIDs = Set(courses.map(\.id))
        for courseID in courseIDsToRefresh.sorted() where availableCourseIDs.contains(courseID) {
            guard !Task.isCancelled else {
                return
            }

            if offlinePriorityCourseIDsToRefresh.contains(courseID) {
                await preloadCourseMetadata(courseID: courseID)
            } else {
                await refreshCachedCourseMetadata(courseID: courseID)
            }
        }
    }

    @discardableResult
    func saveConfiguration(
        baseURL: String,
        token: String,
        lookaheadDays: Int,
        telegramReminders: TelegramReminderConfig,
        downloadCacheLimit: DownloadCacheLimitPreset = .unlimited,
        autoSync: AutoSyncConfig? = nil
    ) throws -> Bool {
        let nextAutoSync = autoSync ?? config.autoSync
        let previousAutoSync = config.autoSync
        let updatedConfig = CanvasConfig(
            baseURL: baseURL,
            token: token,
            lookaheadDays: lookaheadDays,
            telegramReminders: telegramReminders,
            downloadCacheLimit: downloadCacheLimit,
            autoSync: nextAutoSync
        )

        let credentialsChanged = updatedConfig.normalizedBaseURL != config.normalizedBaseURL
            || updatedConfig.trimmedToken != config.trimmedToken

        if credentialsChanged {
            stopAutoSync()
        }

        try configManager.saveConfig(updatedConfig)
        config = updatedConfig
        reminderService.updateConfig(updatedConfig)
        restartAutoSyncIfNeeded(
            previous: previousAutoSync,
            current: updatedConfig.autoSync,
            forceRestart: credentialsChanged
        )
        errorMessage = nil

        if credentialsChanged {
            clearLocalData()
        }

        return credentialsChanged
    }

    func clearLocalData() {
        courses = []
        clearCourseDetailMemoryCache()
        upcomingEvents = []
        missingSubmissions = []
        profile = nil
        lastSyncedAt = nil
        selectedCourseID = nil

        do {
            try databaseManager.clearSnapshot()
            try detailCacheManager.clearCache()
            try preferenceManager.clearPreferences()
            try fileDownloadManager.clearAllData()
            coursePreferences = CoursePreferencesSnapshot()
            fileDownloadSnapshot = FileDownloadSnapshot()
            downloadingFileIDs = []
            offlineBulkDownloadProgress = nil
            preloadingCourseIDs = []
            try recentSearchManager.clearTerms()
            recentSearchTerms = []
            inboxConversations = []
            loadingInbox = false
            inboxLastLoadedAt = nil
        } catch {
            displayError(error)
        }
    }

    func preferredCourses(showingHidden: Bool = false) -> [Course] {
        let hiddenIDs = coursePreferences.hiddenCourseIDs
        let visibleCourses = showingHidden ? courses : courses.filter { !hiddenIDs.contains($0.id) }
        let candidates = visibleCourses.isEmpty && !courses.isEmpty ? courses : visibleCourses

        return candidates.sorted { lhs, rhs in
            let leftPinned = coursePreferences.pinnedCourseIDs.contains(lhs.id)
            let rightPinned = coursePreferences.pinnedCourseIDs.contains(rhs.id)

            if leftPinned != rightPinned {
                return leftPinned
            }

            let leftOffline = coursePreferences.offlinePriorityCourseIDs.contains(lhs.id)
            let rightOffline = coursePreferences.offlinePriorityCourseIDs.contains(rhs.id)

            if leftOffline != rightOffline {
                return leftOffline
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func resolvedDefaultCourseID(showingHidden: Bool = false) -> Int? {
        let preferredCourses = preferredCourses(showingHidden: showingHidden)

        if let defaultCourseID = coursePreferences.defaultCourseID,
           preferredCourses.contains(where: { $0.id == defaultCourseID }) {
            return defaultCourseID
        }

        return preferredCourses.first?.id
    }

    func resolvedDefaultEventsCourseID(showingHidden: Bool = false) -> Int? {
        let preferredCourses = preferredCourses(showingHidden: showingHidden)

        if let defaultEventsCourseID = coursePreferences.defaultEventsCourseID,
           preferredCourses.contains(where: { $0.id == defaultEventsCourseID }) {
            return defaultEventsCourseID
        }

        return resolvedDefaultCourseID(showingHidden: showingHidden)
    }

    func coursePreference(for courseID: Int?) -> SingleCoursePreference {
        guard let courseID else {
            return SingleCoursePreference()
        }

        return coursePreferences.preferencesByCourseID[courseID] ?? SingleCoursePreference()
    }

    func updateCoursePreference(courseID: Int, _ update: (inout SingleCoursePreference) -> Void) {
        var preference = coursePreferences.preferencesByCourseID[courseID] ?? SingleCoursePreference()
        update(&preference)
        coursePreferences.preferencesByCourseID[courseID] = preference
        persistCoursePreferences()
    }

    func togglePinnedCourse(_ courseID: Int) {
        if coursePreferences.pinnedCourseIDs.contains(courseID) {
            coursePreferences.pinnedCourseIDs.remove(courseID)
        } else {
            coursePreferences.pinnedCourseIDs.insert(courseID)
        }

        persistCoursePreferences()
    }

    func toggleHiddenCourse(_ courseID: Int) {
        if coursePreferences.hiddenCourseIDs.contains(courseID) {
            coursePreferences.hiddenCourseIDs.remove(courseID)
        } else {
            coursePreferences.hiddenCourseIDs.insert(courseID)
        }

        if coursePreferences.defaultCourseID == courseID && coursePreferences.hiddenCourseIDs.contains(courseID) {
            coursePreferences.defaultCourseID = nil
        }

        if coursePreferences.defaultEventsCourseID == courseID && coursePreferences.hiddenCourseIDs.contains(courseID) {
            coursePreferences.defaultEventsCourseID = nil
        }

        persistCoursePreferences()
    }

    func toggleOfflinePriorityCourse(_ courseID: Int) {
        if coursePreferences.offlinePriorityCourseIDs.contains(courseID) {
            coursePreferences.offlinePriorityCourseIDs.remove(courseID)
        } else {
            coursePreferences.offlinePriorityCourseIDs.insert(courseID)
        }

        persistCoursePreferences()
    }

    func setShowsHiddenCourses(_ showsHiddenCourses: Bool) {
        guard coursePreferences.showsHiddenCourses != showsHiddenCourses else {
            return
        }

        coursePreferences.showsHiddenCourses = showsHiddenCourses
        persistCoursePreferences()
    }

    func setDefaultCourse(_ courseID: Int?) {
        coursePreferences.defaultCourseID = courseID
        persistCoursePreferences()
    }

    func setDefaultEventsCourse(_ courseID: Int?) {
        coursePreferences.defaultEventsCourseID = courseID
        persistCoursePreferences()
    }

    func courseName(for courseID: Int?) -> String? {
        guard let courseID else {
            return nil
        }

        return courses.first(where: { $0.id == courseID })?.name
    }

    func filteredUpcomingEvents(courseID: Int?) -> [UpcomingEvent] {
        let events: [UpcomingEvent]
        let missing: [MissingSubmission]
        if let courseID {
            events = upcomingEvents.filter { $0.courseID == courseID }
            missing = missingSubmissions.filter { $0.courseID == courseID }
        } else {
            events = upcomingEvents
            missing = missingSubmissions
        }

        return upcomingEventsExcludingMissingAssignments(events, missingSubmissions: missing)
    }

    func filteredMissingSubmissions(courseID: Int?) -> [MissingSubmission] {
        guard let courseID else {
            return missingSubmissions
        }

        return missingSubmissions.filter { $0.courseID == courseID }
    }

    private func upcomingEventsExcludingMissingAssignments(
        _ events: [UpcomingEvent],
        missingSubmissions: [MissingSubmission]
    ) -> [UpcomingEvent] {
        let missingAssignmentIdentities = Set(missingSubmissions.map(\.assignmentIdentity))
        return events.filter { event in
            guard let assignmentIdentity = event.assignmentIdentity else {
                return true
            }

            return !missingAssignmentIdentities.contains(assignmentIdentity)
        }
    }

    func prioritizedMissingSubmissions(courseID: Int?) -> [MissingSubmission] {
        filteredMissingSubmissions(courseID: courseID)
            .sorted(by: priorityMissingSubmissionPrecedes)
    }

    func prioritizedUpcomingEvents(courseID: Int?) -> [UpcomingEvent] {
        filteredUpcomingEvents(courseID: courseID)
            .sorted(by: priorityUpcomingEventPrecedes)
    }

    func priorityNowItems(courseID: Int?, limit: Int = 3) -> [DashboardPriorityItem] {
        let items = prioritizedMissingSubmissions(courseID: courseID).map {
            DashboardPriorityItem(kind: .missing($0), score: priorityScore(for: $0))
        } + prioritizedUpcomingEvents(courseID: courseID).compactMap { event in
            let score = priorityScore(for: event)
            guard score > 0 else {
                return nil
            }

            return DashboardPriorityItem(kind: .upcoming(event), score: score)
        }

        return items
            .sorted(by: priorityItemPrecedes)
            .prefix(limit)
            .map { $0 }
    }

    func dashboardFocusItem(courseID: Int?) -> DashboardPriorityItem? {
        priorityNowItems(courseID: courseID, limit: 1).first
    }

    func modules(for courseID: Int?) -> [CourseModule] {
        guard let courseID else {
            return []
        }

        return courseModulesByCourseID[courseID] ?? []
    }

    func assignments(for courseID: Int?) -> [CourseAssignment] {
        guard let courseID else {
            return []
        }

        return courseAssignmentsByCourseID[courseID] ?? []
    }

    func folders(for courseID: Int?) -> [CanvasFolder] {
        guard let courseID else {
            return []
        }

        return courseFoldersByCourseID[courseID] ?? []
    }

    func files(for folderID: Int?) -> [CanvasFile] {
        guard let folderID else {
            return []
        }

        return courseFilesByFolderID[folderID] ?? []
    }

    func downloadRecord(for file: CanvasFile) -> FileDownloadRecord? {
        fileDownloadSnapshot.recordsByFileID[file.id]
    }

    func isDownloading(_ file: CanvasFile) -> Bool {
        downloadingFileIDs.contains(file.id)
    }

    func registerSeenFiles(_ files: [CanvasFile], courseID: Int?) {
        var snapshot = fileDownloadSnapshot
        var didChange = false

        for file in files {
            if var existingRecord = snapshot.recordsByFileID[file.id] {
                existingRecord.courseID = existingRecord.courseID ?? courseID
                existingRecord.folderID = existingRecord.folderID ?? file.folderID
                existingRecord.file = file
                snapshot.recordsByFileID[file.id] = existingRecord
            } else {
                snapshot.recordsByFileID[file.id] = FileDownloadRecord(
                    fileID: file.id,
                    courseID: courseID,
                    folderID: file.folderID,
                    file: file
                )
            }

            didChange = true
        }

        guard didChange else {
            return
        }

        snapshot.updatedAt = now()
        fileDownloadSnapshot = snapshot
        persistFileDownloadSnapshot()
    }

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
            items: itemsByFileID.values.sorted(by: offlineDownloadPlanItemPrecedes),
            skippedFiles: skippedByFileID.values.sorted(by: offlineDownloadSkippedFilePrecedes)
        )
    }

    func announcements(for courseID: Int?) -> [CourseAnnouncement] {
        guard let courseID else {
            return []
        }

        return courseAnnouncementsByCourseID[courseID] ?? []
    }

    func syllabus(for courseID: Int?) -> CourseSyllabus? {
        guard let courseID else {
            return nil
        }

        return courseSyllabusByCourseID[courseID]
    }

    func people(for courseID: Int?) -> [CoursePerson] {
        guard let courseID else {
            return []
        }

        return coursePeopleByCourseID[courseID] ?? []
    }

    func moduleItemDetail(for key: CourseModuleItemDetailKey?) -> CourseModuleItemDetail? {
        guard let key else {
            return nil
        }

        return moduleItemDetailsByKey[key.rawValue]
    }

    func hasLoadedAssignments(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return courseAssignmentsByCourseID[courseID] != nil
    }

    func isLoadingAssignments(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return loadingCourseAssignmentIDs.contains(courseID)
    }

    func loadAssignmentsIfNeeded(for courseID: Int?) async {
        guard let courseID else {
            return
        }

        if courseAssignmentsByCourseID[courseID] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingCourseAssignmentIDs.contains(courseID) else {
            return
        }

        await loadAssignments(for: courseID)
    }

    func loadAssignments(for courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingCourseAssignmentIDs.insert(courseID)

        do {
            let assignments = try await networkManager.fetchAssignments(courseID: courseID, using: config)
            courseAssignmentsByCourseID[courseID] = assignments
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()
        } catch {
            handleCourseDetailLoadFailure(error, courseID: courseID)
        }

        loadingCourseAssignmentIDs.remove(courseID)
    }

    func hasLoadedModules(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return courseModulesByCourseID[courseID] != nil
    }

    func isLoadingModules(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return loadingCourseModuleIDs.contains(courseID)
    }

    func loadModulesIfNeeded(for courseID: Int?) async {
        guard let courseID else {
            return
        }

        if courseModulesByCourseID[courseID] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingCourseModuleIDs.contains(courseID) else {
            return
        }

        await loadModules(for: courseID)
    }

    func loadModules(for courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingCourseModuleIDs.insert(courseID)

        do {
            let modules = try await networkManager.fetchModules(courseID: courseID, using: config)
            courseModulesByCourseID[courseID] = modules
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()
        } catch {
            handleCourseDetailLoadFailure(error, courseID: courseID)
        }

        loadingCourseModuleIDs.remove(courseID)
    }

    func hasLoadedFolders(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return courseFoldersByCourseID[courseID] != nil
    }

    func isLoadingFolders(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return loadingCourseFolderIDs.contains(courseID)
    }

    func hasLoadedFiles(for folderID: Int?) -> Bool {
        guard let folderID else {
            return false
        }

        return courseFilesByFolderID[folderID] != nil
    }

    func isLoadingFiles(for folderID: Int?) -> Bool {
        guard let folderID else {
            return false
        }

        return loadingFolderFileIDs.contains(folderID)
    }

    func hasLoadedAnnouncements(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return courseAnnouncementsByCourseID[courseID] != nil
    }

    func isLoadingAnnouncements(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return loadingCourseAnnouncementIDs.contains(courseID)
    }

    func hasLoadedSyllabus(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return courseSyllabusByCourseID[courseID] != nil
    }

    func isLoadingSyllabus(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return loadingCourseSyllabusIDs.contains(courseID)
    }

    func hasLoadedPeople(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return coursePeopleByCourseID[courseID] != nil
    }

    func isLoadingPeople(for courseID: Int?) -> Bool {
        guard let courseID else {
            return false
        }

        return loadingCoursePeopleIDs.contains(courseID)
    }

    func isLoadingModuleItemDetail(_ key: CourseModuleItemDetailKey?) -> Bool {
        guard let key else {
            return false
        }

        return loadingModuleItemDetailKeys.contains(key.rawValue)
    }

    func loadCourseFilesIfNeeded(for courseID: Int?) async {
        guard let courseID else {
            return
        }

        if courseFoldersByCourseID[courseID] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingCourseFolderIDs.contains(courseID) else {
            return
        }

        await loadCourseFiles(for: courseID)
    }

    func loadCourseFiles(for courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingCourseFolderIDs.insert(courseID)

        do {
            let folders = try await networkManager.fetchFolders(courseID: courseID, using: config)
            courseFoldersByCourseID[courseID] = folders
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()

            if let firstFolderID = folders.first?.id, courseFilesByFolderID[firstFolderID] == nil {
                await loadFiles(for: firstFolderID)
            }
        } catch {
            handleCourseDetailLoadFailure(error, courseID: courseID)
        }

        loadingCourseFolderIDs.remove(courseID)
    }

    func loadFilesIfNeeded(for folderID: Int?) async {
        guard let folderID else {
            return
        }

        if courseFilesByFolderID[folderID] != nil {
            if let courseID = courseID(containingFolderID: folderID) {
                markCourseDetailAccess(courseID)
            }
            return
        }

        guard !loadingFolderFileIDs.contains(folderID) else {
            return
        }

        await loadFiles(for: folderID)
    }

    func loadFiles(for folderID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingFolderFileIDs.insert(folderID)

        do {
            let files = try await networkManager.fetchFiles(folderID: folderID, using: config)
            courseFilesByFolderID[folderID] = files
            if let courseID = courseID(containingFolderID: folderID) {
                registerSeenFiles(files, courseID: courseID)
                markCourseDetailAccess(courseID)
                persistCourseDetailCache()
            }
        } catch {
            if let courseID = courseID(containingFolderID: folderID) {
                handleCourseDetailLoadFailure(error, courseID: courseID)
            } else {
                displayError(error)
            }
        }

        loadingFolderFileIDs.remove(folderID)
    }

    func downloadFile(_ file: CanvasFile, courseID: Int?) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        guard !file.isUnavailable else {
            updateDownloadRecord(file: file, courseID: courseID, state: .failed, message: "Canvas marks this file as locked or hidden.")
            return
        }

        if let limitError = downloadCacheLimitError(for: file) {
            updateDownloadRecord(file: file, courseID: courseID, state: .failed, message: limitError)
            errorMessage = limitError
            return
        }

        downloadingFileIDs.insert(file.id)
        updateDownloadRecord(file: file, courseID: courseID, state: .downloading)

        do {
            let record = try await fileDownloadManager.download(file: file, courseID: courseID, using: config)
            fileDownloadSnapshot.recordsByFileID[file.id] = record
            fileDownloadSnapshot.updatedAt = now()
            persistFileDownloadSnapshot()
        } catch {
            updateDownloadRecord(file: file, courseID: courseID, state: .failed, message: error.localizedDescription)
        }

        downloadingFileIDs.remove(file.id)
    }

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
            await downloadFile(item.file, courseID: item.courseID)

            if fileDownloadSnapshot.recordsByFileID[item.file.id]?.state == .downloaded {
                offlineBulkDownloadProgress?.completedCount += 1
            } else {
                offlineBulkDownloadProgress?.failedCount += 1
            }
        }
    }

    func retryDownload(_ record: FileDownloadRecord) async {
        await downloadFile(record.file, courseID: record.courseID)
    }

    func removeDownloadedFile(_ record: FileDownloadRecord) {
        do {
            try fileDownloadManager.removeDownloadedFile(record)
            var updatedRecord = record
            updatedRecord.state = .notDownloaded
            updatedRecord.localPath = nil
            updatedRecord.downloadedAt = nil
            updatedRecord.failureMessage = nil
            updatedRecord.byteCount = nil
            fileDownloadSnapshot.recordsByFileID[record.fileID] = updatedRecord
            fileDownloadSnapshot.updatedAt = now()
            persistFileDownloadSnapshot()
        } catch {
            displayError(error)
        }
    }

    func clearDownloadedFiles() {
        do {
            try fileDownloadManager.clearDownloadedFilesDirectory()
            var snapshot = fileDownloadSnapshot
            snapshot.recordsByFileID = snapshot.recordsByFileID.mapValues { record in
                var updatedRecord = record
                if updatedRecord.state == .downloaded {
                    updatedRecord.state = .notDownloaded
                    updatedRecord.localPath = nil
                    updatedRecord.downloadedAt = nil
                    updatedRecord.failureMessage = nil
                    updatedRecord.byteCount = nil
                }
                return updatedRecord
            }
            snapshot.updatedAt = now()
            fileDownloadSnapshot = snapshot
            persistFileDownloadSnapshot()
        } catch {
            displayError(error)
        }
    }

    func clearDashboardCache() {
        courses = []
        upcomingEvents = []
        missingSubmissions = []
        profile = nil
        lastSyncedAt = nil
        selectedCourseID = nil

        do {
            try databaseManager.clearSnapshot()
        } catch {
            displayError(error)
        }
    }

    func clearCourseDetailCache() {
        clearCourseDetailMemoryCache()

        do {
            try detailCacheManager.clearCache()
        } catch {
            displayError(error)
        }
    }

    func preloadOfflinePriorityCourseMetadata() async {
        let courseIDs = coursePreferences.offlinePriorityCourseIDs
            .filter { courseID in courses.contains { $0.id == courseID } }
            .sorted()

        for courseID in courseIDs {
            await preloadCourseMetadata(courseID: courseID)
        }
    }

    func preloadCourseMetadata(courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        guard courses.contains(where: { $0.id == courseID }) else {
            return
        }

        guard !preloadingCourseIDs.contains(courseID) else {
            return
        }

        preloadingCourseIDs.insert(courseID)
        defer {
            preloadingCourseIDs.remove(courseID)
        }

        await loadAssignments(for: courseID)
        await loadModules(for: courseID)
        await loadCourseFiles(for: courseID)

        for folder in courseFoldersByCourseID[courseID] ?? [] {
            guard !Task.isCancelled else {
                return
            }

            await loadFiles(for: folder.id)
        }

        await loadAnnouncements(for: courseID)
        await loadSyllabus(for: courseID)
        await loadPeople(for: courseID)
    }

    private func refreshCachedCourseMetadata(courseID: Int) async {
        guard config.isComplete, courses.contains(where: { $0.id == courseID }) else {
            return
        }

        if courseAssignmentsByCourseID[courseID] != nil {
            await loadAssignments(for: courseID)
        }

        if courseModulesByCourseID[courseID] != nil {
            await loadModules(for: courseID)
        }

        let cachedFolderIDs = Set((courseFoldersByCourseID[courseID] ?? []).map(\.id))
        if courseFoldersByCourseID[courseID] != nil {
            await loadCourseFiles(for: courseID)
        }

        let currentFolderIDs = Set((courseFoldersByCourseID[courseID] ?? []).map(\.id))
        for folderID in cachedFolderIDs.union(currentFolderIDs).sorted() {
            if courseFilesByFolderID[folderID] != nil {
                await loadFiles(for: folderID)
            }
        }

        if courseAnnouncementsByCourseID[courseID] != nil {
            await loadAnnouncements(for: courseID)
        }

        if courseSyllabusByCourseID[courseID] != nil {
            await loadSyllabus(for: courseID)
        }

        if coursePeopleByCourseID[courseID] != nil {
            await loadPeople(for: courseID)
        }

        await refreshCachedModuleItemDetails(courseID: courseID)
    }

    private func refreshCachedModuleItemDetails(courseID: Int) async {
        let cachedKeys = Set(moduleItemDetailsByKey.keys.compactMap(CourseModuleItemDetailKey.init(rawValue:)))
            .filter { $0.courseID == courseID }

        guard !cachedKeys.isEmpty else {
            return
        }

        if courseModulesByCourseID[courseID] == nil {
            await loadModules(for: courseID)
        }

        let cachedItems = (courseModulesByCourseID[courseID] ?? [])
            .flatMap { $0.items ?? [] }
            .compactMap { item -> (CourseModuleItem, CourseModuleItemDetailKey)? in
                guard let key = CourseModuleItemDetailKey.key(courseID: courseID, item: item),
                      cachedKeys.contains(key)
                else {
                    return nil
                }

                return (item, key)
            }

        for (item, key) in cachedItems {
            guard !Task.isCancelled else {
                return
            }

            await loadModuleItemDetail(courseID: courseID, item: item, key: key)
        }
    }

    func globalSearchResults(for query: String) -> [GlobalSearchResult] {
        GlobalSearchIndex.results(
            query: query,
            courses: courses,
            upcomingEvents: filteredUpcomingEvents(courseID: nil),
            missingSubmissions: missingSubmissions,
            assignmentsByCourseID: courseAssignmentsByCourseID,
            modulesByCourseID: courseModulesByCourseID,
            foldersByCourseID: courseFoldersByCourseID,
            filesByFolderID: courseFilesByFolderID,
            announcementsByCourseID: courseAnnouncementsByCourseID,
            syllabusByCourseID: courseSyllabusByCourseID,
            peopleByCourseID: coursePeopleByCourseID,
            moduleItemDetailsByKey: moduleItemDetailsByKey
        )
    }

    func rememberSearchTerm(_ term: String) {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            return
        }

        recentSearchTerms.removeAll { $0.localizedCaseInsensitiveCompare(trimmedTerm) == .orderedSame }
        recentSearchTerms.insert(trimmedTerm, at: 0)
        recentSearchTerms = Array(recentSearchTerms.prefix(10))
        persistRecentSearchTerms()
    }

    func clearRecentSearchTerms() {
        recentSearchTerms = []
        do {
            try recentSearchManager.clearTerms()
        } catch {
            displayError(error)
        }
    }

    func loadInboxConversationsIfNeeded() async {
        guard inboxConversations.isEmpty else {
            return
        }

        await loadInboxConversations()
    }

    func refreshInboxConversations() async {
        await loadInboxConversations()
    }

    func loadInboxConversations() async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        guard !loadingInbox else {
            return
        }

        loadingInbox = true
        errorMessage = nil

        do {
            async let activeConversationsTask = networkManager.fetchConversations(using: config)
            async let archivedConversationsTask = networkManager.fetchConversations(scope: .archived, using: config)
            let conversations = try await activeConversationsTask + archivedConversationsTask
            var seenConversationIDs: Set<Int> = []
            inboxConversations = conversations
                .filter { seenConversationIDs.insert($0.id).inserted }
                .sorted(by: sortInboxConversations)
            inboxLastLoadedAt = now()
        } catch {
            displayError(error)
        }

        loadingInbox = false
    }

    func markConversationRead(_ conversation: CanvasConversation) async {
        await updateConversationWorkflowState(conversation, state: .read)
    }

    func markConversationUnread(_ conversation: CanvasConversation) async {
        await updateConversationWorkflowState(conversation, state: .unread)
    }

    func archiveConversation(_ conversation: CanvasConversation) async {
        await updateConversationWorkflowState(conversation, state: .archived)
    }

    func quickLookURL(for record: FileDownloadRecord) -> URL? {
        if let url = record.localPreviewURL {
            return url
        }

        if record.state == .downloaded {
            markDownloadedFileMissing(record)
        }

        errorMessage = FileDownloadError.missingLocalFile.localizedDescription
        return nil
    }

    func openDownloadedFile(_ record: FileDownloadRecord) {
        guard let localPath = record.localPath else {
            errorMessage = FileDownloadError.missingLocalFile.localizedDescription
            return
        }

        let url = URL(fileURLWithPath: localPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            markDownloadedFileMissing(record)
            errorMessage = FileDownloadError.missingLocalFile.localizedDescription
            return
        }

        NSWorkspace.shared.open(url)
    }

    func revealDownloadedFile(_ record: FileDownloadRecord) {
        guard let localPath = record.localPath else {
            errorMessage = FileDownloadError.missingLocalFile.localizedDescription
            return
        }

        let url = URL(fileURLWithPath: localPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            markDownloadedFileMissing(record)
            errorMessage = FileDownloadError.missingLocalFile.localizedDescription
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func loadAnnouncementsIfNeeded(for courseID: Int?) async {
        guard let courseID else {
            return
        }

        if courseAnnouncementsByCourseID[courseID] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingCourseAnnouncementIDs.contains(courseID) else {
            return
        }

        await loadAnnouncements(for: courseID)
    }

    func loadAnnouncements(for courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingCourseAnnouncementIDs.insert(courseID)

        do {
            let announcements = try await networkManager.fetchAnnouncements(courseID: courseID, using: config)
            courseAnnouncementsByCourseID[courseID] = announcements
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()
        } catch {
            handleCourseDetailLoadFailure(error, courseID: courseID)
        }

        loadingCourseAnnouncementIDs.remove(courseID)
    }

    func loadSyllabusIfNeeded(for courseID: Int?) async {
        guard let courseID else {
            return
        }

        if courseSyllabusByCourseID[courseID] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingCourseSyllabusIDs.contains(courseID) else {
            return
        }

        await loadSyllabus(for: courseID)
    }

    func loadSyllabus(for courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingCourseSyllabusIDs.insert(courseID)

        do {
            let syllabus = try await networkManager.fetchSyllabus(courseID: courseID, using: config)
            courseSyllabusByCourseID[courseID] = syllabus
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()
        } catch {
            handleCourseDetailLoadFailure(error, courseID: courseID)
        }

        loadingCourseSyllabusIDs.remove(courseID)
    }

    func loadPeopleIfNeeded(for courseID: Int?) async {
        guard let courseID else {
            return
        }

        if coursePeopleByCourseID[courseID] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingCoursePeopleIDs.contains(courseID) else {
            return
        }

        await loadPeople(for: courseID)
    }

    func loadPeople(for courseID: Int) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingCoursePeopleIDs.insert(courseID)

        do {
            let people = try await networkManager.fetchPeople(courseID: courseID, using: config)
            coursePeopleByCourseID[courseID] = people
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()
        } catch {
            handleCourseDetailLoadFailure(error, courseID: courseID)
        }

        loadingCoursePeopleIDs.remove(courseID)
    }

    func loadModuleItemDetailIfNeeded(courseID: Int, item: CourseModuleItem) async {
        guard let key = CourseModuleItemDetailKey.key(courseID: courseID, item: item) else {
            return
        }

        if moduleItemDetailsByKey[key.rawValue] != nil {
            markCourseDetailAccess(courseID)
            return
        }

        guard !loadingModuleItemDetailKeys.contains(key.rawValue) else {
            return
        }

        await loadModuleItemDetail(courseID: courseID, item: item, key: key)
    }

    private func loadModuleItemDetail(courseID: Int, item: CourseModuleItem, key: CourseModuleItemDetailKey) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        loadingModuleItemDetailKeys.insert(key.rawValue)

        do {
            let detail: CourseModuleItemDetail

            switch item.type {
            case "Quiz":
                guard let quizID = item.contentID else {
                    loadingModuleItemDetailKeys.remove(key.rawValue)
                    return
                }

                detail = .quiz(try await networkManager.fetchQuizDetail(courseID: courseID, quizID: quizID, using: config))
            case "Discussion":
                guard let discussionID = item.contentID else {
                    loadingModuleItemDetailKeys.remove(key.rawValue)
                    return
                }

                detail = .discussion(
                    try await networkManager.fetchDiscussionDetail(
                        courseID: courseID,
                        discussionID: discussionID,
                        using: config
                    )
                )
            case "Page":
                guard let pageURL = item.pageURL else {
                    loadingModuleItemDetailKeys.remove(key.rawValue)
                    return
                }

                detail = .page(try await networkManager.fetchPageDetail(courseID: courseID, pageURL: pageURL, using: config))
            default:
                loadingModuleItemDetailKeys.remove(key.rawValue)
                return
            }

            moduleItemDetailsByKey[key.rawValue] = detail
            markCourseDetailAccess(courseID)
            persistCourseDetailCache()
        } catch {
            displayError(error)
        }

        loadingModuleItemDetailKeys.remove(key.rawValue)
    }

    func startTelegramReminderService() {
        reminderService.start()
    }

    func stopTelegramReminderService() {
        reminderService.stop()
    }

    func startCacheMaintenance() {
        guard cacheMaintenanceTask == nil else {
            return
        }

        let interval = max(cachePolicy.maintenanceInterval, 1)
        cacheMaintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard !Task.isCancelled else {
                    return
                }

                guard let self else {
                    return
                }

                self.pruneCourseDetailMemoryCache()
            }
        }
    }

    func stopCacheMaintenance() {
        cacheMaintenanceTask?.cancel()
        cacheMaintenanceTask = nil
    }

    func startAutoSync() {
        guard autoSyncTask == nil, config.isComplete, config.autoSync.isEnabled else {
            return
        }

        autoSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                let minutes = self.config.autoSync.normalizedIntervalMinutes
                try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)

                guard !Task.isCancelled else {
                    return
                }

                guard self.config.isComplete, self.config.autoSync.isEnabled, !self.isSyncing else {
                    continue
                }

                await self.refreshDashboardAndCachedDetails()
            }
        }
    }

    func stopAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }

    func pruneCourseDetailMemoryCache(referenceDate: Date? = nil) {
        let currentDate = referenceDate ?? now()
        let snapshot = buildCourseDetailCacheSnapshot(savedAt: currentDate)
        let prunedSnapshot = snapshot.prunedForMemory(
            now: currentDate,
            timeToLive: cachePolicy.memoryTimeToLive,
            maximumCourses: cachePolicy.maximumMemoryCourses,
            alwaysKeepingCourseIDs: courseIDsToKeepInMemory
        )

        applyCourseDetailCache(prunedSnapshot)
        _ = detailCacheManager.loadCache(validAt: currentDate, maximumAge: cachePolicy.diskTimeToLive)
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

    private func restoreCourseDetailCache() {
        let currentDate = now()
        guard let snapshot = detailCacheManager.loadCache(validAt: currentDate, maximumAge: cachePolicy.diskTimeToLive) else {
            return
        }

        let validCourseIDs = Set(courses.map(\.id))
        let memorySnapshot = snapshot
            .filteredForCourses(validCourseIDs)
            .prunedForMemory(
                now: currentDate,
                timeToLive: cachePolicy.memoryTimeToLive,
                maximumCourses: cachePolicy.maximumMemoryCourses,
                alwaysKeepingCourseIDs: courseIDsToKeepInMemory
            )

        applyCourseDetailCache(memorySnapshot)
    }

    private func buildCourseDetailCacheSnapshot(savedAt: Date) -> CourseDetailCacheSnapshot {
        CourseDetailCacheSnapshot(
            assignmentsByCourseID: courseAssignmentsByCourseID,
            modulesByCourseID: courseModulesByCourseID,
            foldersByCourseID: courseFoldersByCourseID,
            filesByFolderID: courseFilesByFolderID,
            announcementsByCourseID: courseAnnouncementsByCourseID,
            syllabusByCourseID: courseSyllabusByCourseID,
            peopleByCourseID: coursePeopleByCourseID,
            moduleItemDetailsByKey: moduleItemDetailsByKey,
            courseAccessedAtByCourseID: courseDetailAccessDates,
            savedAt: savedAt
        )
    }

    private func applyCourseDetailCache(_ snapshot: CourseDetailCacheSnapshot) {
        courseAssignmentsByCourseID = snapshot.assignmentsByCourseID
        courseModulesByCourseID = snapshot.modulesByCourseID
        courseFoldersByCourseID = snapshot.foldersByCourseID
        courseFilesByFolderID = snapshot.filesByFolderID
        courseAnnouncementsByCourseID = snapshot.announcementsByCourseID
        courseSyllabusByCourseID = snapshot.syllabusByCourseID
        coursePeopleByCourseID = snapshot.peopleByCourseID
        moduleItemDetailsByKey = snapshot.moduleItemDetailsByKey
        courseDetailAccessDates = snapshot.courseAccessedAtByCourseID
    }

    private func mergeCourseDetailCache(_ snapshot: CourseDetailCacheSnapshot) {
        courseAssignmentsByCourseID.merge(snapshot.assignmentsByCourseID) { _, new in new }
        courseModulesByCourseID.merge(snapshot.modulesByCourseID) { _, new in new }
        courseFoldersByCourseID.merge(snapshot.foldersByCourseID) { _, new in new }
        courseFilesByFolderID.merge(snapshot.filesByFolderID) { _, new in new }
        courseAnnouncementsByCourseID.merge(snapshot.announcementsByCourseID) { _, new in new }
        courseSyllabusByCourseID.merge(snapshot.syllabusByCourseID) { _, new in new }
        coursePeopleByCourseID.merge(snapshot.peopleByCourseID) { _, new in new }
        moduleItemDetailsByKey.merge(snapshot.moduleItemDetailsByKey) { _, new in new }
        courseDetailAccessDates.merge(snapshot.courseAccessedAtByCourseID) { _, new in new }
    }

    private func handleCourseDetailLoadFailure(_ error: Error, courseID: Int) {
        guard !isCancellation(error) else {
            return
        }

        if restoreCachedCourseDetails(for: courseID) {
            errorMessage = "Could not refresh Canvas. Showing cached data from offline storage."
            return
        }

        displayError(error)
    }

    private func displayError(_ error: Error) {
        guard !isCancellation(error) else {
            return
        }

        errorMessage = error.localizedDescription
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func restoreCachedCourseDetails(for courseID: Int) -> Bool {
        guard let snapshot = detailCacheManager.loadCache(validAt: now(), maximumAge: cachePolicy.diskTimeToLive) else {
            return false
        }

        let courseSnapshot = snapshot.filteredForCourses([courseID])
        guard courseSnapshot.containsDetails(for: courseID) else {
            return false
        }

        mergeCourseDetailCache(courseSnapshot)
        return true
    }

    private func persistCourseDetailCache() {
        let validCourseIDs = Set(courses.map(\.id))
        let snapshot = buildCourseDetailCacheSnapshot(savedAt: now())
            .filteredForCourses(validCourseIDs)

        do {
            try detailCacheManager.saveCache(snapshot)
        } catch {
            displayError(error)
        }
    }

    private func markCourseDetailAccess(_ courseID: Int) {
        courseDetailAccessDates[courseID] = now()
    }

    private var cachedCourseDetailIDs: Set<Int> {
        Set(courseAssignmentsByCourseID.keys)
            .union(courseModulesByCourseID.keys)
            .union(courseFoldersByCourseID.keys)
            .union(courseAnnouncementsByCourseID.keys)
            .union(courseSyllabusByCourseID.keys)
            .union(coursePeopleByCourseID.keys)
            .union(moduleItemDetailsByKey.keys.compactMap { CourseModuleItemDetailKey(rawValue: $0).courseID })
    }

    private var courseIDsToKeepInMemory: Set<Int> {
        coursePreferences.offlinePriorityCourseIDs
            .union(Set([selectedCourseID].compactMap { $0 }))
    }

    private func restartAutoSyncIfNeeded(
        previous: AutoSyncConfig,
        current: AutoSyncConfig,
        forceRestart: Bool = false
    ) {
        guard forceRestart || previous != current else {
            if autoSyncTask == nil {
                startAutoSync()
            }
            return
        }

        stopAutoSync()
        startAutoSync()
    }

    private func persistCoursePreferences() {
        do {
            try preferenceManager.savePreferences(coursePreferences)
        } catch {
            displayError(error)
        }
    }

    private func updateDownloadRecord(
        file: CanvasFile,
        courseID: Int?,
        state: FileDownloadState,
        message: String? = nil
    ) {
        var record = fileDownloadSnapshot.recordsByFileID[file.id] ?? FileDownloadRecord(
            fileID: file.id,
            courseID: courseID,
            folderID: file.folderID,
            file: file
        )
        record.courseID = record.courseID ?? courseID
        record.folderID = record.folderID ?? file.folderID
        record.file = file
        record.state = state
        record.failureMessage = message
        fileDownloadSnapshot.recordsByFileID[file.id] = record
        fileDownloadSnapshot.updatedAt = now()
        persistFileDownloadSnapshot()
    }

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

        return downloadCacheLimitError(forAdditionalBytes: fileSize - existingBytes)
    }

    private func downloadCacheLimitError(forAdditionalBytes additionalBytes: Int) -> String? {
        guard let byteLimit = config.downloadCacheLimit.byteLimit else {
            return nil
        }

        let reservedBytes = reservedDownloadByteCount(excludingFileID: -1)
        let projectedBytes = reservedBytes + additionalBytes
        guard projectedBytes > byteLimit else {
            return nil
        }

        let currentUsage = ByteCountFormatter.string(
            fromByteCount: Int64(reservedBytes),
            countStyle: .file
        )
        let limit = ByteCountFormatter.string(fromByteCount: Int64(byteLimit), countStyle: .file)
        return "Download cache limit reached (\(currentUsage) of \(limit)). Reduce the offline selection, clear downloaded files, or raise the limit in Settings."
    }

    private func reservedDownloadByteCount(excludingFileID excludedFileID: Int) -> Int {
        fileDownloadSnapshot.recordsByFileID.reduce(0) { total, element in
            let (fileID, record) = element
            guard fileID != excludedFileID else {
                return total
            }

            switch record.state {
            case .downloaded:
                return total + (record.byteCount ?? record.file.size ?? 0)
            case .downloading:
                return total + (record.file.size ?? 0)
            case .notDownloaded, .failed:
                return total
            }
        }
    }

    private func markDownloadedFileMissing(_ record: FileDownloadRecord) {
        var updatedRecord = record
        updatedRecord.state = .failed
        updatedRecord.localPath = nil
        updatedRecord.downloadedAt = nil
        updatedRecord.byteCount = nil
        updatedRecord.failureMessage = FileDownloadError.missingLocalFile.localizedDescription
        fileDownloadSnapshot.recordsByFileID[record.fileID] = updatedRecord
        fileDownloadSnapshot.updatedAt = now()
        persistFileDownloadSnapshot()
    }

    private func updateConversationWorkflowState(
        _ conversation: CanvasConversation,
        state: CanvasConversationWorkflowState
    ) async {
        guard config.isComplete else {
            errorMessage = CanvasServiceError.incompleteConfiguration.localizedDescription
            return
        }

        do {
            let updatedConversation = try await networkManager.updateConversationWorkflowState(
                conversationID: conversation.id,
                state: state,
                using: config
            )
            if let index = inboxConversations.firstIndex(where: { $0.id == conversation.id }) {
                inboxConversations[index] = updatedConversation
                inboxConversations.sort(by: sortInboxConversations)
            }
        } catch {
            displayError(error)
        }
    }

    private func sortInboxConversations(_ lhs: CanvasConversation, _ rhs: CanvasConversation) -> Bool {
        switch (lhs.lastMessageAt, rhs.lastMessageAt) {
        case let (left?, right?):
            if left != right {
                return left > right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.displaySubject.localizedCaseInsensitiveCompare(rhs.displaySubject) == .orderedAscending
    }

    private func priorityMissingSubmissionPrecedes(_ lhs: MissingSubmission, _ rhs: MissingSubmission) -> Bool {
        priorityItemPrecedes(
            DashboardPriorityItem(kind: .missing(lhs), score: priorityScore(for: lhs)),
            DashboardPriorityItem(kind: .missing(rhs), score: priorityScore(for: rhs))
        )
    }

    private func priorityUpcomingEventPrecedes(_ lhs: UpcomingEvent, _ rhs: UpcomingEvent) -> Bool {
        priorityItemPrecedes(
            DashboardPriorityItem(kind: .upcoming(lhs), score: priorityScore(for: lhs)),
            DashboardPriorityItem(kind: .upcoming(rhs), score: priorityScore(for: rhs))
        )
    }

    private func priorityItemPrecedes(_ lhs: DashboardPriorityItem, _ rhs: DashboardPriorityItem) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

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

    private func priorityScore(for submission: MissingSubmission) -> Int {
        var score = 200

        if let dueAt = submission.dueAt {
            let day: TimeInterval = 24 * 60 * 60
            let delta = dueAt.timeIntervalSince(now())

            if delta < 0 {
                let overdueDays = min(Int(abs(delta) / day), 14)
                score += 80 + overdueDays * 6
            } else if delta <= day {
                score += 44
            } else if delta <= 3 * day {
                score += 28
            } else if delta <= 7 * day {
                score += 18
            } else {
                score += 8
            }
        } else {
            score += 12
        }

        score += coursePriorityBonus(for: submission.courseID)
        return score
    }

    private func priorityScore(for event: UpcomingEvent) -> Int {
        guard let date = event.displayDate else {
            return 0
        }

        let day: TimeInterval = 24 * 60 * 60
        let delta = date.timeIntervalSince(now())
        guard delta >= 0 else {
            return event.isAssignment ? 34 + coursePriorityBonus(for: event.courseID) : 0
        }

        var score = event.isAssignment ? 118 : 82
        if delta <= day {
            score += 36
        } else if delta <= 3 * day {
            score += 24
        } else if delta <= 7 * day {
            score += 14
        } else {
            score += 6
        }

        score += coursePriorityBonus(for: event.courseID)
        return score
    }

    private func coursePriorityBonus(for courseID: Int?) -> Int {
        guard let courseID else {
            return 0
        }

        var bonus = 0
        if coursePreferences.pinnedCourseIDs.contains(courseID) {
            bonus += 12
        }
        if coursePreferences.offlinePriorityCourseIDs.contains(courseID) {
            bonus += 6
        }
        return bonus
    }

    private func persistFileDownloadSnapshot() {
        do {
            try fileDownloadManager.saveSnapshot(fileDownloadSnapshot)
        } catch {
            displayError(error)
        }
    }

    private func persistRecentSearchTerms() {
        do {
            try recentSearchManager.saveTerms(recentSearchTerms)
        } catch {
            displayError(error)
        }
    }

    private func clearCourseDetailMemoryCache() {
        courseAssignmentsByCourseID = [:]
        loadingCourseAssignmentIDs = []
        courseModulesByCourseID = [:]
        loadingCourseModuleIDs = []
        courseFoldersByCourseID = [:]
        courseFilesByFolderID = [:]
        loadingCourseFolderIDs = []
        loadingFolderFileIDs = []
        courseAnnouncementsByCourseID = [:]
        loadingCourseAnnouncementIDs = []
        courseSyllabusByCourseID = [:]
        loadingCourseSyllabusIDs = []
        coursePeopleByCourseID = [:]
        loadingCoursePeopleIDs = []
        moduleItemDetailsByKey = [:]
        loadingModuleItemDetailKeys = []
        courseDetailAccessDates = [:]
    }

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

        if let record = fileDownloadSnapshot.recordsByFileID[file.id] {
            switch record.state {
            case .downloaded:
                skippedByFileID[file.id] = OfflineDownloadSkippedFile(
                    courseID: courseID,
                    folderID: folderID,
                    file: file,
                    reason: .alreadyDownloaded
                )
                return
            case .downloading:
                skippedByFileID[file.id] = OfflineDownloadSkippedFile(
                    courseID: courseID,
                    folderID: folderID,
                    file: file,
                    reason: .alreadyDownloading
                )
                return
            case .failed, .notDownloaded:
                break
            }
        }

        if file.isUnavailable {
            skippedByFileID[file.id] = OfflineDownloadSkippedFile(
                courseID: courseID,
                folderID: folderID,
                file: file,
                reason: .unavailable
            )
            return
        }

        if file.url == nil {
            skippedByFileID[file.id] = OfflineDownloadSkippedFile(
                courseID: courseID,
                folderID: folderID,
                file: file,
                reason: .missingDownloadURL
            )
            return
        }

        itemsByFileID[file.id] = OfflineDownloadPlanItem(courseID: courseID, folderID: folderID, file: file)
    }

    private func offlineDownloadPlanItemPrecedes(
        _ lhs: OfflineDownloadPlanItem,
        _ rhs: OfflineDownloadPlanItem
    ) -> Bool {
        offlineDownloadPlanSortKeyPrecedes(
            lhsFile: lhs.file,
            lhsCourseID: lhs.courseID,
            lhsFolderID: lhs.folderID,
            rhsFile: rhs.file,
            rhsCourseID: rhs.courseID,
            rhsFolderID: rhs.folderID
        )
    }

    private func offlineDownloadSkippedFilePrecedes(
        _ lhs: OfflineDownloadSkippedFile,
        _ rhs: OfflineDownloadSkippedFile
    ) -> Bool {
        offlineDownloadPlanSortKeyPrecedes(
            lhsFile: lhs.file,
            lhsCourseID: lhs.courseID,
            lhsFolderID: lhs.folderID,
            rhsFile: rhs.file,
            rhsCourseID: rhs.courseID,
            rhsFolderID: rhs.folderID
        )
    }

    private func offlineDownloadPlanSortKeyPrecedes(
        lhsFile: CanvasFile,
        lhsCourseID: Int,
        lhsFolderID: Int?,
        rhsFile: CanvasFile,
        rhsCourseID: Int,
        rhsFolderID: Int?
    ) -> Bool {
        let nameComparison = lhsFile.name.localizedCaseInsensitiveCompare(rhsFile.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        if lhsCourseID != rhsCourseID {
            return lhsCourseID < rhsCourseID
        }

        let lhsFolderSortID = lhsFolderID ?? -1
        let rhsFolderSortID = rhsFolderID ?? -1
        if lhsFolderSortID != rhsFolderSortID {
            return lhsFolderSortID < rhsFolderSortID
        }

        return lhsFile.id < rhsFile.id
    }

    private func courseID(containingFolderID folderID: Int) -> Int? {
        courseFoldersByCourseID.first { _, folders in
            folders.contains { $0.id == folderID }
        }?.key
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

    private func applySnapshot(_ snapshot: CanvasSnapshot) {
        courses = snapshot.courses
        upcomingEvents = snapshot.upcomingEvents
        missingSubmissions = snapshot.missingSubmissions
        profile = snapshot.profile
        lastSyncedAt = snapshot.syncedAt

        if let selectedCourseID, courses.contains(where: { $0.id == selectedCourseID }) {
            return
        }

        self.selectedCourseID = courses.first?.id
    }
}

private extension CourseDetailCacheSnapshot {
    func containsDetails(for courseID: Int) -> Bool {
        assignmentsByCourseID[courseID] != nil
            || modulesByCourseID[courseID] != nil
            || foldersByCourseID[courseID] != nil
            || announcementsByCourseID[courseID] != nil
            || syllabusByCourseID[courseID] != nil
            || peopleByCourseID[courseID] != nil
            || moduleItemDetailsByKey.keys.contains { CourseModuleItemDetailKey(rawValue: $0).courseID == courseID }
    }
}
