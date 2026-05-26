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

    private var prioritizedMissingSubmissions: [MissingSubmission] {
        store.prioritizedMissingSubmissions(courseID: selectedCourseID)
    }

    private var prioritizedUpcomingEvents: [UpcomingEvent] {
        store.prioritizedUpcomingEvents(courseID: selectedCourseID)
    }

    private var priorityNowItems: [CanvasStore.DashboardPriorityItem] {
        store.priorityNowItems(courseID: selectedCourseID)
    }

    private var focusItem: CanvasStore.DashboardPriorityItem? {
        store.dashboardFocusItem(courseID: selectedCourseID)
    }

    private var secondaryPriorityNowItems: [CanvasStore.DashboardPriorityItem] {
        guard let focusItem else {
            return priorityNowItems
        }

        return priorityNowItems.filter { $0.id != focusItem.id }
    }

    private var highlightedPriorityIDs: Set<String> {
        Set(priorityNowItems.map(\.id))
    }

    private var todayEvents: [UpcomingEvent] {
        prioritizedUpcomingEvents
            .filter { !highlightedPriorityIDs.contains(Self.priorityID(for: $0)) }
            .filter { $0.dashboardWindow() == .today }
    }

    private var thisWeekEvents: [UpcomingEvent] {
        prioritizedUpcomingEvents
            .filter { !highlightedPriorityIDs.contains(Self.priorityID(for: $0)) }
            .filter { $0.dashboardWindow() == .thisWeek }
    }

    private var laterEvents: [UpcomingEvent] {
        prioritizedUpcomingEvents
            .filter { !highlightedPriorityIDs.contains(Self.priorityID(for: $0)) }
            .filter { $0.dashboardWindow() == .later }
    }

    private var overdueSectionSubmissions: [MissingSubmission] {
        prioritizedMissingSubmissions.filter { !highlightedPriorityIDs.contains(Self.priorityID(for: $0)) }
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
                        item: focusItem,
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
                value: "\(prioritizedMissingSubmissions.count)",
                detail: prioritizedMissingSubmissions.isEmpty ? "No missing work" : "Needs attention",
                systemImage: "exclamationmark.circle",
                tint: prioritizedMissingSubmissions.isEmpty ? .secondary : .red
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
        if priorityNowItems.isEmpty && overdueSectionSubmissions.isEmpty && todayEvents.isEmpty && thisWeekEvents.isEmpty && laterEvents.isEmpty {
            ContentUnavailableView(
                "All Clear",
                systemImage: "checkmark.circle",
                description: Text("No missing or upcoming Canvas work is visible for \(selectedCourseName.lowercased()).")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
            if !secondaryPriorityNowItems.isEmpty {
                HomeSection(
                    title: "Priority Now",
                    subtitle: "\(secondaryPriorityNowItems.count) more item\(secondaryPriorityNowItems.count == 1 ? "" : "s") worth handling first",
                    accentColor: .blue
                ) {
                    ForEach(secondaryPriorityNowItems) { item in
                        HomePriorityRow(
                            item: item,
                            courseName: store.courseName(for: item.courseID)
                        )
                        if item.id != secondaryPriorityNowItems.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !overdueSectionSubmissions.isEmpty {
                HomeSection(
                    title: "Overdue",
                    subtitle: "\(overdueSectionSubmissions.count) item\(overdueSectionSubmissions.count == 1 ? "" : "s") need attention",
                    accentColor: .red
                ) {
                    ForEach(Array(overdueSectionSubmissions.prefix(6))) { submission in
                        HomeMissingRow(
                            submission: submission,
                            courseName: store.courseName(for: submission.courseID)
                        )
                        if submission.id != overdueSectionSubmissions.prefix(6).last?.id {
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

    private static func priorityID(for submission: MissingSubmission) -> String {
        "missing-\(submission.id)"
    }

    private static func priorityID(for event: UpcomingEvent) -> String {
        "event-\(event.id)"
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
    let item: CanvasStore.DashboardPriorityItem?
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

            if let url = item?.actionableURL {
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
        item?.isMissing == true ? "exclamationmark.triangle" : "sparkles"
    }

    private var focusTint: Color {
        item?.isMissing == true ? .red : .blue
    }

    private var focusBadge: String {
        guard let item else {
            return "Clear"
        }

        return item.isMissing ? "Overdue" : "Next Up"
    }

    private var focusTitle: String {
        item?.title ?? "No urgent work right now"
    }

    private var focusDetail: String {
        guard let item else {
            return "You are caught up for the current course filter."
        }

        let course = courseName(item.courseID) ?? "Canvas"
        let when = DisplayFormatters.relativeString(date: item.date) ?? DisplayFormatters.formatted(date: item.date)
        return "\(course) · \(when)"
    }
}

private struct HomePriorityRow: View {
    let item: CanvasStore.DashboardPriorityItem
    let courseName: String?

    private var tint: Color {
        item.isMissing ? .red : (item.isAssignmentBackedEvent ? .orange : .blue)
    }

    private var badgeTint: Color {
        item.isMissing ? .red : (item.isAssignmentBackedEvent ? .blue : .green)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(tint, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    if let courseName {
                        Text(courseName)
                            .foregroundStyle(Color.secondary)
                    }
                    if let date = item.date,
                       let relative = DisplayFormatters.relativeString(date: date) {
                        if courseName != nil {
                            Text("·").foregroundStyle(Color(white: 0.6))
                        }
                        Text(relative)
                            .foregroundStyle(tint)
                    }
                }
                .font(.caption)
            }

            Spacer()

            PillBadge(text: item.subtitle, tint: badgeTint)

            if let url = item.actionableURL {
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
