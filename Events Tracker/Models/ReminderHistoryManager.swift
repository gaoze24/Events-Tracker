//
//  ReminderHistoryManager.swift
//  Events Tracker
//

import Foundation

final class ReminderHistoryManager {
    static let shared = ReminderHistoryManager()

    private let historyURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(historyURL: URL? = nil) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if let historyURL {
            self.historyURL = historyURL
            return
        }

        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.historyURL = appDirectory.appendingPathComponent("telegram-reminder-history.json")
    }

    static func historyKey(courseID: Int, assignmentID: Int) -> String {
        "\(courseID):\(assignmentID)"
    }

    func loadHistory() -> [String: Date] {
        guard let data = try? Data(contentsOf: historyURL) else {
            return [:]
        }

        return (try? decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    func saveHistory(_ history: [String: Date]) throws {
        let data = try encoder.encode(history)
        try data.write(to: historyURL, options: .atomic)
    }
}
