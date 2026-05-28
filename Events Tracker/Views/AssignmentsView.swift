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

    private var subtitleText: String {
        if isLoading {
            return "Loading the latest assignment data…"
        }

        return "\(overdueAssignments.count) overdue · \(upcomingAssignments.count) upcoming"
    }

    var body: some View {
        let overdueItems = overdueAssignments
        let upcomingItems = upcomingAssignments
        let lastOverdueID = overdueItems.last?.id
        let lastUpcomingID = upcomingItems.last?.id

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
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(
                        title: "Assignments",
                        subtitle: subtitleText
                    ) {
                        EmptyView()
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        MetricCard(
                            title: "Overdue",
                            value: "\(overdueItems.count)",
                            detail: overdueItems.isEmpty ? "Nothing overdue" : "Needs attention",
                            systemImage: "exclamationmark.circle",
                            tint: overdueItems.isEmpty ? .green : .red
                        )

                        MetricCard(
                            title: "Upcoming",
                            value: "\(upcomingItems.count)",
                            detail: upcomingItems.isEmpty ? "All clear ahead" : "Plan ahead",
                            systemImage: "calendar.badge.clock",
                            tint: .orange
                        )

                        MetricCard(
                            title: "Courses",
                            value: "\(store.courses.count)",
                            detail: "Tracked in this account",
                            systemImage: "books.vertical",
                            tint: .blue
                        )
                    }

                    AssignmentFilterBar(filter: $filter)

                    VStack(alignment: .leading, spacing: 18) {
                        // Overdue section
                        if filter == .all || filter == .missing {
                            if !overdueItems.isEmpty {
                                AssignmentSection(title: "OVERDUE", accentColor: .red, count: overdueItems.count) {
                                    ForEach(overdueItems) { assignment in
                                        AssignmentRow(
                                            assignment: assignment,
                                            courseName: store.courseName(for: assignment.courseID)
                                        )
                                        if assignment.id != lastOverdueID {
                                            Divider().padding(.leading, 32)
                                        }
                                    }
                                }
                            } else if filter == .missing {
                                Text("Nothing overdue.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Upcoming section
                        if filter == .all || filter == .upcoming {
                            if !upcomingItems.isEmpty {
                                AssignmentSection(title: "UPCOMING", accentColor: .orange, count: upcomingItems.count) {
                                    ForEach(upcomingItems) { assignment in
                                        AssignmentRow(
                                            assignment: assignment,
                                            courseName: store.courseName(for: assignment.courseID)
                                        )
                                        if assignment.id != lastUpcomingID {
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
                        if filter == .all && overdueItems.isEmpty && upcomingItems.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                IconBadge(systemImage: "checkmark.seal.fill", tint: .green, size: 56, cornerRadius: 14)

                                VStack(spacing: 4) {
                                    Text("All caught up")
                                        .font(.title3.weight(.semibold))
                                    Text("No unfinished assignments found.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                        }
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

private struct AssignmentFilterBar: View {
    @Binding var filter: AssignmentFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AssignmentFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(filter == option ? .semibold : .regular))
                        .foregroundStyle(filter == option ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(filter == option ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    filter == option ? Color.accentColor.opacity(0.25) : Color.cardBorder,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.6)
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.15))
                    )
                Spacer()
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                content
            }
            .appCard(padding: 14)
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
