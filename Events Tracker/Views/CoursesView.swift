//
//  CoursesView.swift
//  Events Tracker
//
//  Created by Codex on 13/4/26.
//

import SwiftUI

private enum CourseWorkspaceSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case modules = "Modules"
    case announcements = "Announcements"
    case syllabus = "Syllabus"
    case people = "People"
    case files = "Files"
    case assignments = "Assignments"
    case grades = "Grades"

    var id: String { rawValue }
}

private enum CourseAssignmentFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case upcoming = "Upcoming"
    case missing = "Missing"
    case completed = "Completed"

    var id: String { rawValue }

    func includes(_ assignment: CourseAssignment) -> Bool {
        switch self {
        case .all:
            return true
        case .upcoming:
            return assignment.isUpcoming
        case .missing:
            return assignment.status == .missing || assignment.status == .late
        case .completed:
            return assignment.isCompleted
        }
    }
}

private enum CourseModuleFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pages = "Pages"
    case assignments = "Assignments"
    case files = "Files"
    case quizzes = "Quizzes"
    case locked = "Locked"

    var id: String { rawValue }

    func includes(_ module: CourseModule) -> Bool {
        switch self {
        case .all:
            return true
        case .pages:
            return module.sortedItems.contains { $0.type == "Page" }
        case .assignments:
            return module.sortedItems.contains { $0.type == "Assignment" }
        case .files:
            return module.sortedItems.contains { $0.type == "File" }
        case .quizzes:
            return module.sortedItems.contains { $0.type == "Quiz" }
        case .locked:
            return module.sortedItems.contains { $0.isLockedForUser }
        }
    }
}

private enum CourseModuleSort: String, CaseIterable, Identifiable {
    case canvasOrder = "Canvas Order"
    case name = "Name"
    case itemCount = "Item Count"

    var id: String { rawValue }
}

private enum CourseFileFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case available = "Available"
    case restricted = "Restricted"

    var id: String { rawValue }

    func includes(_ file: CanvasFile) -> Bool {
        switch self {
        case .all:
            return true
        case .available:
            return !file.isUnavailable
        case .restricted:
            return file.isUnavailable
        }
    }
}

private enum CourseFileSort: String, CaseIterable, Identifiable {
    case canvasOrder = "Canvas Order"
    case name = "Name"
    case updated = "Updated"
    case size = "Size"

    var id: String { rawValue }
}

private enum CourseAssignmentSort: String, CaseIterable, Identifiable {
    case dueDate = "Due Date"
    case name = "Name"
    case status = "Status"
    case points = "Points"

    var id: String { rawValue }
}

private enum CourseGradeSort: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case name = "Name"
    case score = "Score"

    var id: String { rawValue }
}

private enum CourseAnnouncementFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unread = "Unread"
    case locked = "Locked"

    var id: String { rawValue }

    func includes(_ announcement: CourseAnnouncement) -> Bool {
        switch self {
        case .all:
            return true
        case .unread:
            return announcement.isUnread
        case .locked:
            return announcement.lockedForUser == true
        }
    }
}

private enum CourseAnnouncementSort: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case title = "Title"

    var id: String { rawValue }
}

struct CoursesView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var selectedSection: CourseWorkspaceSection = .overview
    @State private var moduleSearchQuery = ""
    @State private var moduleFilter: CourseModuleFilter = .all
    @State private var moduleSort: CourseModuleSort = .canvasOrder
    @State private var fileSearchQuery = ""
    @State private var fileFilter: CourseFileFilter = .all
    @State private var fileSort: CourseFileSort = .canvasOrder
    @State private var assignmentSearchQuery = ""
    @State private var assignmentFilter: CourseAssignmentFilter = .all
    @State private var assignmentSort: CourseAssignmentSort = .dueDate
    @State private var gradeSearchQuery = ""
    @State private var gradeSort: CourseGradeSort = .recent
    @State private var announcementSearchQuery = ""
    @State private var announcementFilter: CourseAnnouncementFilter = .all
    @State private var announcementSort: CourseAnnouncementSort = .recent
    @State private var selectedModuleDetailItem: CourseModuleItem?
    @State private var showingHiddenCourses = false

    private var selectedCourseBinding: Binding<Int?> {
        Binding(
            get: { store.selectedCourseID },
            set: { store.selectedCourseID = $0 }
        )
    }

    private var selectedCourseModules: [CourseModule] {
        store.modules(for: store.selectedCourseID)
    }

    private var selectedCourseAssignments: [CourseAssignment] {
        store.assignments(for: store.selectedCourseID)
    }

    private var selectedCourseFolders: [CanvasFolder] {
        store.folders(for: store.selectedCourseID)
    }

    private var selectedCourseAnnouncements: [CourseAnnouncement] {
        store.announcements(for: store.selectedCourseID)
    }

    private var selectedCourseSyllabus: CourseSyllabus? {
        store.syllabus(for: store.selectedCourseID)
    }

    private var selectedCoursePeople: [CoursePerson] {
        store.people(for: store.selectedCourseID)
    }

    private var isLoadingSelectedCourseModules: Bool {
        store.isLoadingModules(for: store.selectedCourseID)
    }

    private var isLoadingSelectedCourseAssignments: Bool {
        store.isLoadingAssignments(for: store.selectedCourseID)
    }

    private var isLoadingSelectedCourseFolders: Bool {
        store.isLoadingFolders(for: store.selectedCourseID)
    }

    private var isLoadingSelectedCourseAnnouncements: Bool {
        store.isLoadingAnnouncements(for: store.selectedCourseID)
    }

    private var isLoadingSelectedCourseSyllabus: Bool {
        store.isLoadingSyllabus(for: store.selectedCourseID)
    }

    private var isLoadingSelectedCoursePeople: Bool {
        store.isLoadingPeople(for: store.selectedCourseID)
    }

    private var hasLoadedSelectedCourseModules: Bool {
        store.hasLoadedModules(for: store.selectedCourseID)
    }

    private var hasLoadedSelectedCourseAssignments: Bool {
        store.hasLoadedAssignments(for: store.selectedCourseID)
    }

    private var hasLoadedSelectedCourseFolders: Bool {
        store.hasLoadedFolders(for: store.selectedCourseID)
    }

    private var hasLoadedSelectedCourseAnnouncements: Bool {
        store.hasLoadedAnnouncements(for: store.selectedCourseID)
    }

    private var hasLoadedSelectedCourseSyllabus: Bool {
        store.hasLoadedSyllabus(for: store.selectedCourseID)
    }

    private var hasLoadedSelectedCoursePeople: Bool {
        store.hasLoadedPeople(for: store.selectedCourseID)
    }

    private var selectedCourseUpcomingItems: [UpcomingEvent] {
        store.filteredUpcomingEvents(courseID: store.selectedCourseID)
    }

    private var selectedCourseMissingItems: [MissingSubmission] {
        store.filteredMissingSubmissions(courseID: store.selectedCourseID)
    }

    var body: some View {
        if !store.isConfigured {
            SetupPromptView(
                title: "Connect Canvas",
                message: "Save your Canvas credentials in Settings to open course workspaces and modules."
            )
        } else if store.courses.isEmpty {
            SetupPromptView(
                title: "No Courses Loaded",
                message: "Sync once to load the active courses available in your Canvas account."
            )
        } else {
            HStack(spacing: 0) {
                List(selection: selectedCourseBinding) {
                    Toggle("Show Hidden", isOn: $showingHiddenCourses)

                    ForEach(store.preferredCourses(showingHidden: showingHiddenCourses)) { course in
                        CourseListRow(course: course)
                            .tag(Optional(course.id))
                    }
                }
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)

                Divider()

                if let selectedCourse = store.selectedCourse {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(selectedCourse.name)
                                        .font(.largeTitle.weight(.semibold))

                                    HStack(spacing: 12) {
                                        if let courseCode = selectedCourse.courseCode, !courseCode.isEmpty {
                                            Label(courseCode, systemImage: "number.square")
                                                .foregroundStyle(.secondary)
                                        }

                                        if let termName = selectedCourse.enrollmentTerm?.name, !termName.isEmpty {
                                            Label(termName, systemImage: "calendar")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.subheadline)
                                }

                                Spacer()

                                Menu("Course Preferences") {
                                    Button(store.coursePreferences.pinnedCourseIDs.contains(selectedCourse.id) ? "Unpin Course" : "Pin Course") {
                                        store.togglePinnedCourse(selectedCourse.id)
                                    }

                                    Button(store.coursePreferences.hiddenCourseIDs.contains(selectedCourse.id) ? "Unhide Course" : "Hide Course") {
                                        store.toggleHiddenCourse(selectedCourse.id)
                                    }

                                    Button("Set as Default Course") {
                                        store.setDefaultCourse(selectedCourse.id)
                                        store.selectedCourseID = selectedCourse.id
                                    }
                                }

                                if let htmlURL = selectedCourse.htmlURL {
                                    Link("Open in Canvas", destination: htmlURL)
                                }
                            }

                            Picker("Workspace", selection: $selectedSection) {
                                ForEach(CourseWorkspaceSection.allCases) { section in
                                    Text(section.rawValue)
                                        .tag(section)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 760)

                            switch selectedSection {
                            case .overview:
                                CourseOverviewContent(
                                    course: selectedCourse,
                                    hasLoadedAssignments: hasLoadedSelectedCourseAssignments,
                                    assignments: selectedCourseAssignments,
                                    hasLoadedModules: hasLoadedSelectedCourseModules,
                                    modules: selectedCourseModules,
                                    hasLoadedFolders: hasLoadedSelectedCourseFolders,
                                    folders: selectedCourseFolders,
                                    hasLoadedAnnouncements: hasLoadedSelectedCourseAnnouncements,
                                    announcements: selectedCourseAnnouncements,
                                    hasLoadedSyllabus: hasLoadedSelectedCourseSyllabus,
                                    syllabus: selectedCourseSyllabus,
                                    upcomingItems: selectedCourseUpcomingItems,
                                    missingItems: selectedCourseMissingItems
                                )
                            case .modules:
                                CourseModulesContent(
                                    course: selectedCourse,
                                    modules: selectedCourseModules,
                                    isLoading: isLoadingSelectedCourseModules,
                                    searchQuery: $moduleSearchQuery,
                                    filter: $moduleFilter,
                                    sort: $moduleSort,
                                    onOpenNativeDetail: { item in
                                        selectedModuleDetailItem = item
                                    }
                                )
                            case .announcements:
                                CourseAnnouncementsContent(
                                    course: selectedCourse,
                                    announcements: selectedCourseAnnouncements,
                                    isLoading: isLoadingSelectedCourseAnnouncements,
                                    searchQuery: $announcementSearchQuery,
                                    filter: $announcementFilter,
                                    sort: $announcementSort
                                )
                            case .syllabus:
                                CourseSyllabusContent(
                                    course: selectedCourse,
                                    syllabus: selectedCourseSyllabus,
                                    isLoading: isLoadingSelectedCourseSyllabus
                                )
                            case .people:
                                CoursePeopleContent(
                                    course: selectedCourse,
                                    people: selectedCoursePeople,
                                    isLoading: isLoadingSelectedCoursePeople,
                                    hasLoaded: hasLoadedSelectedCoursePeople
                                )
                            case .files:
                                CourseFilesContent(
                                    course: selectedCourse,
                                    folders: selectedCourseFolders,
                                    isLoadingFolders: isLoadingSelectedCourseFolders,
                                    searchQuery: $fileSearchQuery,
                                    filter: $fileFilter,
                                    sort: $fileSort
                                )
                            case .assignments:
                                CourseAssignmentsContent(
                                    course: selectedCourse,
                                    assignments: selectedCourseAssignments,
                                    isLoading: isLoadingSelectedCourseAssignments,
                                    searchQuery: $assignmentSearchQuery,
                                    filter: $assignmentFilter,
                                    sort: $assignmentSort
                                )
                            case .grades:
                                CourseGradesContent(
                                    course: selectedCourse,
                                    assignments: selectedCourseAssignments,
                                    isLoading: isLoadingSelectedCourseAssignments,
                                    searchQuery: $gradeSearchQuery,
                                    sort: $gradeSort
                                )
                            }
                        }
                        .padding(24)
                    }
                    .task(id: "\(selectedCourse.id)-\(selectedSection.rawValue)") {
                        switch selectedSection {
                        case .modules:
                            await store.loadModulesIfNeeded(for: selectedCourse.id)
                        case .announcements:
                            await store.loadAnnouncementsIfNeeded(for: selectedCourse.id)
                        case .syllabus:
                            await store.loadSyllabusIfNeeded(for: selectedCourse.id)
                        case .people:
                            await store.loadPeopleIfNeeded(for: selectedCourse.id)
                        case .files:
                            await store.loadCourseFilesIfNeeded(for: selectedCourse.id)
                        case .assignments, .grades:
                            await store.loadAssignmentsIfNeeded(for: selectedCourse.id)
                        case .overview:
                            break
                        }
                    }
                    .onAppear {
                        applyCoursePreference(for: selectedCourse.id)
                    }
                    .onChange(of: selectedSection) { _, newValue in
                        store.updateCoursePreference(courseID: selectedCourse.id) { preference in
                            preference.workspaceSection = newValue.rawValue
                        }
                    }
                    .onChange(of: moduleSearchQuery) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: moduleFilter) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: moduleSort) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: fileSearchQuery) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: fileFilter) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: fileSort) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: assignmentSearchQuery) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: assignmentFilter) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: assignmentSort) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: gradeSearchQuery) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: gradeSort) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: announcementSearchQuery) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: announcementFilter) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .onChange(of: announcementSort) { _, _ in persistWorkspacePreferences(for: selectedCourse.id) }
                    .sheet(item: $selectedModuleDetailItem) { item in
                        let key = CourseModuleItemDetailKey.key(courseID: selectedCourse.id, item: item)

                        ModuleItemDetailView(
                            item: item,
                            detail: store.moduleItemDetail(for: key),
                            isLoading: store.isLoadingModuleItemDetail(key),
                            courseName: selectedCourse.name
                        )
                        .task(id: key?.rawValue) {
                            await store.loadModuleItemDetailIfNeeded(courseID: selectedCourse.id, item: item)
                        }
                    }
                } else {
                    SetupPromptView(
                        title: "Select a Course",
                        message: "Choose a course from the left to open its workspace."
                    )
                }
            }
            .onAppear {
                if let defaultCourseID = store.resolvedDefaultCourseID(showingHidden: showingHiddenCourses) {
                    store.selectedCourseID = defaultCourseID
                    applyCoursePreference(for: defaultCourseID)
                }
            }
            .onChange(of: store.selectedCourseID) { _, newValue in
                applyCoursePreference(for: newValue)
            }
        }
    }

    private func applyCoursePreference(for courseID: Int?) {
        guard let courseID else {
            return
        }

        let preference = store.coursePreference(for: courseID)
        selectedSection = CourseWorkspaceSection(rawValue: preference.workspaceSection) ?? .overview
        moduleSearchQuery = preference.modules.searchQuery
        moduleFilter = CourseModuleFilter(rawValue: preference.modules.filter) ?? .all
        moduleSort = CourseModuleSort(rawValue: preference.modules.sort) ?? .canvasOrder
        fileSearchQuery = preference.files.searchQuery
        fileFilter = CourseFileFilter(rawValue: preference.files.filter) ?? .all
        fileSort = CourseFileSort(rawValue: preference.files.sort) ?? .canvasOrder
        assignmentSearchQuery = preference.assignments.searchQuery
        assignmentFilter = CourseAssignmentFilter(rawValue: preference.assignments.filter) ?? .all
        assignmentSort = CourseAssignmentSort(rawValue: preference.assignments.sort) ?? .dueDate
        gradeSearchQuery = preference.grades.searchQuery
        gradeSort = CourseGradeSort(rawValue: preference.grades.sort) ?? .recent
        announcementSearchQuery = preference.announcements.searchQuery
        announcementFilter = CourseAnnouncementFilter(rawValue: preference.announcements.filter) ?? .all
        announcementSort = CourseAnnouncementSort(rawValue: preference.announcements.sort) ?? .recent
    }

    private func persistWorkspacePreferences(for courseID: Int) {
        store.updateCoursePreference(courseID: courseID) { preference in
            preference.workspaceSection = selectedSection.rawValue
            preference.modules = CourseWorkspacePreference(
                searchQuery: moduleSearchQuery,
                filter: moduleFilter.rawValue,
                sort: moduleSort.rawValue
            )
            preference.files = CourseWorkspacePreference(
                searchQuery: fileSearchQuery,
                filter: fileFilter.rawValue,
                sort: fileSort.rawValue
            )
            preference.assignments = CourseWorkspacePreference(
                searchQuery: assignmentSearchQuery,
                filter: assignmentFilter.rawValue,
                sort: assignmentSort.rawValue
            )
            preference.grades = CourseWorkspacePreference(
                searchQuery: gradeSearchQuery,
                filter: "All",
                sort: gradeSort.rawValue
            )
            preference.announcements = CourseWorkspacePreference(
                searchQuery: announcementSearchQuery,
                filter: announcementFilter.rawValue,
                sort: announcementSort.rawValue
            )
        }
    }
}

private struct CourseOverviewContent: View {
    let course: Course
    let hasLoadedAssignments: Bool
    let assignments: [CourseAssignment]
    let hasLoadedModules: Bool
    let modules: [CourseModule]
    let hasLoadedFolders: Bool
    let folders: [CanvasFolder]
    let hasLoadedAnnouncements: Bool
    let announcements: [CourseAnnouncement]
    let hasLoadedSyllabus: Bool
    let syllabus: CourseSyllabus?
    let upcomingItems: [UpcomingEvent]
    let missingItems: [MissingSubmission]

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var nextDeadline: UpcomingEvent? {
        upcomingItems.first(where: { event in
            guard let date = event.displayDate else {
                return false
            }

            return date >= Date()
        })
    }

    private var gradedAssignmentsCount: Int {
        assignments.filter { $0.submission?.isGraded == true }.count
    }

    private var gradeHeadline: String {
        if let displayGrade = course.studentEnrollment?.displayCurrentGrade {
            return displayGrade
        }

        if hasLoadedAssignments, let weightedAverage {
            return weightedAverage
        }

        return hasLoadedAssignments ? "Hidden" : "Load"
    }

    private var weightedAverage: String? {
        let totals = assignments.reduce(into: (earned: 0.0, possible: 0.0)) { partialResult, assignment in
            guard
                let score = assignment.submission?.score,
                let pointsPossible = assignment.pointsPossible,
                pointsPossible > 0
            else {
                return
            }

            partialResult.earned += score
            partialResult.possible += pointsPossible
        }

        guard totals.possible > 0 else {
            return nil
        }

        let percentage = (totals.earned / totals.possible) * 100

        if percentage.rounded() == percentage {
            return "\(Int(percentage))%"
        }

        return String(format: "%.1f%%", percentage)
    }

    var body: some View {
        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryCard(
                title: "Upcoming",
                value: "\(upcomingItems.count)",
                detail: "Assignments and events attached to this course.",
                systemImage: "calendar.badge.clock",
                tint: .blue
            )

            SummaryCard(
                title: "Missing",
                value: "\(missingItems.count)",
                detail: "Past-due items that still need attention.",
                systemImage: "exclamationmark.circle",
                tint: .red
            )

            SummaryCard(
                title: "Modules",
                value: hasLoadedModules ? "\(modules.count)" : "Load",
                detail: hasLoadedModules ? "Canvas modules available in this course." : "Open the Modules tab to load the course structure.",
                systemImage: "square.grid.2x2",
                tint: .green
            )

            SummaryCard(
                title: "Files",
                value: hasLoadedFolders ? "\(folders.count)" : "Load",
                detail: hasLoadedFolders ? "Canvas folders available in this course." : "Open the Files tab to browse course materials.",
                systemImage: "folder",
                tint: .purple
            )

            SummaryCard(
                title: "Announcements",
                value: hasLoadedAnnouncements ? "\(announcements.count)" : "Load",
                detail: hasLoadedAnnouncements ? "Recent Canvas announcements available." : "Open Announcements to load course updates.",
                systemImage: "megaphone",
                tint: .indigo
            )

            SummaryCard(
                title: "Syllabus",
                value: hasLoadedSyllabus ? (syllabus?.hasContent == true ? "Ready" : "Empty") : "Load",
                detail: hasLoadedSyllabus ? "Course syllabus has been checked." : "Open Syllabus to load course policies.",
                systemImage: "doc.richtext",
                tint: .cyan
            )

            SummaryCard(
                title: "Assignments",
                value: hasLoadedAssignments ? "\(assignments.count)" : "Load",
                detail: hasLoadedAssignments ? "\(gradedAssignmentsCount) graded items are ready to review." : "Open Assignments or Grades to load coursework.",
                systemImage: "checklist",
                tint: .mint
            )

            SummaryCard(
                title: "Current Grade",
                value: gradeHeadline,
                detail: course.studentEnrollment?.displayCurrentScore.map { "Current score \($0)." } ?? "Uses Canvas totals when available.",
                systemImage: "chart.bar.doc.horizontal",
                tint: .orange
            )

            SummaryCard(
                title: "Next Deadline",
                value: nextDeadline.flatMap { DisplayFormatters.relativeString(date: $0.displayDate) } ?? "Clear",
                detail: nextDeadline?.title ?? "No upcoming deadlines found for this course.",
                systemImage: "flag",
                tint: .teal
            )
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming In This Course")
                .font(.title2.weight(.semibold))

            if upcomingItems.isEmpty {
                Text("No upcoming assignments or events are scheduled right now.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(upcomingItems.prefix(6))) { event in
                    UpcomingEventRow(event: event, courseName: course.name)

                    if event.id != upcomingItems.prefix(6).last?.id {
                        Divider()
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Missing In This Course")
                .font(.title2.weight(.semibold))

            if missingItems.isEmpty {
                Text("Nothing overdue in this course.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(missingItems.prefix(5))) { item in
                    MissingSubmissionRow(submission: item, courseName: course.name)

                    if item.id != missingItems.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct CourseWorkspaceControls<Filter, Sort>: View
where Filter: CaseIterable & Hashable & Identifiable & RawRepresentable,
      Filter.AllCases: RandomAccessCollection,
      Filter.RawValue == String,
      Sort: CaseIterable & Hashable & Identifiable & RawRepresentable,
      Sort.AllCases: RandomAccessCollection,
      Sort.RawValue == String {
    let searchPrompt: String
    @Binding var searchQuery: String
    @Binding var filter: Filter
    @Binding var sort: Sort
    let shownCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            TextField(searchPrompt, text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Picker("Sort", selection: $sort) {
                ForEach(Sort.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Spacer()

            Text("\(shownCount) of \(totalCount) shown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CourseWorkspaceSearchSortControls<Sort>: View
where Sort: CaseIterable & Hashable & Identifiable & RawRepresentable,
      Sort.AllCases: RandomAccessCollection,
      Sort.RawValue == String {
    let searchPrompt: String
    @Binding var searchQuery: String
    @Binding var sort: Sort
    let shownCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            TextField(searchPrompt, text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            Picker("Sort", selection: $sort) {
                ForEach(Sort.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Spacer()

            Text("\(shownCount) of \(totalCount) shown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CourseModulesContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let modules: [CourseModule]
    let isLoading: Bool
    @Binding var searchQuery: String
    @Binding var filter: CourseModuleFilter
    @Binding var sort: CourseModuleSort
    let onOpenNativeDetail: (CourseModuleItem) -> Void

    private var visibleModules: [CourseModule] {
        let filteredModules = modules
            .filter { filter.includes($0) }
            .filter { $0.matchesSearch(searchQuery) }

        switch sort {
        case .canvasOrder:
            return filteredModules.sorted(by: sortByCanvasOrder)
        case .name:
            return filteredModules.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .itemCount:
            return filteredModules.sorted {
                if $0.visibleItemCount != $1.visibleItemCount {
                    return $0.visibleItemCount > $1.visibleItemCount
                }

                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        HStack {
            Text("Modules")
                .font(.title2.weight(.semibold))

            Spacer()

            Button("Refresh Modules") {
                Task {
                    await store.loadModules(for: course.id)
                }
            }
        }

        CourseWorkspaceControls(
            searchPrompt: "Search modules and items",
            searchQuery: $searchQuery,
            filter: $filter,
            sort: $sort,
            shownCount: visibleModules.count,
            totalCount: modules.count
        )

        if isLoading {
            ProgressView("Loading modules...")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else if modules.isEmpty {
            SetupPromptView(
                title: "No Modules Yet",
                message: "If this course uses Canvas Modules, they will appear here after loading."
            )
        } else if visibleModules.isEmpty {
            SetupPromptView(
                title: "No Matching Modules",
                message: "Change the search, filter, or sort controls to review more course modules."
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(visibleModules) { module in
                    CourseModuleCard(module: module, onOpenNativeDetail: onOpenNativeDetail)
                }
            }
        }
    }

    private func sortByCanvasOrder(_ lhs: CourseModule, _ rhs: CourseModule) -> Bool {
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
}

private struct CourseAnnouncementsContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let announcements: [CourseAnnouncement]
    let isLoading: Bool
    @Binding var searchQuery: String
    @Binding var filter: CourseAnnouncementFilter
    @Binding var sort: CourseAnnouncementSort

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var visibleAnnouncements: [CourseAnnouncement] {
        let filteredAnnouncements = announcements
            .filter { filter.includes($0) }
            .filter { $0.matchesSearch(searchQuery) }

        switch sort {
        case .recent:
            return filteredAnnouncements.sorted(by: sortByRecent)
        case .title:
            return filteredAnnouncements.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    private var unreadCount: Int {
        announcements.filter(\.isUnread).count
    }

    private var lockedCount: Int {
        announcements.filter { $0.lockedForUser == true }.count
    }

    var body: some View {
        HStack {
            Text("Announcements")
                .font(.title2.weight(.semibold))

            Spacer()

            Button("Refresh Announcements") {
                Task {
                    await store.loadAnnouncements(for: course.id)
                }
            }
            .disabled(isLoading)
        }

        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryCard(
                title: "Total",
                value: "\(announcements.count)",
                detail: "Announcements Canvas returned for this course.",
                systemImage: "megaphone",
                tint: .indigo
            )

            SummaryCard(
                title: "Unread",
                value: "\(unreadCount)",
                detail: "Announcements Canvas marks as unread.",
                systemImage: "circle.fill",
                tint: .blue
            )

            SummaryCard(
                title: "Restricted",
                value: "\(lockedCount)",
                detail: "Announcements locked for the current user.",
                systemImage: "lock",
                tint: .orange
            )
        }

        CourseWorkspaceControls(
            searchPrompt: "Search announcements",
            searchQuery: $searchQuery,
            filter: $filter,
            sort: $sort,
            shownCount: visibleAnnouncements.count,
            totalCount: announcements.count
        )

        if isLoading && announcements.isEmpty {
            ProgressView("Loading announcements...")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else if announcements.isEmpty {
            SetupPromptView(
                title: "No Announcements Yet",
                message: "Canvas has not returned announcements for this course."
            )
        } else if visibleAnnouncements.isEmpty {
            SetupPromptView(
                title: "No Matching Announcements",
                message: "Change the search, filter, or sort controls to review more announcements."
            )
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(visibleAnnouncements) { announcement in
                    CourseAnnouncementRow(announcement: announcement)

                    if announcement.id != visibleAnnouncements.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func sortByRecent(_ lhs: CourseAnnouncement, _ rhs: CourseAnnouncement) -> Bool {
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
}

private struct CourseAnnouncementRow: View {
    let announcement: CourseAnnouncement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(announcement.title)
                        .font(.headline)

                    if let summaryText = announcement.summaryText {
                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if announcement.isUnread {
                    PillBadge(text: "Unread", tint: .blue)
                }

                if announcement.lockedForUser == true {
                    PillBadge(text: "Restricted", tint: .orange)
                }
            }

            HStack(spacing: 12) {
                Label(
                    DisplayFormatters.formatted(date: announcement.displayDate),
                    systemImage: "clock"
                )

                if let relative = DisplayFormatters.relativeString(date: announcement.displayDate) {
                    Text(relative)
                }

                Spacer()

                if let htmlURL = announcement.htmlURL {
                    Link("Open in Canvas", destination: htmlURL)
                        .font(.caption.weight(.semibold))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}

private struct CourseSyllabusContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let syllabus: CourseSyllabus?
    let isLoading: Bool

    var body: some View {
        HStack {
            Text("Syllabus")
                .font(.title2.weight(.semibold))

            Spacer()

            Button("Refresh Syllabus") {
                Task {
                    await store.loadSyllabus(for: course.id)
                }
            }
            .disabled(isLoading)
        }

        if isLoading && syllabus == nil {
            ProgressView("Loading syllabus...")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else if let syllabus, let summaryText = syllabus.summaryText {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(syllabus.name, systemImage: "doc.richtext")
                        .font(.headline)

                    Spacer()

                    if let htmlURL = syllabus.htmlURL {
                        Link("Open in Canvas", destination: htmlURL)
                    }
                }

                Text(summaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            SetupPromptView(
                title: "No Syllabus Yet",
                message: "Canvas did not return a visible syllabus body for this course."
            )
        }
    }
}

private struct CourseFilesContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let folders: [CanvasFolder]
    let isLoadingFolders: Bool
    @Binding var searchQuery: String
    @Binding var filter: CourseFileFilter
    @Binding var sort: CourseFileSort

    @State private var selectedFolderID: Int?

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var selectedFolder: CanvasFolder? {
        if let selectedFolderID,
           let folder = visibleFolders.first(where: { $0.id == selectedFolderID }) {
            return folder
        }

        return visibleFolders.first
    }

    private var selectedFiles: [CanvasFile] {
        store.files(for: selectedFolder?.id)
    }

    private var visibleFolders: [CanvasFolder] {
        let filteredFolders = folders.filter { $0.matchesSearch(searchQuery) || searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        switch sort {
        case .canvasOrder:
            return filteredFolders.sorted(by: sortFoldersByCanvasOrder)
        case .name, .updated, .size:
            return filteredFolders.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    private var visibleFiles: [CanvasFile] {
        let filteredFiles = selectedFiles
            .filter { filter.includes($0) }
            .filter { $0.matchesSearch(searchQuery) }

        switch sort {
        case .canvasOrder:
            return filteredFiles.sorted { $0.id < $1.id }
        case .name:
            return filteredFiles.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .updated:
            return filteredFiles.sorted {
                switch ($0.updatedAt, $1.updatedAt) {
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

                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .size:
            return filteredFiles.sorted {
                if ($0.size ?? -1) != ($1.size ?? -1) {
                    return ($0.size ?? -1) > ($1.size ?? -1)
                }

                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private var isLoadingSelectedFiles: Bool {
        store.isLoadingFiles(for: selectedFolder?.id)
    }

    private var totalFileCount: Int {
        folders.reduce(0) { partialResult, folder in
            partialResult + (folder.filesCount ?? 0)
        }
    }

    private var unavailableFileCount: Int {
        visibleFiles.filter(\.isUnavailable).count
    }

    var body: some View {
        HStack {
            Text("Files")
                .font(.title2.weight(.semibold))

            Spacer()

            Button("Refresh Files") {
                Task {
                    await store.loadCourseFiles(for: course.id)
                    selectedFolderID = store.folders(for: course.id).first?.id
                }
            }
            .disabled(isLoadingFolders)
        }

        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryCard(
                title: "Folders",
                value: "\(folders.count)",
                detail: "Folders Canvas exposes for this course.",
                systemImage: "folder",
                tint: .purple
            )

            SummaryCard(
                title: "Files",
                value: "\(totalFileCount)",
                detail: "Files reported across the course folder tree.",
                systemImage: "doc",
                tint: .blue
            )

            SummaryCard(
                title: "Selected",
                value: selectedFolder?.filesCount.map { "\($0)" } ?? "\(selectedFiles.count)",
                detail: selectedFolder?.displayName ?? "Choose a folder to review files.",
                systemImage: "folder.badge.gearshape",
                tint: .teal
            )
        }

        CourseWorkspaceControls(
            searchPrompt: "Search folders and files",
            searchQuery: $searchQuery,
            filter: $filter,
            sort: $sort,
            shownCount: visibleFiles.count,
            totalCount: selectedFiles.count
        )

        if isLoadingFolders && folders.isEmpty {
            ProgressView("Loading course files...")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else if folders.isEmpty {
            SetupPromptView(
                title: "No Files Yet",
                message: "Canvas has not returned any visible folders for this course."
            )
        } else if visibleFolders.isEmpty {
            SetupPromptView(
                title: "No Matching Folders",
                message: "Change the search text to review more course folders."
            )
        } else {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Folders")
                        .font(.headline)

                    ForEach(visibleFolders) { folder in
                        CourseFolderRow(
                            folder: folder,
                            isSelected: folder.id == selectedFolder?.id
                        ) {
                            selectedFolderID = folder.id
                            Task {
                                await store.loadFilesIfNeeded(for: folder.id)
                            }
                        }
                    }
                }
                .frame(width: 280, alignment: .topLeading)
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedFolder?.displayName ?? "Files")
                                .font(.headline)

                            if let selectedFolder {
                                Text(selectedFolder.itemCountDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let selectedFolder {
                            Button("Refresh Folder") {
                                Task {
                                    await store.loadFiles(for: selectedFolder.id)
                                }
                            }
                            .disabled(isLoadingSelectedFiles)
                        }
                    }

                    if unavailableFileCount > 0 {
                        PillBadge(text: "\(unavailableFileCount) locked or hidden", tint: .orange)
                    }

                    if isLoadingSelectedFiles && selectedFiles.isEmpty {
                        ProgressView("Loading files...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 24)
                    } else if selectedFiles.isEmpty {
                        SetupPromptView(
                            title: "Folder Is Empty",
                            message: "Canvas did not return any visible files for this folder."
                        )
                    } else if visibleFiles.isEmpty {
                        SetupPromptView(
                            title: "No Matching Files",
                            message: "Change the search, filter, or sort controls to review more files."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(visibleFiles) { file in
                                CourseFileRow(file: file, courseID: course.id)

                                if file.id != visibleFiles.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func selectFirstFolderIfNeeded() {
        guard !folders.isEmpty else {
            selectedFolderID = nil
            return
        }

        if selectedFolderID == nil || !folders.contains(where: { $0.id == selectedFolderID }) {
            selectedFolderID = folders.first?.id
        }
    }

    private func sortFoldersByCanvasOrder(_ lhs: CanvasFolder, _ rhs: CanvasFolder) -> Bool {
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

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}

private struct CourseFolderRow: View {
    let folder: CanvasFolder
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: folder.isUnavailable ? "folder.badge.questionmark" : "folder")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.displayName)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(folder.itemCountDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CourseFileRow: View {
    @EnvironmentObject private var store: CanvasStore

    let file: CanvasFile
    let courseID: Int

    private var updatedDescription: String? {
        guard let updatedAt = file.updatedAt else {
            return nil
        }

        return DisplayFormatters.relativeString(date: updatedAt) ?? DisplayFormatters.formatted(date: updatedAt)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: file.isUnavailable ? "lock.doc" : "doc")
                .foregroundStyle(file.isUnavailable ? .orange : .blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(file.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let sizeDescription = file.sizeDescription {
                        Label(sizeDescription, systemImage: "externaldrive")
                    }

                    if let updatedDescription {
                        Label(updatedDescription, systemImage: "clock")
                    }

                    if let contentType = file.contentType, !contentType.isEmpty {
                        Text(contentType)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if file.isUnavailable {
                PillBadge(text: "Restricted", tint: .orange)
            }

            if let record = store.downloadRecord(for: file) {
                DownloadActions(record: record)
            } else {
                HStack(spacing: 8) {
                    Button("Download") {
                        Task {
                            await store.downloadFile(file, courseID: courseID)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(file.isUnavailable)

                    if let url = file.actionableURL {
                        Link("Open", destination: url)
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct CourseAssignmentsContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let assignments: [CourseAssignment]
    let isLoading: Bool
    @Binding var searchQuery: String
    @Binding var filter: CourseAssignmentFilter
    @Binding var sort: CourseAssignmentSort

    @State private var selectedAssignment: CourseAssignment?

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filteredAssignments: [CourseAssignment] {
        let filteredAssignments = assignments
            .filter { filter.includes($0) }
            .filter { $0.matchesSearch(searchQuery) }

        switch sort {
        case .dueDate:
            return filteredAssignments.sorted(by: sortByDueDate)
        case .name:
            return filteredAssignments.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .status:
            return filteredAssignments.sorted {
                if $0.status.rawValue != $1.status.rawValue {
                    return $0.status.rawValue.localizedCaseInsensitiveCompare($1.status.rawValue) == .orderedAscending
                }

                return sortByDueDate($0, $1)
            }
        case .points:
            return filteredAssignments.sorted {
                if ($0.pointsPossible ?? -1) != ($1.pointsPossible ?? -1) {
                    return ($0.pointsPossible ?? -1) > ($1.pointsPossible ?? -1)
                }

                return sortByDueDate($0, $1)
            }
        }
    }

    private var completedCount: Int {
        assignments.filter { $0.isCompleted }.count
    }

    private var missingCount: Int {
        assignments.filter { $0.status == .missing || $0.status == .late }.count
    }

    private var upcomingCount: Int {
        assignments.filter { $0.isUpcoming }.count
    }

    var body: some View {
        Group {
            HStack {
                Text("Assignments")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Refresh Assignments") {
                    Task {
                        await store.loadAssignments(for: course.id)
                    }
                }
            }

            LazyVGrid(columns: summaryColumns, spacing: 12) {
                SummaryCard(
                    title: "All Work",
                    value: "\(assignments.count)",
                    detail: "Assignments currently published in this course.",
                    systemImage: "doc.text",
                    tint: .blue
                )

                SummaryCard(
                    title: "Upcoming",
                    value: "\(upcomingCount)",
                    detail: "Assignments still open and not yet submitted.",
                    systemImage: "calendar",
                    tint: .orange
                )

                SummaryCard(
                    title: "Missing",
                    value: "\(missingCount)",
                    detail: "Items that Canvas marks as overdue or late.",
                    systemImage: "exclamationmark.circle",
                    tint: .red
                )

                SummaryCard(
                    title: "Completed",
                    value: "\(completedCount)",
                    detail: "Submitted, graded, or excused work.",
                    systemImage: "checkmark.circle",
                    tint: .green
                )
            }

            CourseWorkspaceControls(
                searchPrompt: "Search assignments",
                searchQuery: $searchQuery,
                filter: $filter,
                sort: $sort,
                shownCount: filteredAssignments.count,
                totalCount: assignments.count
            )

            if isLoading && assignments.isEmpty {
                ProgressView("Loading assignments...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else if assignments.isEmpty {
                SetupPromptView(
                    title: "No Assignments Yet",
                    message: "Canvas has not returned any assignments for this course."
                )
            } else if filteredAssignments.isEmpty {
                SetupPromptView(
                    title: "No Matching Work",
                    message: "Change the search, filter, or sort controls to review a different slice of this course."
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredAssignments) { assignment in
                        CourseAssignmentRow(assignment: assignment, courseName: course.name)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAssignment = assignment
                            }

                        if assignment.id != filteredAssignments.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentDetailView(assignment: assignment, courseName: course.name)
        }
    }

    private func sortByDueDate(_ lhs: CourseAssignment, _ rhs: CourseAssignment) -> Bool {
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
}

private struct CourseGradesContent: View {
    @EnvironmentObject private var store: CanvasStore

    let course: Course
    let assignments: [CourseAssignment]
    let isLoading: Bool
    @Binding var searchQuery: String
    @Binding var sort: CourseGradeSort

    @State private var selectedAssignment: CourseAssignment?

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var enrollment: CourseEnrollment? {
        course.studentEnrollment
    }

    private var allGradedAssignments: [CourseAssignment] {
        assignments
            .filter { $0.submission?.isGraded == true }
    }

    private var gradedAssignments: [CourseAssignment] {
        let filteredAssignments = allGradedAssignments.filter { $0.matchesSearch(searchQuery) }

        switch sort {
        case .recent:
            return filteredAssignments.sorted(by: sortByRecentActivity)
        case .name:
            return filteredAssignments.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .score:
            return filteredAssignments.sorted {
                if ($0.submission?.score ?? -1) != ($1.submission?.score ?? -1) {
                    return ($0.submission?.score ?? -1) > ($1.submission?.score ?? -1)
                }

                return sortByRecentActivity($0, $1)
            }
        }
    }

    private var recentGradedAssignments: [CourseAssignment] {
        allGradedAssignments
            .sorted { lhs, rhs in
                sortByRecentActivity(lhs, rhs)
            }
    }

    private var outstandingCount: Int {
        assignments.filter { $0.status == .missing || $0.status == .late || $0.isUpcoming }.count
    }

    private var gradedTotals: (earned: Double, possible: Double) {
        assignments.reduce(into: (earned: 0.0, possible: 0.0)) { partialResult, assignment in
            guard
                let score = assignment.submission?.score,
                let pointsPossible = assignment.pointsPossible,
                pointsPossible > 0
            else {
                return
            }

            partialResult.earned += score
            partialResult.possible += pointsPossible
        }
    }

    private var weightedScoreLabel: String? {
        guard gradedTotals.possible > 0 else {
            return nil
        }

        let percentage = (gradedTotals.earned / gradedTotals.possible) * 100

        if percentage.rounded() == percentage {
            return "\(Int(percentage))%"
        }

        return String(format: "%.1f%%", percentage)
    }

    private var totalEarnedPointsLabel: String? {
        guard gradedTotals.possible > 0 else {
            return nil
        }

        let earned = DisplayFormatters.formattedPoints(gradedTotals.earned) ?? "\(gradedTotals.earned)"
        let possible = DisplayFormatters.formattedPoints(gradedTotals.possible) ?? "\(gradedTotals.possible)"
        return "\(earned) / \(possible)"
    }

    var body: some View {
        Group {
            HStack {
                Text("Grades")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Refresh Grades") {
                    Task {
                        await store.loadAssignments(for: course.id)
                    }
                }
            }

            LazyVGrid(columns: summaryColumns, spacing: 12) {
                SummaryCard(
                    title: "Current Grade",
                    value: enrollment?.displayCurrentGrade ?? weightedScoreLabel ?? "Hidden",
                    detail: enrollment?.displayFinalGrade.map { "Final grade \($0)." } ?? "Falls back to graded assignments when Canvas hides totals.",
                    systemImage: "graduationcap",
                    tint: .green
                )

                SummaryCard(
                    title: "Current Score",
                    value: enrollment?.displayCurrentScore ?? totalEarnedPointsLabel ?? "Pending",
                    detail: totalEarnedPointsLabel.map { "\($0) graded points recorded." } ?? "Scores will appear after graded work is returned.",
                    systemImage: "number.square",
                    tint: .blue
                )

                SummaryCard(
                    title: "Graded Items",
                    value: "\(allGradedAssignments.count)",
                    detail: "Assignments with posted scores or grades.",
                    systemImage: "checkmark.circle",
                    tint: .orange
                )

                SummaryCard(
                    title: "Need Attention",
                    value: "\(outstandingCount)",
                    detail: "Missing, late, or still-upcoming coursework.",
                    systemImage: "flag",
                    tint: .red
                )
            }

            if let gradingPeriodTitle = enrollment?.currentGradingPeriodTitle,
               let gradingPeriodGrade = enrollment?.displayCurrentPeriodGrade {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Grading Period")
                        .font(.headline)

                    Text("\(gradingPeriodTitle): \(gradingPeriodGrade)\(enrollment?.displayCurrentPeriodScore.map { " (\($0))" } ?? "")")
                        .foregroundStyle(.secondary)
                }
            }

            CourseWorkspaceSearchSortControls(
                searchPrompt: "Search graded assignments",
                searchQuery: $searchQuery,
                sort: $sort,
                shownCount: gradedAssignments.count,
                totalCount: allGradedAssignments.count
            )

            if isLoading && assignments.isEmpty {
                ProgressView("Loading grades...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else if allGradedAssignments.isEmpty {
                SetupPromptView(
                    title: "No Grades Posted",
                    message: "Canvas has not returned any graded assignments for this course yet."
                )
            } else if gradedAssignments.isEmpty {
                SetupPromptView(
                    title: "No Matching Scores",
                    message: "Change the search or sort controls to review more graded assignments."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Scores")
                        .font(.title2.weight(.semibold))

                    ForEach(gradedAssignments.prefix(10)) { assignment in
                        CourseAssignmentRow(assignment: assignment, courseName: course.name)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAssignment = assignment
                            }

                        if assignment.id != gradedAssignments.prefix(10).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentDetailView(assignment: assignment, courseName: course.name)
        }
    }

    private func sortByRecentActivity(_ lhs: CourseAssignment, _ rhs: CourseAssignment) -> Bool {
        switch (lhs.recentActivityDate, rhs.recentActivityDate) {
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

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

struct CoursesView_Previews: PreviewProvider {
    static var previews: some View {
        CoursesView()
            .environmentObject(CanvasStore())
    }
}
