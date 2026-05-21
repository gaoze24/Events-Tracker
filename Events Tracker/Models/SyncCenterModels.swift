//
//  SyncCenterModels.swift
//  Events Tracker
//

import Foundation

struct LocalDataInventory: Equatable {
    let isConfigured: Bool
    let lastDashboardSync: Date?
    let courseDetailCourseCount: Int
    let knownFileCount: Int
    let downloadedFileCount: Int
    let downloadedByteCount: Int
    let downloadCacheLimitBytes: Int?
    let downloadCacheLimitLabel: String
    let recentSearchCount: Int
    let pinnedCourseCount: Int
    let hiddenCourseCount: Int
    let offlinePriorityCourseCount: Int
}

struct CourseOfflineReadiness: Identifiable, Equatable {
    let courseID: Int
    let courseName: String
    let isOfflinePriority: Bool
    let hasAssignments: Bool
    let hasModules: Bool
    let hasFilesMetadata: Bool
    let hasAnnouncements: Bool
    let hasSyllabus: Bool
    let hasPeople: Bool
    let lastAccessedAt: Date?

    var id: Int { courseID }

    var totalSectionCount: Int { 6 }

    var cachedSectionCount: Int {
        [
            hasAssignments,
            hasModules,
            hasFilesMetadata,
            hasAnnouncements,
            hasSyllabus,
            hasPeople
        ].filter { $0 }.count
    }

    var isFullyCached: Bool {
        cachedSectionCount == totalSectionCount
    }
}

struct OfflineDownloadSelection: Equatable {
    var selectedCourseIDs: Set<Int> = []
    var selectedFolderIDs: Set<Int> = []
    var selectedFileIDs: Set<Int> = []
}

enum OfflineDownloadSkipReason: String, Codable, CaseIterable, Hashable, Identifiable {
    case unavailable
    case alreadyDownloaded
    case alreadyDownloading
    case missingDownloadURL

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .alreadyDownloaded:
            return "Already Downloaded"
        case .alreadyDownloading:
            return "Already Downloading"
        case .missingDownloadURL:
            return "Missing Download URL"
        }
    }
}

struct OfflineDownloadPlanItem: Identifiable, Equatable {
    let courseID: Int
    let folderID: Int?
    let file: CanvasFile

    var id: Int { file.id }
    var estimatedByteCount: Int? { file.size }
}

struct OfflineDownloadSkippedFile: Identifiable, Equatable {
    let courseID: Int
    let folderID: Int?
    let file: CanvasFile
    let reason: OfflineDownloadSkipReason

    var id: String { "\(file.id)-\(reason.rawValue)" }
}

struct OfflineDownloadPlan: Equatable {
    var items: [OfflineDownloadPlanItem]
    var skippedFiles: [OfflineDownloadSkippedFile]

    init(items: [OfflineDownloadPlanItem] = [], skippedFiles: [OfflineDownloadSkippedFile] = []) {
        self.items = items
        self.skippedFiles = skippedFiles
    }

    var fileCount: Int { items.count }
    var skippedCount: Int { skippedFiles.count }
    var isEmpty: Bool { items.isEmpty }

    var estimatedByteCount: Int {
        items.reduce(0) { total, item in
            total + (item.estimatedByteCount ?? 0)
        }
    }

    var unknownSizeCount: Int {
        items.filter { $0.estimatedByteCount == nil }.count
    }

    func skippedCount(for reason: OfflineDownloadSkipReason) -> Int {
        skippedFiles.filter { $0.reason == reason }.count
    }
}

struct OfflineBulkDownloadProgress: Equatable {
    let totalCount: Int
    var completedCount: Int
    var failedCount: Int
    let skippedCount: Int

    var processedCount: Int {
        completedCount + failedCount
    }

    var isComplete: Bool {
        processedCount >= totalCount
    }
}
