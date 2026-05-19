//
//  DatabaseManager.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

final class DatabaseManager {
    static let shared = DatabaseManager()

    private let cacheURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(cacheURL: URL? = nil) {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.cacheURL = cacheURL ?? appDirectory.appendingPathComponent("canvas-cache.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    func saveSnapshot(_ snapshot: CanvasSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: cacheURL, options: .atomic)
    }

    func loadSnapshot() -> CanvasSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }

        return try? decoder.decode(CanvasSnapshot.self, from: data)
    }

    func clearSnapshot() throws {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: cacheURL)
    }
}
