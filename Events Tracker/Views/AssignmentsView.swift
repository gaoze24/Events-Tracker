//
//  AssignmentsView.swift
//  Events Tracker
//

import SwiftUI

private enum AssignmentFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case upcoming = "Upcoming"
    case missing = "Missing"

    var id: String { rawValue }
}

struct AssignmentsView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var filter: AssignmentFilter = .all

    private var allLoadedAssignments: [CourseAssignment] {
        store.courseAssignmentsByCourseID.values.flatMap { $0 }
    }

    private var overdueAssignments: [CourseAssignment] {
        allLoadedAssignments
            .filter { $0.status == .missing || $0.status == .late }
            .sorted { ($0.dueAt ?? .distantPast) < ($1.dueAt ?? .distantPast) }
    }

    private var upcomingAssignments: [CourseAssignment] {
        allLoadedAssignments
            .filter { $0.isUpcoming }
            .sorted {
                switch ($0.dueAt, $1.dueAt) {
                case let (a?, b?): return a < b
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return $0.name < $1.name
                }
            }
    }

    private var isLoading: Bool {
        !store.loadingCourseAssignmentIDs.isEmpty
    }

    var body: some View {
        if !store.isConfigured {
            SetupPromptView(
                title: "Connect Canvas",
                message: "Save your Canvas credentials in Settings to view your assignments."
            )
        } else if store.courses.isEmpty {
            SetupPromptView(
                title: "No Courses",
                message: "Sync to load your active courses and assignments."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assignments")
                            .font(.largeTitle.weight(.semibold))

                        Group {
                            if isLoading {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.65)
                                    Text("Loading…")
                                }
                            } else {
                                Text("\(overdueAssignments.count) overdue · \(upcomingAssignments.count) upcoming")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)

                    // Filter pills
                    HStack(spacing: 4) {
                        ForEach(AssignmentFilter.allCases) { option in
                            Button {
                                filter = option
                            } label: {
                                Text(option.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(filter == option ? .medium : .regular)
                                    .foregroundStyle(filter == option ? Color.primary : Color.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(filter == option ? Color.primary.opacity(0.07) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)

                    // Overdue section
                    if filter == .all || filter == .missing {
                        if !overdueAssignments.isEmpty {
                            AssignmentSection(title: "OVERDUE", accentColor: .red, count: overdueAssignments.count) {
                                ForEach(overdueAssignments) { assignment in
                                    AssignmentRow(
                                        assignment: assignment,
                                        courseName: store.courseName(for: assignment.courseID)
                                    )
                                    if assignment.id != overdueAssignments.last?.id {
                                        Divider().padding(.leading, 32)
                                    }
                                }
                            }
                            .padding(.bottom, 28)
                        } else if filter == .missing {
                            Text("Nothing overdue.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Upcoming section
                    if filter == .all || filter == .upcoming {
                        if !upcomingAssignments.isEmpty {
                            AssignmentSection(title: "UPCOMING", accentColor: .orange, count: upcomingAssignments.count) {
                                ForEach(upcomingAssignments) { assignment in
                                    AssignmentRow(
                                        assignment: assignment,
                                        courseName: store.courseName(for: assignment.courseID)
                                    )
                                    if assignment.id != upcomingAssignments.last?.id {
                                        Divider().padding(.leading, 32)
                                    }
                                }
                            }
                        } else if filter == .upcoming {
                            Text("No upcoming assignments.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // All caught up
                    if filter == .all && overdueAssignments.isEmpty && upcomingAssignments.isEmpty && !isLoading {
                        VStack(spacing: 6) {
                            Text("All caught up")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("No unfinished assignments found.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                }
                .padding(24)
            }
            .task {
                for course in store.courses {
                    await store.loadAssignmentsIfNeeded(for: course.id)
                }
            }
        }
    }
}

private struct AssignmentSection<Content: View>: View {
    let title: String
    let accentColor: Color
    let count: Int
    let content: Content

    init(title: String, accentColor: Color, count: Int, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accentColor = accentColor
        self.count = count
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.3)
                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            content
        }
    }
}

private struct AssignmentRow: View {
    let assignment: CourseAssignment
    let courseName: String?

    private var dotColor: Color {
        switch assignment.status {
        case .missing, .late: return .red
        case .upcoming: return .orange
        default: return .gray
        }
    }

    private var dueDateColor: Color {
        assignment.status == .missing || assignment.status == .late ? .red : Color.secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(dotColor, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.name)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    if let courseName {
                        Text(courseName)
                            .foregroundStyle(Color.secondary)
                    }

                    if let dueAt = assignment.dueAt,
                       let relative = DisplayFormatters.relativeString(date: dueAt) {
                        if courseName != nil {
                            Text("·").foregroundStyle(Color(white: 0.6))
                        }
                        Text(relative)
                            .foregroundStyle(dueDateColor)
                    } else if assignment.dueAt == nil {
                        if courseName != nil {
                            Text("·").foregroundStyle(Color(white: 0.6))
                        }
                        Text("No due date")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            AssignmentRowActions(assignment: assignment)
        }
        .padding(.vertical, 9)
    }
}

private struct AssignmentRowActions: View {
    let assignment: CourseAssignment

    var body: some View {
        AssignmentCompactActions(assignment: assignment)
    }
}

struct AssignmentsView_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentsView()
            .environmentObject(CanvasStore())
    }
}
