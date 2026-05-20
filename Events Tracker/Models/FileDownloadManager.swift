//
//  FileDownloadManager.swift
//  Events Tracker
//

import Foundation

enum FileDownloadError: LocalizedError {
    case missingDownloadURL
    case missingLocalFile

    var errorDescription: String? {
        switch self {
        case .missingDownloadURL:
            return "Canvas did not provide a direct download URL for this file."
        case .missingLocalFile:
            return "The downloaded file is missing from local storage."
        }
    }
}

final class FileDownloadManager {
    static let shared = FileDownloadManager()

    private let metadataURL: URL
    private let downloadsDirectory: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(metadataURL: URL? = nil, downloadsDirectory: URL? = nil, session: URLSession = .shared) {
        self.session = session

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.metadataURL = metadataURL ?? appDirectory.appendingPathComponent("file-downloads.json")
        self.downloadsDirectory = downloadsDirectory ?? appDirectory.appendingPathComponent("Downloads", isDirectory: true)

        try? fileManager.createDirectory(at: self.downloadsDirectory, withIntermediateDirectories: true)
    }

    func loadSnapshot() -> FileDownloadSnapshot {
        guard let data = try? Data(contentsOf: metadataURL) else {
            return FileDownloadSnapshot()
        }

        guard let snapshot = try? decoder.decode(FileDownloadSnapshot.self, from: data) else {
            try? clearMetadata()
            return FileDownloadSnapshot()
        }

        let reconciledSnapshot = reconciledSnapshot(snapshot)
        if reconciledSnapshot != snapshot {
            try? saveSnapshot(reconciledSnapshot)
        }

        return reconciledSnapshot
    }

    func saveSnapshot(_ snapshot: FileDownloadSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: metadataURL, options: .atomic)
    }

    func localURL(for file: CanvasFile, courseID: Int?) -> URL {
        let courseComponent = courseID.map(String.init) ?? "unknown-course"
        let filename = "\(file.id)-\(FileDownloadRecord.safeFilename(for: file))"
        return downloadsDirectory
            .appendingPathComponent(courseComponent, isDirectory: true)
            .appendingPathComponent(filename)
    }

    func download(file: CanvasFile, courseID: Int?, using config: CanvasConfig) async throws -> FileDownloadRecord {
        guard let downloadURL = file.url else {
            throw FileDownloadError.missingDownloadURL
        }

        let localURL = localURL(for: file, courseID: courseID)
        try FileManager.default.createDirectory(
            at: localURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var request = URLRequest(url: downloadURL)
        request.setValue("Bearer \(config.trimmedToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CanvasServiceError.invalidResponse
        }

        try data.write(to: localURL, options: .atomic)

        return FileDownloadRecord(
            fileID: file.id,
            courseID: courseID,
            folderID: file.folderID,
            file: file,
            state: .downloaded,
            localPath: localURL.path,
            downloadedAt: Date(),
            failureMessage: nil,
            byteCount: data.count
        )
    }

    func removeDownloadedFile(_ record: FileDownloadRecord) throws {
        guard let localPath = record.localPath else {
            return
        }

        let url = URL(fileURLWithPath: localPath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func clearDownloadedFilesDirectory() throws {
        if FileManager.default.fileExists(atPath: downloadsDirectory.path) {
            try FileManager.default.removeItem(at: downloadsDirectory)
        }

        try FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    func clearAllData() throws {
        try clearDownloadedFilesDirectory()
        try clearMetadata()
    }

    func clearMetadata() throws {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: metadataURL)
    }

    func localFileExists(for record: FileDownloadRecord) -> Bool {
        guard let localPath = record.localPath else {
            return false
        }

        return FileManager.default.fileExists(atPath: localPath)
    }

    func reconciledSnapshot(_ snapshot: FileDownloadSnapshot) -> FileDownloadSnapshot {
        var snapshot = snapshot

        for (fileID, record) in snapshot.recordsByFileID {
            var updatedRecord = record

            if updatedRecord.state == .downloading {
                updatedRecord.state = .failed
                updatedRecord.failureMessage = "Download was interrupted before it completed."
            }

            if updatedRecord.state == .downloaded && !localFileExists(for: updatedRecord) {
                updatedRecord.state = .failed
                updatedRecord.failureMessage = FileDownloadError.missingLocalFile.localizedDescription
                updatedRecord.localPath = nil
                updatedRecord.downloadedAt = nil
                updatedRecord.byteCount = nil
            }

            snapshot.recordsByFileID[fileID] = updatedRecord
        }

        return snapshot
    }
}
