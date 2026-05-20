//
//  RecentSearchManager.swift
//  Events Tracker
//

import Foundation

final class RecentSearchManager {
    static let shared = RecentSearchManager()

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
            return
        }

        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.storageURL = appDirectory.appendingPathComponent("recent-searches.json")
    }

    func loadTerms() -> [String] {
        guard let data = try? Data(contentsOf: storageURL) else {
            return []
        }

        guard let terms = try? decoder.decode([String].self, from: data) else {
            try? clearTerms()
            return []
        }

        return terms
    }

    func saveTerms(_ terms: [String]) throws {
        let data = try encoder.encode(Array(terms.prefix(10)))
        try data.write(to: storageURL, options: .atomic)
    }

    func clearTerms() throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: storageURL)
    }
}
