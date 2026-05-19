//
//  CourseDetailCacheManager.swift
//  Events Tracker
//

import Foundation

struct CanvasCachePolicy: Equatable {
    let memoryTimeToLive: TimeInterval
    let diskTimeToLive: TimeInterval
    let maintenanceInterval: TimeInterval
    let maximumMemoryCourses: Int

    static let `default` = CanvasCachePolicy(
        memoryTimeToLive: 30 * 60,
        diskTimeToLive: 24 * 60 * 60,
        maintenanceInterval: 60 * 60,
        maximumMemoryCourses: 5
    )
}

struct CourseDetailCacheSnapshot: Codable, Equatable {
    let assignmentsByCourseID: [Int: [CourseAssignment]]
    let modulesByCourseID: [Int: [CourseModule]]
    let foldersByCourseID: [Int: [CanvasFolder]]
    let filesByFolderID: [Int: [CanvasFile]]
    let announcementsByCourseID: [Int: [CourseAnnouncement]]
    let syllabusByCourseID: [Int: CourseSyllabus]
    let peopleByCourseID: [Int: [CoursePerson]]
    let courseAccessedAtByCourseID: [Int: Date]
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case assignmentsByCourseID
        case modulesByCourseID
        case foldersByCourseID
        case filesByFolderID
        case announcementsByCourseID
        case syllabusByCourseID
        case peopleByCourseID
        case courseAccessedAtByCourseID
        case savedAt
    }

    init(
        assignmentsByCourseID: [Int: [CourseAssignment]],
        modulesByCourseID: [Int: [CourseModule]],
        foldersByCourseID: [Int: [CanvasFolder]],
        filesByFolderID: [Int: [CanvasFile]],
        announcementsByCourseID: [Int: [CourseAnnouncement]],
        syllabusByCourseID: [Int: CourseSyllabus],
        peopleByCourseID: [Int: [CoursePerson]] = [:],
        courseAccessedAtByCourseID: [Int: Date],
        savedAt: Date
    ) {
        self.assignmentsByCourseID = assignmentsByCourseID
        self.modulesByCourseID = modulesByCourseID
        self.foldersByCourseID = foldersByCourseID
        self.filesByFolderID = filesByFolderID
        self.announcementsByCourseID = announcementsByCourseID
        self.syllabusByCourseID = syllabusByCourseID
        self.peopleByCourseID = peopleByCourseID
        self.courseAccessedAtByCourseID = courseAccessedAtByCourseID
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assignmentsByCourseID = try container.decode([Int: [CourseAssignment]].self, forKey: .assignmentsByCourseID)
        modulesByCourseID = try container.decode([Int: [CourseModule]].self, forKey: .modulesByCourseID)
        foldersByCourseID = try container.decode([Int: [CanvasFolder]].self, forKey: .foldersByCourseID)
        filesByFolderID = try container.decode([Int: [CanvasFile]].self, forKey: .filesByFolderID)
        announcementsByCourseID = try container.decode([Int: [CourseAnnouncement]].self, forKey: .announcementsByCourseID)
        syllabusByCourseID = try container.decode([Int: CourseSyllabus].self, forKey: .syllabusByCourseID)
        peopleByCourseID = try container.decodeIfPresent([Int: [CoursePerson]].self, forKey: .peopleByCourseID) ?? [:]
        courseAccessedAtByCourseID = try container.decode([Int: Date].self, forKey: .courseAccessedAtByCourseID)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assignmentsByCourseID, forKey: .assignmentsByCourseID)
        try container.encode(modulesByCourseID, forKey: .modulesByCourseID)
        try container.encode(foldersByCourseID, forKey: .foldersByCourseID)
        try container.encode(filesByFolderID, forKey: .filesByFolderID)
        try container.encode(announcementsByCourseID, forKey: .announcementsByCourseID)
        try container.encode(syllabusByCourseID, forKey: .syllabusByCourseID)
        try container.encode(peopleByCourseID, forKey: .peopleByCourseID)
        try container.encode(courseAccessedAtByCourseID, forKey: .courseAccessedAtByCourseID)
        try container.encode(savedAt, forKey: .savedAt)
    }

    func prunedForMemory(
        now: Date = Date(),
        timeToLive: TimeInterval,
        maximumCourses: Int,
        alwaysKeepingCourseIDs: Set<Int> = []
    ) -> CourseDetailCacheSnapshot {
        let detailCourseIDs = courseIDsWithDetails
        var keptCourseIDs = alwaysKeepingCourseIDs.intersection(detailCourseIDs)
        let remainingCapacity = max(0, maximumCourses - keptCourseIDs.count)

        let eligibleCourseIDs = detailCourseIDs
            .subtracting(keptCourseIDs)
            .filter { courseID in
                guard let accessedAt = courseAccessedAtByCourseID[courseID] else {
                    return false
                }

                return now.timeIntervalSince(accessedAt) <= timeToLive
            }
            .sorted { lhs, rhs in
                let left = courseAccessedAtByCourseID[lhs] ?? .distantPast
                let right = courseAccessedAtByCourseID[rhs] ?? .distantPast

                if left != right {
                    return left > right
                }

                return lhs < rhs
            }
            .prefix(remainingCapacity)

        keptCourseIDs.formUnion(eligibleCourseIDs)

        return CourseDetailCacheSnapshot(
            assignmentsByCourseID: assignmentsByCourseID.filterKeys(keptCourseIDs),
            modulesByCourseID: modulesByCourseID.filterKeys(keptCourseIDs),
            foldersByCourseID: foldersByCourseID.filterKeys(keptCourseIDs),
            filesByFolderID: filesForKeptCourses(keptCourseIDs),
            announcementsByCourseID: announcementsByCourseID.filterKeys(keptCourseIDs),
            syllabusByCourseID: syllabusByCourseID.filterKeys(keptCourseIDs),
            peopleByCourseID: peopleByCourseID.filterKeys(keptCourseIDs),
            courseAccessedAtByCourseID: courseAccessedAtByCourseID.filterKeys(keptCourseIDs),
            savedAt: savedAt
        )
    }

    func filteredForCourses(_ courseIDs: Set<Int>) -> CourseDetailCacheSnapshot {
        CourseDetailCacheSnapshot(
            assignmentsByCourseID: assignmentsByCourseID.filterKeys(courseIDs),
            modulesByCourseID: modulesByCourseID.filterKeys(courseIDs),
            foldersByCourseID: foldersByCourseID.filterKeys(courseIDs),
            filesByFolderID: filesForKeptCourses(courseIDs),
            announcementsByCourseID: announcementsByCourseID.filterKeys(courseIDs),
            syllabusByCourseID: syllabusByCourseID.filterKeys(courseIDs),
            peopleByCourseID: peopleByCourseID.filterKeys(courseIDs),
            courseAccessedAtByCourseID: courseAccessedAtByCourseID.filterKeys(courseIDs),
            savedAt: savedAt
        )
    }

    private var courseIDsWithDetails: Set<Int> {
        Set(assignmentsByCourseID.keys)
            .union(modulesByCourseID.keys)
            .union(foldersByCourseID.keys)
            .union(announcementsByCourseID.keys)
            .union(syllabusByCourseID.keys)
            .union(peopleByCourseID.keys)
    }

    private func filesForKeptCourses(_ courseIDs: Set<Int>) -> [Int: [CanvasFile]] {
        let keptFolderIDs = foldersByCourseID
            .filter { courseIDs.contains($0.key) }
            .values
            .flatMap { folders in folders.map(\.id) }

        return filesByFolderID.filterKeys(Set(keptFolderIDs))
    }
}

final class CourseDetailCacheManager {
    static let shared = CourseDetailCacheManager()

    private let cacheURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(cacheURL: URL? = nil) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if let cacheURL {
            self.cacheURL = cacheURL
            return
        }

        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let appDirectory = baseDirectory.appendingPathComponent("EventsTracker", isDirectory: true)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.cacheURL = appDirectory.appendingPathComponent("course-detail-cache.json")
    }

    func saveCache(_ snapshot: CourseDetailCacheSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: cacheURL, options: .atomic)
    }

    func loadCache(validAt referenceDate: Date = Date(), maximumAge: TimeInterval) -> CourseDetailCacheSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }

        guard let snapshot = try? decoder.decode(CourseDetailCacheSnapshot.self, from: data) else {
            try? clearCache()
            return nil
        }

        guard referenceDate.timeIntervalSince(snapshot.savedAt) <= maximumAge else {
            try? clearCache()
            return nil
        }

        return snapshot
    }

    func clearCache() throws {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: cacheURL)
    }
}

private extension Dictionary {
    func filterKeys(_ keys: Set<Key>) -> [Key: Value] {
        filter { keys.contains($0.key) }
    }
}
