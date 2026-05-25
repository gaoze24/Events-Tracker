//
//  GlobalSearchIndex.swift
//  Events Tracker
//

import Foundation

struct GlobalSearchIndex {
    static func results(
        query: String,
        courses: [Course],
        upcomingEvents: [UpcomingEvent],
        missingSubmissions: [MissingSubmission],
        assignmentsByCourseID: [Int: [CourseAssignment]],
        modulesByCourseID: [Int: [CourseModule]],
        foldersByCourseID: [Int: [CanvasFolder]],
        filesByFolderID: [Int: [CanvasFile]],
        announcementsByCourseID: [Int: [CourseAnnouncement]],
        syllabusByCourseID: [Int: CourseSyllabus],
        peopleByCourseID: [Int: [CoursePerson]],
        moduleItemDetailsByKey: [String: CourseModuleItemDetail]
    ) -> [GlobalSearchResult] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let queryTokens = tokens(from: normalizedQuery)
        let referenceDate = Date()
        let courseNames = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name) })
        let courseIDsByFolderID = foldersByCourseID.reduce(into: [Int: Int]()) { partialResult, entry in
            let (courseID, folders) = entry
            for folder in folders {
                partialResult[folder.id] = courseID
            }
        }
        var candidates: [GlobalSearchResult] = []

        for course in courses {
            candidates.append(makeResult(
                id: "course-\(course.id)",
                kind: .course,
                title: course.name,
                subtitle: course.courseCode ?? course.enrollmentTerm?.name,
                courseID: course.id,
                courseName: course.name,
                url: course.htmlURL,
                fields: [course.name, course.courseCode, course.enrollmentTerm?.name],
                query: normalizedQuery,
                queryTokens: queryTokens,
                referenceDate: referenceDate
            ))
        }

        for event in upcomingEvents {
            candidates.append(makeResult(
                id: "event-\(event.id)",
                kind: .event,
                title: event.title,
                subtitle: event.kindLabel,
                courseID: event.courseID,
                courseName: event.courseID.flatMap { courseNames[$0] },
                url: event.actionableURL,
                fields: [event.title, event.details, event.kindLabel, event.workflowState],
                query: normalizedQuery,
                queryTokens: queryTokens,
                referenceDate: referenceDate,
                urgencyDate: event.displayDate,
                isAssignmentBackedEvent: event.isAssignment
            ))
        }

        for submission in missingSubmissions {
            candidates.append(makeResult(
                id: "missing-\(submission.id)",
                kind: .missing,
                title: submission.name,
                subtitle: "Missing work",
                courseID: submission.courseID,
                courseName: submission.courseID.flatMap { courseNames[$0] },
                url: submission.htmlURL,
                fields: [submission.name, "missing", submission.pointsPossible.map { "\($0) points" }],
                query: normalizedQuery,
                queryTokens: queryTokens,
                referenceDate: referenceDate,
                urgencyDate: submission.dueAt,
                isOverdue: submission.isOverdue(referenceDate: referenceDate)
            ))
        }

        for (courseID, assignments) in assignmentsByCourseID {
            for assignment in assignments {
                candidates.append(makeResult(
                    id: "assignment-\(courseID)-\(assignment.id)",
                    kind: .assignment,
                    title: assignment.name,
                    subtitle: assignment.status.rawValue,
                    courseID: courseID,
                    courseName: courseNames[courseID],
                    url: assignment.canvasURL,
                    fields: [
                        assignment.name,
                        courseNames[courseID],
                        assignment.summaryText,
                        assignment.status.rawValue,
                        assignment.pointsDescription,
                        assignment.gradeDescription
                    ],
                    query: normalizedQuery,
                    queryTokens: queryTokens,
                    referenceDate: referenceDate,
                    urgencyDate: assignment.dueAt,
                    isOverdue: assignment.status == .missing || assignment.status == .late
                ))
            }
        }

        for (courseID, modules) in modulesByCourseID {
            for module in modules {
                candidates.append(makeResult(
                    id: "module-\(courseID)-\(module.id)",
                    kind: .module,
                    title: module.name,
                    subtitle: "Module",
                    courseID: courseID,
                    courseName: courseNames[courseID],
                    url: nil,
                    fields: [module.name, module.workflowState],
                    query: normalizedQuery,
                    queryTokens: queryTokens,
                    referenceDate: referenceDate
                ))

                for item in module.sortedItems {
                    candidates.append(makeResult(
                        id: "module-item-\(courseID)-\(item.id)",
                        kind: .moduleItem,
                        title: item.title,
                        subtitle: item.itemTypeLabel,
                        courseID: courseID,
                        courseName: courseNames[courseID],
                        url: item.actionableURL,
                        fields: [item.title, item.itemTypeLabel, item.pageURL, item.pointsDescription],
                        query: normalizedQuery,
                        queryTokens: queryTokens,
                        referenceDate: referenceDate
                    ))
                }
            }
        }

        for (courseID, folders) in foldersByCourseID {
            for folder in folders {
                candidates.append(makeResult(
                    id: "folder-\(courseID)-\(folder.id)",
                    kind: .folder,
                    title: folder.displayName,
                    subtitle: folder.itemCountDescription,
                    courseID: courseID,
                    courseName: courseNames[courseID],
                    url: nil,
                    fields: [folder.displayName, folder.fullName, folder.itemCountDescription],
                    query: normalizedQuery,
                    queryTokens: queryTokens,
                    referenceDate: referenceDate
                ))
            }
        }

        for files in filesByFolderID.values {
            for file in files {
                let courseID = file.folderID.flatMap { courseIDsByFolderID[$0] }
                candidates.append(makeResult(
                    id: "file-\(file.id)",
                    kind: .file,
                    title: file.name,
                    subtitle: file.contentType ?? file.sizeDescription,
                    courseID: courseID,
                    courseName: courseID.flatMap { courseNames[$0] },
                    url: file.actionableURL,
                    fields: [file.name, file.filename, file.contentType, file.sizeDescription],
                    query: normalizedQuery,
                    queryTokens: queryTokens,
                    referenceDate: referenceDate
                ))
            }
        }

        for (courseID, announcements) in announcementsByCourseID {
            for announcement in announcements {
                candidates.append(makeResult(
                    id: "announcement-\(courseID)-\(announcement.id)",
                    kind: .announcement,
                    title: announcement.title,
                    subtitle: announcement.isUnread ? "Unread announcement" : "Announcement",
                    courseID: courseID,
                    courseName: courseNames[courseID],
                    url: announcement.htmlURL,
                    fields: [announcement.title, announcement.summaryText, announcement.readState],
                    query: normalizedQuery,
                    queryTokens: queryTokens,
                    referenceDate: referenceDate,
                    isUnread: announcement.isUnread
                ))
            }
        }

        for (courseID, syllabus) in syllabusByCourseID {
            candidates.append(makeResult(
                id: "syllabus-\(courseID)",
                kind: .syllabus,
                title: syllabus.name,
                subtitle: "Syllabus",
                courseID: courseID,
                courseName: courseNames[courseID],
                url: syllabus.htmlURL,
                fields: [syllabus.name, syllabus.summaryText],
                query: normalizedQuery,
                queryTokens: queryTokens,
                referenceDate: referenceDate
            ))
        }

        for (courseID, people) in peopleByCourseID {
            for person in people {
                candidates.append(makeResult(
                    id: "person-\(courseID)-\(person.id)",
                    kind: .person,
                    title: person.displayName,
                    subtitle: person.roleLabel,
                    courseID: courseID,
                    courseName: courseNames[courseID],
                    url: person.htmlURL,
                    fields: [person.displayName, person.name, person.roleLabel, person.email, person.sectionLabel],
                    query: normalizedQuery,
                    queryTokens: queryTokens,
                    referenceDate: referenceDate
                ))
            }
        }

        for (key, detail) in moduleItemDetailsByKey {
            let courseID = CourseModuleItemDetailKey(rawValue: key).courseID
            let fields = detail.searchFields
            candidates.append(makeResult(
                id: "detail-\(key)",
                kind: .detail,
                title: detail.displayTitle,
                subtitle: detail.kindLabel,
                courseID: courseID,
                courseName: courseID.flatMap { courseNames[$0] },
                url: detail.htmlURL,
                fields: fields,
                query: normalizedQuery,
                queryTokens: queryTokens,
                referenceDate: referenceDate
            ))
        }

        return candidates
            .filter { $0.score > 0 }
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }

                if ($0.url != nil) != ($1.url != nil) {
                    return $0.url != nil
                }

                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private static func makeResult(
        id: String,
        kind: GlobalSearchResultKind,
        title: String,
        subtitle: String?,
        courseID: Int?,
        courseName: String?,
        url: URL?,
        fields: [String?],
        query: String,
        queryTokens: [String],
        referenceDate: Date,
        urgencyDate: Date? = nil,
        isOverdue: Bool = false,
        isUnread: Bool = false,
        isAssignmentBackedEvent: Bool = false
    ) -> GlobalSearchResult {
        let searchableText = fields.compactMap { $0 }.joined(separator: " ")
        let score = score(
            kind: kind,
            title: title,
            subtitle: subtitle,
            courseName: courseName,
            fields: fields,
            query: query,
            queryTokens: queryTokens,
            urgencyDate: urgencyDate,
            referenceDate: referenceDate,
            isOverdue: isOverdue,
            isUnread: isUnread,
            isAssignmentBackedEvent: isAssignmentBackedEvent,
            isActionable: url != nil
        )
        return GlobalSearchResult(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            courseID: courseID,
            courseName: courseName,
            url: url,
            searchableText: searchableText,
            score: score
        )
    }

    private static func score(
        kind: GlobalSearchResultKind,
        title: String,
        subtitle: String?,
        courseName: String?,
        fields: [String?],
        query: String,
        queryTokens: [String],
        urgencyDate: Date?,
        referenceDate: Date,
        isOverdue: Bool,
        isUnread: Bool,
        isAssignmentBackedEvent: Bool,
        isActionable: Bool
    ) -> Int {
        let normalizedTitle = normalize(title)
        let normalizedSubtitle = normalize(subtitle ?? "")
        let normalizedCourseName = normalize(courseName ?? "")
        let metadata = normalize(fields.compactMap { $0 }.joined(separator: " "))
        let titleTokens = tokens(from: normalizedTitle)

        var score = 0

        if normalizedTitle == query {
            score += 160
        } else if normalizedTitle.hasPrefix(query) {
            score += 120
        } else if titleTokens.contains(where: { $0.hasPrefix(query) }) {
            score += 96
        } else if normalizedTitle.contains(query) {
            score += 80
        }

        if !normalizedSubtitle.isEmpty {
            if normalizedSubtitle == query {
                score += 48
            } else if normalizedSubtitle.hasPrefix(query) {
                score += 34
            } else if normalizedSubtitle.contains(query) {
                score += 22
            }
        }

        if !normalizedCourseName.isEmpty {
            if normalizedCourseName == query {
                score += 44
            } else if normalizedCourseName.hasPrefix(query) {
                score += 28
            } else if normalizedCourseName.contains(query) {
                score += 18
            }
        }

        let metadataTokens = tokens(from: metadata)
        for token in queryTokens where !token.isEmpty {
            if metadataTokens.contains(where: { $0.hasPrefix(token) }) {
                score += 12
            } else if metadata.contains(token) {
                score += 8
            }
        }

        if score == 0 && metadata.contains(query) {
            score += 20
        }

        if score == 0 {
            return 0
        }

        score += kindBonus(kind)

        if isActionable {
            score += 6
        }

        if isAssignmentBackedEvent {
            score += 10
        }

        if isUnread {
            score += 6
        }

        if isOverdue {
            score += 26
        }

        score += urgencyBonus(for: urgencyDate, referenceDate: referenceDate, kind: kind)
        return score
    }

    private static func kindBonus(_ kind: GlobalSearchResultKind) -> Int {
        switch kind {
        case .missing:
            return 26
        case .assignment:
            return 20
        case .event:
            return 18
        case .detail:
            return 14
        case .file:
            return 12
        case .announcement:
            return 10
        case .person:
            return 8
        case .course:
            return 8
        case .moduleItem:
            return 4
        case .syllabus:
            return 4
        case .module:
            return 2
        case .folder:
            return 0
        }
    }

    private static func urgencyBonus(for date: Date?, referenceDate: Date, kind: GlobalSearchResultKind) -> Int {
        guard let date else {
            return 0
        }

        let delta = date.timeIntervalSince(referenceDate)
        let day: TimeInterval = 24 * 60 * 60

        if delta < 0 {
            switch kind {
            case .missing, .assignment:
                return 18
            case .event:
                return 4
            default:
                return 0
            }
        }

        if delta <= day {
            return 16
        }

        if delta <= 3 * day {
            return 10
        }

        if delta <= 7 * day {
            return 6
        }

        return 0
    }

    private static func tokens(from value: String) -> [String] {
        normalize(value)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private extension CourseModuleItemDetail {
    var displayTitle: String {
        switch self {
        case .quiz(let detail):
            return detail.displayTitle
        case .discussion(let detail):
            return detail.displayTitle
        case .page(let detail):
            return detail.displayTitle
        }
    }

    var kindLabel: String {
        switch self {
        case .quiz:
            return "Quiz Detail"
        case .discussion:
            return "Discussion Detail"
        case .page:
            return "Page Detail"
        }
    }

    var htmlURL: URL? {
        switch self {
        case .quiz(let detail):
            return detail.htmlURL
        case .discussion(let detail):
            return detail.htmlURL
        case .page(let detail):
            return detail.htmlURL
        }
    }

    var searchFields: [String?] {
        switch self {
        case .quiz(let detail):
            return [detail.title, detail.summaryText, detail.quizType]
        case .discussion(let detail):
            return [detail.title, detail.summaryText, detail.authorName]
        case .page(let detail):
            return [detail.title, detail.summaryText]
        }
    }
}
