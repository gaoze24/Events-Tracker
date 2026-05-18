//
//  CanvasStore.swift
//  Events Tracker
//
//  Created by Codex on 13/4/26.
//

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
    private let reminderService: AssignmentReminderService
    private let relativeFormatter = RelativeDateTimeFormatter()

    init(
        configManager: CanvasConfigManager = .shared,
        databaseManager: DatabaseManager = .shared,
        networkManager: NetworkManager = .shared
    ) {
        self.configManager = configManager
        self.databaseManager = databaseManager
        self.networkManager = networkManager

        let savedConfig = configManager.loadConfig()
        config = savedConfig
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
            upcomingEvents = []
            missingSubmissions = []
            profile = nil
            lastSyncedAt = nil
        }

        selectedCourseID = courses.first?.id
        relativeFormatter.unitsStyle = .full
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
            courseAssignmentsByCourseID = [:]
            loadingCourseAssignmentIDs = []
            courseModulesByCourseID = [:]
            loadingCourseModuleIDs = []
            courseFoldersByCourseID = [:]
            courseFilesByFolderID = [:]
            loadingCourseFolderIDs = []
            loadingFolderFileIDs = []
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

    func clearLocalData() {
        courses = []
        courseAssignmentsByCourseID = [:]
        loadingCourseAssignmentIDs = []
        courseModulesByCourseID = [:]
        loadingCourseModuleIDs = []
        courseFoldersByCourseID = [:]
        courseFilesByFolderID = [:]
        loadingCourseFolderIDs = []
        loadingFolderFileIDs = []
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
        guard
            let courseID,
            courseAssignmentsByCourseID[courseID] == nil,
            !loadingCourseAssignmentIDs.contains(courseID)
        else {
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
        } catch {
            errorMessage = error.localizedDescription
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
        guard
            let courseID,
            courseModulesByCourseID[courseID] == nil,
            !loadingCourseModuleIDs.contains(courseID)
        else {
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
        } catch {
            errorMessage = error.localizedDescription
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

    func loadCourseFilesIfNeeded(for courseID: Int?) async {
        guard
            let courseID,
            courseFoldersByCourseID[courseID] == nil,
            !loadingCourseFolderIDs.contains(courseID)
        else {
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

            if let firstFolderID = folders.first?.id, courseFilesByFolderID[firstFolderID] == nil {
                await loadFiles(for: firstFolderID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        loadingCourseFolderIDs.remove(courseID)
    }

    func loadFilesIfNeeded(for folderID: Int?) async {
        guard
            let folderID,
            courseFilesByFolderID[folderID] == nil,
            !loadingFolderFileIDs.contains(folderID)
        else {
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
        } catch {
            errorMessage = error.localizedDescription
        }

        loadingFolderFileIDs.remove(folderID)
    }

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
