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

    init(
        configManager: CanvasConfigManager = .shared,
        databaseManager: DatabaseManager = .shared,
        networkManager: NetworkManager = .shared,
        detailCacheManager: CourseDetailCacheManager = .shared,
        preferenceManager: CoursePreferenceManager = .shared,
        fileDownloadManager: FileDownloadManager = .shared,
        recentSearchManager: RecentSearchManager = .shared,
        cachePolicy: CanvasCachePolicy = .default,
        now: @escaping () -> Date = Date.init
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

        let savedConfig = configManager.loadConfig()
        config = savedConfig
        coursePreferences = preferenceManager.loadPreferences()
        fileDownloadSnapshot = fileDownloadManager.loadSnapshot()
        downloadingFileIDs = []
        preloadingCourseIDs = []
        recentSearchTerms = recentSearchManager.loadTerms()
        inboxConversations = []
        loadingInbox = false
        inboxLastLoadedAt = nil
        reminderService = AssignmentReminderService(
            config: savedConfig,
            networkManager: networkManager,
            telegramManager: .shared,
            historyManager: .shared
        )

        if let snapshot = databaseManager.loadSnapshot() {
            courses = snapshot.courses
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
            upcomingEvents = snapshot.upcomingEvents
            missingSubmissions = snapshot.missingSubmissions
            profile = snapshot.profile
            lastSyncedAt = snapshot.syncedAt
        } else {
            courses = []
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
            upcomingEvents = []
            missingSubmissions = []
            profile = nil
            lastSyncedAt = nil
        }

        selectedCourseID = courses.first?.id
        relativeFormatter.unitsStyle = .full
        restoreCourseDetailCache()
    }

    deinit {
        cacheMaintenanceTask?.cancel()
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
            applySnapshot(snapshot)
            try databaseManager.saveSnapshot(snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSyncing = false
    }

    @discardableResult
    func saveConfiguration(
        baseURL: String,
        token: String,
        lookaheadDays: Int,
        telegramReminders: TelegramReminderConfig,
        downloadCacheLimit: DownloadCacheLimitPreset = .unlimited
    ) throws -> Bool {
        let updatedConfig = CanvasConfig(
            baseURL: baseURL,
            token: token,
            lookaheadDays: lookaheadDays,
            telegramReminders: telegramReminders,
            downloadCacheLimit: downloadCacheLimit
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
            preloadingCourseIDs = []
            try recentSearchManager.clearTerms()
            recentSearchTerms = []
            inboxConversations = []
            loadingInbox = false
            inboxLastLoadedAt = nil
        } catch {
            errorMessage = error.localizedDescription
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
        guard let courseID else {
            return upcomingEvents
        }

        return upcomingEvents.filter { $0.courseID == courseID }
    }

    func filteredMissingSubmissions(courseID: Int?) -> [MissingSubmission] {
        guard let courseID else {
            return missingSubmissions
        }

        return missingSubmissions.filter { $0.courseID == courseID }
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
                errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    func clearCourseDetailCache() {
        clearCourseDetailMemoryCache()

        do {
            try detailCacheManager.clearCache()
        } catch {
            errorMessage = error.localizedDescription
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
            await loadFilesIfNeeded(for: folder.id)
        }

        await loadAnnouncements(for: courseID)
        await loadSyllabus(for: courseID)
        await loadPeople(for: courseID)
    }

    func globalSearchResults(for query: String) -> [GlobalSearchResult] {
        GlobalSearchIndex.results(
            query: query,
            courses: courses,
            upcomingEvents: upcomingEvents,
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
        if restoreCachedCourseDetails(for: courseID) {
            errorMessage = "Could not refresh Canvas. Showing cached data from offline storage."
            return
        }

        errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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

    private func persistCoursePreferences() {
        do {
            try preferenceManager.savePreferences(coursePreferences)
        } catch {
            errorMessage = error.localizedDescription
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
        guard let byteLimit = config.downloadCacheLimit.byteLimit else {
            return nil
        }

        guard let fileSize = file.size else {
            return nil
        }

        let reservedBytes = reservedDownloadByteCount(excludingFileID: file.id)
        let projectedBytes = reservedBytes + fileSize
        guard projectedBytes > byteLimit else {
            return nil
        }

        let currentUsage = ByteCountFormatter.string(
            fromByteCount: Int64(reservedBytes),
            countStyle: .file
        )
        let limit = ByteCountFormatter.string(fromByteCount: Int64(byteLimit), countStyle: .file)
        return "Download cache limit reached (\(currentUsage) of \(limit)). Clear downloaded files or raise the limit in Settings."
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
            errorMessage = error.localizedDescription
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

    private func persistFileDownloadSnapshot() {
        do {
            try fileDownloadManager.saveSnapshot(fileDownloadSnapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistRecentSearchTerms() {
        do {
            try recentSearchManager.saveTerms(recentSearchTerms)
        } catch {
            errorMessage = error.localizedDescription
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

    private func courseID(containingFolderID folderID: Int) -> Int? {
        courseFoldersByCourseID.first { _, folders in
            folders.contains { $0.id == folderID }
        }?.key
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
