//
//  HomeView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var selectedCourseID: Int?

    private var selectedCourseBinding: Binding<Int?> {
        Binding(
            get: { selectedCourseID },
            set: { selectedCourseID = $0 }
        )
    }

    private var filteredMissingSubmissions: [MissingSubmission] {
        store.filteredMissingSubmissions(courseID: selectedCourseID)
            .sorted(by: sortMissingSubmissions)
    }

    private var filteredUpcomingEvents: [UpcomingEvent] {
        store.filteredUpcomingEvents(courseID: selectedCourseID)
    }

    private var todayEvents: [UpcomingEvent] {
        filteredUpcomingEvents.filter { $0.dashboardWindow() == .today }
    }

    private var thisWeekEvents: [UpcomingEvent] {
        filteredUpcomingEvents.filter { $0.dashboardWindow() == .thisWeek }
    }

    private var laterEvents: [UpcomingEvent] {
        filteredUpcomingEvents.filter { $0.dashboardWindow() == .later }
    }

    private var nextUpcomingEvent: UpcomingEvent? {
        (todayEvents + thisWeekEvents + laterEvents).first
    }

    private var selectedCourseName: String {
        selectedCourseID.flatMap { store.courseName(for: $0) } ?? "All Courses"
    }

    var body: some View {
        if !store.isConfigured {
            SetupPromptView(
                title: "Connect Canvas",
                message: "Save your Canvas base URL and personal access token in Settings, then sync to build your dashboard."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    metrics

                    HomeFocusCard(
                        missingSubmission: filteredMissingSubmissions.first,
                        upcomingEvent: nextUpcomingEvent,
                        courseName: { store.courseName(for: $0) }
                    )

                    prioritySections
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dashboard")
                    .font(.largeTitle.weight(.semibold))

                Text("Prioritized work for \(selectedCourseName.lowercased()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Course", selection: selectedCourseBinding) {
                Text("All Courses")
                    .tag(nil as Int?)

                ForEach(store.courses) { course in
                    Text(course.name)
                        .tag(Optional(course.id))
                }
            }
            .frame(width: 260)
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            HomeMetricCard(
                title: "Courses",
                value: selectedCourseID == nil ? "\(store.courses.count)" : "1",
                detail: selectedCourseName,
                systemImage: "books.vertical",
                tint: .blue
            )

            HomeMetricCard(
                title: "Overdue",
                value: "\(filteredMissingSubmissions.count)",
                detail: filteredMissingSubmissions.isEmpty ? "No missing work" : "Needs attention",
                systemImage: "exclamationmark.circle",
                tint: filteredMissingSubmissions.isEmpty ? .secondary : .red
            )

            HomeMetricCard(
                title: "Today",
                value: "\(todayEvents.count)",
                detail: "Due or scheduled today",
                systemImage: "sun.max",
                tint: .orange
            )

            HomeMetricCard(
                title: "This Week",
                value: "\(thisWeekEvents.count)",
                detail: "Next 7 days",
                systemImage: "calendar",
                tint: .green
            )
        }
    }

    @ViewBuilder
    private var prioritySections: some View {
        if filteredMissingSubmissions.isEmpty && todayEvents.isEmpty && thisWeekEvents.isEmpty && laterEvents.isEmpty {
            ContentUnavailableView(
                "All Clear",
                systemImage: "checkmark.circle",
                description: Text("No missing or upcoming Canvas work is visible for \(selectedCourseName.lowercased()).")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
            if !filteredMissingSubmissions.isEmpty {
                HomeSection(
                    title: "Overdue",
                    subtitle: "\(filteredMissingSubmissions.count) item\(filteredMissingSubmissions.count == 1 ? "" : "s") need attention",
                    accentColor: .red
                ) {
                    ForEach(Array(filteredMissingSubmissions.prefix(6))) { submission in
                        HomeMissingRow(
                            submission: submission,
                            courseName: store.courseName(for: submission.courseID)
                        )
                        if submission.id != filteredMissingSubmissions.prefix(6).last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !todayEvents.isEmpty {
                HomeSection(
                    title: "Today",
                    subtitle: "\(todayEvents.count) item\(todayEvents.count == 1 ? "" : "s") scheduled today",
                    accentColor: .orange
                ) {
                    ForEach(todayEvents) { event in
                        HomeEventRow(
                            event: event,
                            courseName: store.courseName(for: event.courseID)
                        )
                        if event.id != todayEvents.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !thisWeekEvents.isEmpty {
                HomeSection(
                    title: "This Week",
                    subtitle: "\(thisWeekEvents.count) upcoming item\(thisWeekEvents.count == 1 ? "" : "s")",
                    accentColor: .green
                ) {
                    ForEach(Array(thisWeekEvents.prefix(8))) { event in
                        HomeEventRow(
                            event: event,
                            courseName: store.courseName(for: event.courseID)
                        )
                        if event.id != thisWeekEvents.prefix(8).last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !laterEvents.isEmpty {
                HomeSection(
                    title: "Later",
                    subtitle: "\(laterEvents.count) item\(laterEvents.count == 1 ? "" : "s") beyond this week",
                    accentColor: .secondary
                ) {
                    ForEach(Array(laterEvents.prefix(6))) { event in
                        HomeEventRow(
                            event: event,
                            courseName: store.courseName(for: event.courseID)
                        )
                        if event.id != laterEvents.prefix(6).last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }

    private func sortMissingSubmissions(_ lhs: MissingSubmission, _ rhs: MissingSubmission) -> Bool {
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

private struct HomeMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct HomeFocusCard: View {
    let missingSubmission: MissingSubmission?
    let upcomingEvent: UpcomingEvent?
    let courseName: (Int?) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: focusIcon)
                    .foregroundStyle(focusTint)
                Text("Focus")
                    .font(.headline)
                Spacer()
                PillBadge(text: focusBadge, tint: focusTint)
            }

            Text(focusTitle)
                .font(.title3.weight(.semibold))

            Text(focusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let url = focusURL {
                Link("Open in Canvas", destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(focusTint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var focusIcon: String {
        missingSubmission == nil ? "sparkles" : "exclamationmark.triangle"
    }

    private var focusTint: Color {
        missingSubmission == nil ? .blue : .red
    }

    private var focusBadge: String {
        if missingSubmission != nil {
            return "Overdue"
        }

        return upcomingEvent == nil ? "Clear" : "Next Up"
    }

    private var focusTitle: String {
        missingSubmission?.name ?? upcomingEvent?.title ?? "No urgent work right now"
    }

    private var focusDetail: String {
        if let missingSubmission {
            let course = courseName(missingSubmission.courseID) ?? "Canvas"
            let due = DisplayFormatters.relativeString(date: missingSubmission.dueAt) ?? DisplayFormatters.formatted(date: missingSubmission.dueAt)
            return "\(course) · \(due)"
        }

        if let upcomingEvent {
            let course = courseName(upcomingEvent.courseID) ?? "Canvas"
            let due = DisplayFormatters.relativeString(date: upcomingEvent.displayDate) ?? DisplayFormatters.formatted(date: upcomingEvent.displayDate)
            return "\(course) · \(due)"
        }

        return "You are caught up for the current course filter."
    }

    private var focusURL: URL? {
        missingSubmission?.htmlURL ?? upcomingEvent?.actionableURL
    }
}

private struct HomeSection<Content: View>: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let content: Content

    init(title: String, subtitle: String, accentColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct HomeMissingRow: View {
    let submission: MissingSubmission
    let courseName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(Color.red, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(submission.name)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    if let courseName {
                        Text(courseName)
                            .foregroundStyle(Color.secondary)
                    }
                    if let dueAt = submission.dueAt,
                       let relative = DisplayFormatters.relativeString(date: dueAt) {
                        if courseName != nil {
                            Text("·").foregroundStyle(Color(white: 0.6))
                        }
                        Text(relative).foregroundStyle(Color.red)
                    }
                }
                .font(.caption)
            }

            Spacer()

            if let url = submission.htmlURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 9)
    }
}

private struct HomeEventRow: View {
    let event: UpcomingEvent
    let courseName: String?

    private var tint: Color {
        switch event.dashboardWindow() {
        case .today:
            return .orange
        case .thisWeek:
            return .green
        case .later:
            return .secondary
        case nil:
            return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(tint, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    if let courseName {
                        Text(courseName)
                            .foregroundStyle(Color.secondary)
                    }
                    if let date = event.displayDate,
                       let relative = DisplayFormatters.relativeString(date: date) {
                        if courseName != nil {
                            Text("·").foregroundStyle(Color(white: 0.6))
                        }
                        Text(relative).foregroundStyle(Color.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            PillBadge(text: event.kindLabel, tint: event.isAssignment ? .blue : .green)

            if let url = event.actionableURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 9)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(CanvasStore())
    }
}
