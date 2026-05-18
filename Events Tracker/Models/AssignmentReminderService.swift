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
        guard shouldRun else {
            stop()
            return
        }

        startLoop()
    }

    func stop() {
        reminderTask?.cancel()
        reminderTask = nil
        isChecking = false
    }

    func updateConfig(_ config: CanvasConfig) {
        let previousReminderConfig = self.config.telegramReminders
        let wasRunning = reminderTask != nil
        self.config = config

        guard shouldRun else {
            stop()
            return
        }

        guard wasRunning else {
            startLoop()
            return
        }

        if shouldRestartLoop(previous: previousReminderConfig, current: config.telegramReminders) {
            stop()
            startLoop()
        }
    }

    private func startLoop() {
        guard reminderTask == nil else {
            return
        }

        reminderTask = Task { [weak self] in
            await self?.runLoop()
        }
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
                guard !Task.isCancelled else {
                    return
                }

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
                guard shouldSendMessages(using: currentConfig), !Task.isCancelled else {
                    return
                }

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
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled {
                return
            }

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

    private var shouldRun: Bool {
        config.isComplete
            && config.telegramReminders.isEnabled
            && config.telegramReminders.isComplete
    }

    private func shouldRestartLoop(
        previous: TelegramReminderConfig,
        current: TelegramReminderConfig
    ) -> Bool {
        previous.isEnabled != current.isEnabled
            || previous.normalizedCheckIntervalMinutes != current.normalizedCheckIntervalMinutes
            || previous.trimmedBotToken != current.trimmedBotToken
            || previous.trimmedChatID != current.trimmedChatID
    }

    private func shouldSendMessages(using checkConfig: CanvasConfig) -> Bool {
        config.telegramReminders.isEnabled
            && config.telegramReminders.trimmedBotToken == checkConfig.telegramReminders.trimmedBotToken
            && config.telegramReminders.trimmedChatID == checkConfig.telegramReminders.trimmedChatID
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
