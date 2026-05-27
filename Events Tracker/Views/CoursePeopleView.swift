//
//  CoursePeopleView.swift
//  Events Tracker
//

import SwiftUI

private enum CoursePeopleFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case teachers = "Teachers"
    case tas = "TAs"
    case students = "Students"
    case others = "Other"

    var id: String { rawValue }

    func includes(_ entry: PersonEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .teachers:
            return entry.primaryRole == .teacher
        case .tas:
            return entry.primaryRole == .ta
        case .students:
            return entry.primaryRole == .student
        case .others:
            return ![.teacher, .ta, .student].contains(entry.primaryRole)
        }
    }
}

private enum CoursePeopleSort: String, CaseIterable, Identifiable {
    case role = "Role"
    case name = "Name"
    case activity = "Recent Activity"

    var id: String { rawValue }
}

// Lightweight wrapper that caches the expensive `primaryRole` lookup so it is
// computed at most once per person per body invocation. `CoursePerson.primaryRole`
// allocates several strings and runs multiple `.contains()` checks, which becomes
// catastrophic when invoked across counting, filtering, sorting comparisons, and
// row rendering for large rosters.
fileprivate struct PersonEntry: Identifiable {
    let person: CoursePerson
    let primaryRole: CoursePersonRole
    let roleLabel: String
    let sectionLabel: String?
    let lastActivityAt: Date?

    init(person: CoursePerson) {
        self.person = person
        let primaryRole = person.primaryRole
        self.primaryRole = primaryRole
        self.roleLabel = primaryRole.label
        self.sectionLabel = person.sectionLabel
        self.lastActivityAt = person.lastActivityAt
    }

    var id: Int { person.id }

    func matchesSearch(_ normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return [
            person.name,
            person.sortableName,
            person.shortName,
            person.email,
            person.loginID,
            sectionLabel,
            roleLabel
        ].contains { value in
            value?.normalizedPeopleSearchText.contains(normalizedQuery) == true
        }
    }
}

struct CoursePeopleContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let people: [CoursePerson]
    let isLoading: Bool
    let hasLoaded: Bool

    @State private var searchQuery = ""
    @State private var filter: CoursePeopleFilter = .all
    @State private var sort: CoursePeopleSort = .role
    @State private var selectedPerson: CoursePerson?

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        let preparedPeople = people.map { person in
            PersonEntry(person: person)
        }
        let normalizedSearchQuery = searchQuery.normalizedPeopleSearchText
        let teacherAndTACount = preparedPeople.reduce(into: 0) { count, entry in
            if entry.primaryRole == .teacher || entry.primaryRole == .ta {
                count += 1
            }
        }
        let studentCount = preparedPeople.reduce(into: 0) { count, entry in
            if entry.primaryRole == .student {
                count += 1
            }
        }
        let otherCount = preparedPeople.count - teacherAndTACount - studentCount
        let visiblePeople = filteredAndSortedPeople(from: preparedPeople, normalizedSearchQuery: normalizedSearchQuery)

        HStack {
            Text("People")
                .font(.title2.weight(.semibold))

            Spacer()

            Button("Refresh People") {
                Task {
                    await store.loadPeople(for: course.id)
                }
            }
            .disabled(isLoading)
        }

        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryCard(
                title: "Total",
                value: "\(people.count)",
                detail: "Visible members Canvas returned.",
                systemImage: "person.3",
                tint: .blue
            )

            SummaryCard(
                title: "Teaching Team",
                value: "\(teacherAndTACount)",
                detail: "Teachers and TAs for this course.",
                systemImage: "person.badge.key",
                tint: .purple
            )

            SummaryCard(
                title: "Students",
                value: "\(studentCount)",
                detail: "Student enrollments visible to you.",
                systemImage: "graduationcap",
                tint: .green
            )

            SummaryCard(
                title: "Other",
                value: "\(otherCount)",
                detail: "Observers, designers, and other roles.",
                systemImage: "person.crop.circle.badge.questionmark",
                tint: .orange
            )
        }

        HStack(spacing: 12) {
            TextField("Search people, roles, sections, or emails", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            Picker("Filter", selection: $filter) {
                ForEach(CoursePeopleFilter.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Picker("Sort", selection: $sort) {
                ForEach(CoursePeopleSort.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Spacer()

            Text("\(visiblePeople.count) of \(people.count) shown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Group {
            if isLoading && people.isEmpty {
                ProgressView("Loading people...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else if people.isEmpty {
                SetupPromptView(
                    title: hasLoaded ? "No People Visible" : "People Not Loaded",
                    message: hasLoaded
                        ? "Canvas did not return a visible roster for this course. Some schools restrict People access."
                        : "Open or refresh this tab to load the course roster from Canvas."
                )
            } else if visiblePeople.isEmpty {
                SetupPromptView(
                    title: "No Matching People",
                    message: "Change the search, role filter, or sort controls to review more members."
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visiblePeople) { entry in
                        CoursePersonRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPerson = entry.person
                            }

                        if entry.id != visiblePeople.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedPerson) { person in
            CoursePersonDetailView(person: person, courseName: course.name)
        }
        .onAppear {
            let preference = store.coursePreference(for: course.id).people
            searchQuery = preference.searchQuery
            filter = CoursePeopleFilter(rawValue: preference.filter) ?? .all
            sort = CoursePeopleSort(rawValue: preference.sort) ?? .role
        }
        .onChange(of: searchQuery) { _, _ in persistPreference() }
        .onChange(of: filter) { _, _ in persistPreference() }
        .onChange(of: sort) { _, _ in persistPreference() }
    }

    private func filteredAndSortedPeople(from prepared: [PersonEntry], normalizedSearchQuery: String) -> [PersonEntry] {
        let roleFiltered = prepared.filter { filter.includes($0) }
        let filtered = normalizedSearchQuery.isEmpty
            ? roleFiltered
            : roleFiltered.filter { $0.matchesSearch(normalizedSearchQuery) }

        switch sort {
        case .role:
            return filtered.sorted(by: sortByRole)
        case .name:
            return filtered.sorted(by: sortByName)
        case .activity:
            return filtered.sorted(by: sortByActivity)
        }
    }

    private func sortByRole(_ lhs: PersonEntry, _ rhs: PersonEntry) -> Bool {
        let leftPriority = lhs.primaryRole.sortPriority
        let rightPriority = rhs.primaryRole.sortPriority
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        return sortByName(lhs, rhs)
    }

    private func sortByName(_ lhs: PersonEntry, _ rhs: PersonEntry) -> Bool {
        let left = lhs.person.sortableName ?? lhs.person.name
        let right = rhs.person.sortableName ?? rhs.person.name
        return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
    }

    private func sortByActivity(_ lhs: PersonEntry, _ rhs: PersonEntry) -> Bool {
        switch (lhs.lastActivityAt, rhs.lastActivityAt) {
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

        return sortByRole(lhs, rhs)
    }

    private func persistPreference() {
        store.updateCoursePreference(courseID: course.id) { preference in
            preference.people = CourseWorkspacePreference(
                searchQuery: searchQuery,
                filter: filter.rawValue,
                sort: sort.rawValue
            )
        }
    }
}

private struct CoursePersonRow: View {
    let entry: PersonEntry

    private var person: CoursePerson { entry.person }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoursePersonAvatar(person: person)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(person.displayName)
                        .font(.headline)

                    PillBadge(text: entry.roleLabel, tint: tint)

                    if let state = person.primaryEnrollment?.enrollmentState, !state.isEmpty {
                        PillBadge(text: state.capitalized, tint: .secondary)
                    }
                }

                HStack(spacing: 12) {
                    if let section = entry.sectionLabel, !section.isEmpty {
                        Label(section, systemImage: "rectangle.3.group")
                    }

                    if let email = person.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                    }

                    if let lastActivity = entry.lastActivityAt {
                        Label(
                            DisplayFormatters.relativeString(date: lastActivity)
                                ?? DisplayFormatters.formatted(date: lastActivity),
                            systemImage: "clock"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let htmlURL = person.htmlURL {
                Link("Open in Canvas", destination: htmlURL)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 12)
    }

    private var tint: Color {
        switch entry.primaryRole {
        case .teacher:
            return .purple
        case .ta:
            return .indigo
        case .student:
            return .green
        case .observer, .designer, .other:
            return .orange
        }
    }
}

private extension String {
    var normalizedPeopleSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private struct CoursePersonAvatar: View {
    let person: CoursePerson

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.14))

            if let avatarURL = person.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Text(person.initials)
                        .font(.caption.weight(.bold))
                }
                .clipShape(Circle())
            } else {
                Text(person.initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 40, height: 40)
    }
}

private struct CoursePersonDetailView: View {
    let person: CoursePerson
    let courseName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    CoursePersonAvatar(person: person)
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(person.displayName)
                            .font(.largeTitle.weight(.semibold))

                        Text(courseName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    CoursePersonDetailMetric(title: "Role", value: person.roleLabel, systemImage: "person.text.rectangle")
                    CoursePersonDetailMetric(title: "Section", value: person.sectionLabel ?? "Not provided", systemImage: "rectangle.3.group")
                    CoursePersonDetailMetric(title: "Email", value: person.email ?? "Not provided", systemImage: "envelope")
                    CoursePersonDetailMetric(
                        title: "Last Activity",
                        value: DisplayFormatters.relativeString(date: person.lastActivityAt)
                            ?? DisplayFormatters.formatted(date: person.lastActivityAt),
                        systemImage: "clock"
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Canvas Context")
                        .font(.title2.weight(.semibold))

                    CoursePersonInfoRow(title: "Full Name", value: person.name)
                    CoursePersonInfoRow(title: "Sortable Name", value: person.sortableName ?? "Not provided")
                    CoursePersonInfoRow(title: "Login ID", value: person.loginID ?? "Not provided")
                    CoursePersonInfoRow(title: "Enrollment State", value: person.primaryEnrollment?.enrollmentState ?? "Not provided")
                }

                if let htmlURL = person.htmlURL {
                    Link("Open in Canvas", destination: htmlURL)
                        .font(.headline)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

private struct CoursePersonDetailMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 14)
    }
}

private struct CoursePersonInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .textSelection(.enabled)

            Spacer()
        }
    }
}
