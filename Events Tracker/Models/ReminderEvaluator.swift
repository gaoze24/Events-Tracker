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
                isActionableReminderAssignment(assignment),
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

    private static func isActionableReminderAssignment(_ assignment: CourseAssignment) -> Bool {
        guard assignment.published != false else {
            return false
        }

        let submissionTypes = (assignment.submissionTypes ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !submissionTypes.isEmpty else {
            return false
        }

        return submissionTypes.contains { submissionType in
            submissionType.hasPrefix("online_")
                || submissionType.hasPrefix("external_")
                || submissionType == "discussion_topic"
        }
    }
}
