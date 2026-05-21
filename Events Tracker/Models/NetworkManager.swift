//
//  NetworkManager.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

enum CanvasServiceError: LocalizedError {
    case incompleteConfiguration
    case invalidBaseURL
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .incompleteConfiguration:
            return "Add your Canvas base URL and access token in Settings before syncing."
        case .invalidBaseURL:
            return "The Canvas base URL is invalid. Use your school's Canvas domain, for example https://school.instructure.com."
        case .invalidResponse:
            return "Canvas returned an invalid response."
        case .requestFailed(let statusCode, let message):
            if statusCode == 401 {
                return "Canvas rejected the access token. Generate a fresh token and try again."
            }

            return "Canvas request failed (\(statusCode)): \(message)"
        case .decodingFailed:
            return "Canvas returned data in an unexpected format."
        }
    }
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeCanvasDate(from: decoder)
        }
    }

    func fetchDashboardSnapshot(using config: CanvasConfig) async throws -> CanvasSnapshot {
        guard config.isComplete else {
            throw CanvasServiceError.incompleteConfiguration
        }

        async let coursesTask = fetchCourses(using: config)
        async let upcomingEventsTask = fetchUpcomingEvents(using: config)
        async let missingSubmissionsTask = fetchMissingSubmissions(using: config)
        async let profileTask = fetchProfile(using: config)

        let courses = try await coursesTask
        let upcomingEvents = try await upcomingEventsTask
        let missingSubmissions = try await missingSubmissionsTask
        let profile = try? await profileTask

        return CanvasSnapshot(
            courses: courses,
            upcomingEvents: upcomingEvents,
            missingSubmissions: missingSubmissions,
            profile: profile,
            syncedAt: Date()
        )
    }

    func fetchCourses(using config: CanvasConfig) async throws -> [Course] {
        let queryItems = [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "include[]", value: "term"),
            URLQueryItem(name: "include[]", value: "total_scores"),
            URLQueryItem(name: "include[]", value: "current_grading_period_scores"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        let courses: [Course] = try await requestPaginatedArray(
            path: "/api/v1/courses",
            queryItems: queryItems,
            config: config
        )

        return courses.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func fetchAssignments(courseID: Int, using config: CanvasConfig) async throws -> [CourseAssignment] {
        let queryItems = [
            URLQueryItem(name: "include[]", value: "submission"),
            URLQueryItem(name: "order_by", value: "due_at"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        let assignments: [CourseAssignment] = try await requestPaginatedArray(
            path: "/api/v1/courses/\(courseID)/assignments",
            queryItems: queryItems,
            config: config
        )

        return assignments.sorted(by: Self.sortAssignments)
    }

    func fetchModules(courseID: Int, using config: CanvasConfig) async throws -> [CourseModule] {
        let queryItems = [
            URLQueryItem(name: "include[]", value: "items"),
            URLQueryItem(name: "include[]", value: "content_details"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        var modules: [CourseModule] = try await requestPaginatedArray(
            path: "/api/v1/courses/\(courseID)/modules",
            queryItems: queryItems,
            config: config
        )

        for index in modules.indices where modules[index].items == nil {
            let items: [CourseModuleItem] = try await requestPaginatedArray(
                path: "/api/v1/courses/\(courseID)/modules/\(modules[index].id)/items",
                queryItems: [
                    URLQueryItem(name: "include[]", value: "content_details"),
                    URLQueryItem(name: "per_page", value: "100")
                ],
                config: config
            )

            modules[index] = modules[index].withItems(items)
        }

        return modules.sorted(by: Self.sortModules)
    }

    func fetchFolders(courseID: Int, using config: CanvasConfig) async throws -> [CanvasFolder] {
        let folders: [CanvasFolder] = try await requestPaginatedArray(
            path: "/api/v1/courses/\(courseID)/folders",
            queryItems: [
                URLQueryItem(name: "per_page", value: "100")
            ],
            config: config
        )

        return folders.sorted(by: Self.sortFolders)
    }

    func fetchFiles(folderID: Int, using config: CanvasConfig) async throws -> [CanvasFile] {
        let files: [CanvasFile] = try await requestPaginatedArray(
            path: "/api/v1/folders/\(folderID)/files",
            queryItems: [
                URLQueryItem(name: "per_page", value: "100")
            ],
            config: config
        )

        return files.sorted(by: Self.sortFiles)
    }

    func fetchAnnouncements(courseID: Int, using config: CanvasConfig) async throws -> [CourseAnnouncement] {
        let announcements: [CourseAnnouncement] = try await requestPaginatedArray(
            path: "/api/v1/announcements",
            queryItems: [
                URLQueryItem(name: "context_codes[]", value: "course_\(courseID)"),
                URLQueryItem(name: "per_page", value: "100")
            ],
            config: config
        )

        return announcements.sorted(by: Self.sortAnnouncements)
    }

    func fetchSyllabus(courseID: Int, using config: CanvasConfig) async throws -> CourseSyllabus {
        try await request(
            path: "/api/v1/courses/\(courseID)",
            queryItems: [
                URLQueryItem(name: "include[]", value: "syllabus_body")
            ],
            config: config,
            responseType: CourseSyllabus.self
        )
    }

    func fetchPeople(courseID: Int, using config: CanvasConfig) async throws -> [CoursePerson] {
        let people: [CoursePerson] = try await requestPaginatedArray(
            path: "/api/v1/courses/\(courseID)/users",
            queryItems: [
                URLQueryItem(name: "include[]", value: "enrollments"),
                URLQueryItem(name: "include[]", value: "avatar_url"),
                URLQueryItem(name: "per_page", value: "100")
            ],
            config: config
        )

        return people.sorted {
            if $0.primaryRole.sortPriority != $1.primaryRole.sortPriority {
                return $0.primaryRole.sortPriority < $1.primaryRole.sortPriority
            }

            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func fetchConversations(
        scope: CanvasConversationWorkflowState? = nil,
        filterCourseID: Int? = nil,
        using config: CanvasConfig
    ) async throws -> [CanvasConversation] {
        var queryItems = [
            URLQueryItem(name: "include[]", value: "participant_avatars"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        if let scope, scope != .read {
            queryItems.append(URLQueryItem(name: "scope", value: scope.rawValue))
        }

        if let filterCourseID {
            queryItems.append(URLQueryItem(name: "filter[]", value: "course_\(filterCourseID)"))
        }

        let conversations: [CanvasConversation] = try await requestPaginatedArray(
            path: "/api/v1/conversations",
            queryItems: queryItems,
            config: config
        )

        return conversations.sorted(by: Self.sortConversations)
    }

    func updateConversationWorkflowState(
        conversationID: Int,
        state: CanvasConversationWorkflowState,
        using config: CanvasConfig
    ) async throws -> CanvasConversation {
        try await requestFormEncoded(
            path: "/api/v1/conversations/\(conversationID)",
            queryItems: [],
            formItems: [
                URLQueryItem(name: "conversation[workflow_state]", value: state.rawValue)
            ],
            method: "PUT",
            config: config,
            responseType: CanvasConversation.self
        )
    }

    func fetchQuizDetail(courseID: Int, quizID: Int, using config: CanvasConfig) async throws -> CourseQuizDetail {
        try await request(
            path: "/api/v1/courses/\(courseID)/quizzes/\(quizID)",
            queryItems: [],
            config: config,
            responseType: CourseQuizDetail.self
        )
    }

    func fetchDiscussionDetail(
        courseID: Int,
        discussionID: Int,
        using config: CanvasConfig
    ) async throws -> CourseDiscussionDetail {
        try await request(
            path: "/api/v1/courses/\(courseID)/discussion_topics/\(discussionID)",
            queryItems: [],
            config: config,
            responseType: CourseDiscussionDetail.self
        )
    }

    func fetchPageDetail(courseID: Int, pageURL: String, using config: CanvasConfig) async throws -> CoursePageDetail {
        let encodedPageURL = pageURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pageURL

        return try await request(
            path: "/api/v1/courses/\(courseID)/pages/\(encodedPageURL)",
            queryItems: [],
            config: config,
            responseType: CoursePageDetail.self
        )
    }

    func fetchUpcomingEvents(using config: CanvasConfig) async throws -> [UpcomingEvent] {
        let queryItems = [
            URLQueryItem(name: "per_page", value: "100")
        ]

        let events: [UpcomingEvent] = try await requestPaginatedArray(
            path: "/api/v1/users/self/upcoming_events",
            queryItems: queryItems,
            config: config
        )

        let now = Date()
        let lookaheadEndDate = Calendar.current.date(byAdding: .day, value: config.lookaheadDays, to: now)

        return events
            .filter { event in
                guard let displayDate = event.displayDate else {
                    return true
                }

                guard let lookaheadEndDate else {
                    return true
                }

                return displayDate <= lookaheadEndDate
            }
            .sorted(by: Self.sortUpcomingEvents)
    }

    func fetchMissingSubmissions(using config: CanvasConfig) async throws -> [MissingSubmission] {
        let queryItems = [
            URLQueryItem(name: "filter[]", value: "submittable"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        let submissions: [MissingSubmission] = try await requestPaginatedArray(
            path: "/api/v1/users/self/missing_submissions",
            queryItems: queryItems,
            config: config
        )

        return submissions.sorted(by: Self.sortMissingSubmissions)
    }

    func fetchProfile(using config: CanvasConfig) async throws -> UserProfile {
        try await request(
            path: "/api/v1/users/self/profile",
            queryItems: [],
            config: config,
            responseType: UserProfile.self
        )
    }

    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        config: CanvasConfig,
        responseType: T.Type
    ) async throws -> T {
        let url = try makeURL(path: path, queryItems: queryItems, config: config)
        let (data, response) = try await session.data(for: authorizedRequest(url: url, token: config.trimmedToken))
        try validate(response: response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CanvasServiceError.decodingFailed
        }
    }

    private func requestFormEncoded<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        formItems: [URLQueryItem],
        method: String,
        config: CanvasConfig,
        responseType: T.Type
    ) async throws -> T {
        let url = try makeURL(path: path, queryItems: queryItems, config: config)
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = formItems
        let body = Data((bodyComponents.percentEncodedQuery ?? "").utf8)
        let request = authorizedRequest(
            url: url,
            token: config.trimmedToken,
            method: method,
            body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CanvasServiceError.decodingFailed
        }
    }

    private func requestPaginatedArray<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        config: CanvasConfig
    ) async throws -> [T] {
        var url = try makeURL(path: path, queryItems: queryItems, config: config)
        var combinedResults: [T] = []

        while true {
            let (data, response) = try await session.data(for: authorizedRequest(url: url, token: config.trimmedToken))
            try validate(response: response, data: data)

            do {
                combinedResults += try decoder.decode([T].self, from: data)
            } catch {
                throw CanvasServiceError.decodingFailed
            }

            guard
                let httpResponse = response as? HTTPURLResponse,
                let nextPageURL = nextPageURL(from: httpResponse.value(forHTTPHeaderField: "Link"))
            else {
                break
            }

            url = nextPageURL
        }

        return combinedResults
    }

    private func makeURL(path: String, queryItems: [URLQueryItem], config: CanvasConfig) throws -> URL {
        guard var components = URLComponents(string: config.normalizedBaseURL) else {
            throw CanvasServiceError.invalidBaseURL
        }

        var basePath = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        if basePath.hasSuffix("/api/v1") {
            basePath = String(basePath.dropLast("/api/v1".count))
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath + normalizedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw CanvasServiceError.invalidBaseURL
        }

        return url
    }

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func authorizedRequest(
        url: URL,
        token: String,
        method: String,
        body: Data,
        contentType: String
    ) -> URLRequest {
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CanvasServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw CanvasServiceError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: message.isEmpty ? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode) : message
            )
        }
    }

    private func nextPageURL(from linkHeader: String?) -> URL? {
        guard let linkHeader else {
            return nil
        }

        let parts = linkHeader.split(separator: ",")

        for part in parts {
            let segments = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard
                let urlSegment = segments.first,
                segments.contains(where: { $0.contains("rel=\"next\"") })
            else {
                continue
            }

            let trimmedURL = urlSegment
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")

            if let url = URL(string: trimmedURL) {
                return url
            }
        }

        return nil
    }

    private static func sortUpcomingEvents(_ lhs: UpcomingEvent, _ rhs: UpcomingEvent) -> Bool {
        switch (lhs.displayDate, rhs.displayDate) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func sortConversations(_ lhs: CanvasConversation, _ rhs: CanvasConversation) -> Bool {
        switch (lhs.lastMessageAt, rhs.lastMessageAt) {
        case let (left?, right?):
            if left != right {
                return left > right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.displaySubject.localizedCaseInsensitiveCompare(rhs.displaySubject) == .orderedAscending
    }

    private static func sortMissingSubmissions(_ lhs: MissingSubmission, _ rhs: MissingSubmission) -> Bool {
        switch (lhs.dueAt, rhs.dueAt) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func sortModules(_ lhs: CourseModule, _ rhs: CourseModule) -> Bool {
        switch (lhs.position, rhs.position) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func sortFolders(_ lhs: CanvasFolder, _ rhs: CanvasFolder) -> Bool {
        if lhs.sortName != rhs.sortName {
            return lhs.sortName.localizedCaseInsensitiveCompare(rhs.sortName) == .orderedAscending
        }

        return lhs.id < rhs.id
    }

    private static func sortFiles(_ lhs: CanvasFile, _ rhs: CanvasFile) -> Bool {
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.id < rhs.id
    }

    private static func sortAnnouncements(_ lhs: CourseAnnouncement, _ rhs: CourseAnnouncement) -> Bool {
        switch (lhs.displayDate, rhs.displayDate) {
        case let (left?, right?):
            if left != right {
                return left > right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func sortAssignments(_ lhs: CourseAssignment, _ rhs: CourseAssignment) -> Bool {
        switch (lhs.dueAt, rhs.dueAt) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func decodeCanvasDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = fractionalSecondDateFormatter.date(from: value) ?? internetDateFormatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Canvas date: \(value)")
    }

    private static let fractionalSecondDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
