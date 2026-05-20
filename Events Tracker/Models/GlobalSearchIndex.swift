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
                query: normalizedQuery
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
                query: normalizedQuery
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
                query: normalizedQuery
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
                    url: assignment.htmlURL,
                    fields: [
                        assignment.name,
                        courseNames[courseID],
                        assignment.summaryText,
                        assignment.status.rawValue,
                        assignment.pointsDescription,
                        assignment.gradeDescription
                    ],
                    query: normalizedQuery
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
                    query: normalizedQuery
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
                        query: normalizedQuery
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
                    query: normalizedQuery
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
                    query: normalizedQuery
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
                    query: normalizedQuery
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
                query: normalizedQuery
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
                    query: normalizedQuery
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
                query: normalizedQuery
            ))
        }

        return candidates
            .filter { $0.score > 0 }
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }

                if $0.kind.rawValue != $1.kind.rawValue {
                    return $0.kind.rawValue < $1.kind.rawValue
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
        query: String
    ) -> GlobalSearchResult {
        let searchableText = fields.compactMap { $0 }.joined(separator: " ")
        let score = score(title: title, fields: fields, query: query)
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

    private static func score(title: String, fields: [String?], query: String) -> Int {
        let normalizedTitle = normalize(title)

        if normalizedTitle == query {
            return 100
        }

        if normalizedTitle.hasPrefix(query) {
            return 80
        }

        if normalizedTitle.contains(query) {
            return 60
        }

        let metadata = normalize(fields.compactMap { $0 }.joined(separator: " "))
        return metadata.contains(query) ? 30 : 0
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
