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
