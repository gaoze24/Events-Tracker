//
//  CoursePreferenceManager.swift
//  Events Tracker
//

import Foundation

final class CoursePreferenceManager {
    static let shared = CoursePreferenceManager()

    private let preferencesURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(preferencesURL: URL? = nil) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()

        if let preferencesURL {
            self.preferencesURL = preferencesURL
            return
        }

        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.preferencesURL = appDirectory.appendingPathComponent("course-preferences.json")
    }

    func loadPreferences() -> CoursePreferencesSnapshot {
        guard let data = try? Data(contentsOf: preferencesURL) else {
            return CoursePreferencesSnapshot()
        }

        guard let snapshot = try? decoder.decode(CoursePreferencesSnapshot.self, from: data) else {
            try? clearPreferences()
            return CoursePreferencesSnapshot()
        }

        return snapshot
    }

    func savePreferences(_ snapshot: CoursePreferencesSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: preferencesURL, options: .atomic)
    }

    func clearPreferences() throws {
        guard FileManager.default.fileExists(atPath: preferencesURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: preferencesURL)
    }
}
