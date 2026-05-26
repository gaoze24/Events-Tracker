//
//  HomeView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct HomeDashboardDisplayState {
    let prioritizedMissingSubmissions: [MissingSubmission]
    let priorityNowItems: [CanvasStore.DashboardPriorityItem]
    let focusItem: CanvasStore.DashboardPriorityItem?
    let secondaryPriorityNowItems: [CanvasStore.DashboardPriorityItem]
    let overdueSectionSubmissions: [MissingSubmission]
    let todayEvents: [UpcomingEvent]
    let thisWeekEvents: [UpcomingEvent]
    let laterEvents: [UpcomingEvent]

    init(
        prioritizedMissingSubmissions: [MissingSubmission],
        prioritizedUpcomingEvents: [UpcomingEvent],
        priorityNowItems: [CanvasStore.DashboardPriorityItem],
        referenceDate: Date = Date()
    ) {
        self.prioritizedMissingSubmissions = prioritizedMissingSubmissions
        self.priorityNowItems = priorityNowItems
        focusItem = priorityNowItems.first

        if let focusItem {
            secondaryPriorityNowItems = priorityNowItems.filter { $0.id != focusItem.id }
        } else {
            secondaryPriorityNowItems = priorityNowItems
        }

        let highlightedPriorityIDs = Set(priorityNowItems.map(\.id))
        overdueSectionSubmissions = prioritizedMissingSubmissions.filter {
            !highlightedPriorityIDs.contains(Self.priorityID(for: $0))
        }

        let secondaryUpcomingEvents = prioritizedUpcomingEvents.filter {
            !highlightedPriorityIDs.contains(Self.priorityID(for: $0))
        }
        todayEvents = secondaryUpcomingEvents.filter {
            $0.dashboardWindow(referenceDate: referenceDate) == .today
        }
        thisWeekEvents = secondaryUpcomingEvents.filter {
            $0.dashboardWindow(referenceDate: referenceDate) == .thisWeek
        }
        laterEvents = secondaryUpcomingEvents.filter {
            $0.dashboardWindow(referenceDate: referenceDate) == .later
        }
    }

    private static func priorityID(for submission: MissingSubmission) -> String {
        "missing-\(submission.id)"
    }

    private static func priorityID(for event: UpcomingEvent) -> String {
        "event-\(event.id)"
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var selectedCourseID: Int?

    private var selectedCourseBinding: Binding<Int?> {
        Binding(
            get: { selectedCourseID },
            set: { selectedCourseID = $0 }
        )
    }

    private var selectedCourseName: String {
        selectedCourseID.flatMap { store.courseName(for: $0) } ?? "All Courses"
    }

    var body: some View {
        if !store.isConfigured {
            SetupPromptView(
                title: "Connect Canvas",
                message: "Save your Canvas base URL and personal access token in Settings, then sync to build your dashboard.",
                systemImage: "link.badge.plus",
                tint: .blue
            )
        } else {
            let dashboardState = HomeDashboardDisplayState(
                prioritizedMissingSubmissions: store.prioritizedMissingSubmissions(courseID: selectedCourseID),
                prioritizedUpcomingEvents: store.prioritizedUpcomingEvents(courseID: selectedCourseID),
                priorityNowItems: store.priorityNowItems(courseID: selectedCourseID)
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    metrics(dashboardState)

                    HomeFocusCard(
                        item: dashboardState.focusItem,
                        courseName: { store.courseName(for: $0) }
                    )

                    prioritySections(dashboardState)
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        ScreenHeader(
            title: "Dashboard",
            subtitle: "Prioritized work for \(selectedCourseName.lowercased())."
        ) {
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

    private func metrics(_ state: HomeDashboardDisplayState) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            MetricCard(
                title: "Courses",
                value: selectedCourseID == nil ? "\(store.courses.count)" : "1",
                detail: selectedCourseName,
                systemImage: "books.vertical",
                tint: .blue
            )

            MetricCard(
                title: "Overdue",
                value: "\(state.prioritizedMissingSubmissions.count)",
                detail: state.prioritizedMissingSubmissions.isEmpty ? "No missing work" : "Needs attention",
                systemImage: "exclamationmark.circle",
                tint: state.prioritizedMissingSubmissions.isEmpty ? .green : .red
            )

            MetricCard(
                title: "Today",
                value: "\(state.todayEvents.count)",
                detail: "Due or scheduled today",
                systemImage: "sun.max",
                tint: .orange
            )

            MetricCard(
                title: "This Week",
                value: "\(state.thisWeekEvents.count)",
                detail: "Next 7 days",
                systemImage: "calendar",
                tint: .green
            )
        }
    }

    @ViewBuilder
    private func prioritySections(_ state: HomeDashboardDisplayState) -> some View {
        if state.priorityNowItems.isEmpty && state.overdueSectionSubmissions.isEmpty && state.todayEvents.isEmpty && state.thisWeekEvents.isEmpty && state.laterEvents.isEmpty {
            ContentUnavailableView(
                "All Clear",
                systemImage: "checkmark.circle",
                description: Text("No missing or upcoming Canvas work is visible for \(selectedCourseName.lowercased()).")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
            if !state.secondaryPriorityNowItems.isEmpty {
                HomeSection(
                    title: "Priority Now",
                    subtitle: "\(state.secondaryPriorityNowItems.count) more item\(state.secondaryPriorityNowItems.count == 1 ? "" : "s") worth handling first",
                    accentColor: .blue
                ) {
                    ForEach(state.secondaryPriorityNowItems) { item in
                        HomePriorityRow(
                            item: item,
                            courseName: store.courseName(for: item.courseID)
                        )
                        if item.id != state.secondaryPriorityNowItems.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !state.overdueSectionSubmissions.isEmpty {
                HomeSection(
                    title: "Overdue",
                    subtitle: "\(state.overdueSectionSubmissions.count) item\(state.overdueSectionSubmissions.count == 1 ? "" : "s") need attention",
                    accentColor: .red
                ) {
                    ForEach(Array(state.overdueSectionSubmissions.prefix(6))) { submission in
                        HomeMissingRow(
                            submission: submission,
                            courseName: store.courseName(for: submission.courseID)
                        )
                        if submission.id != state.overdueSectionSubmissions.prefix(6).last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !state.todayEvents.isEmpty {
                HomeSection(
                    title: "Today",
                    subtitle: "\(state.todayEvents.count) item\(state.todayEvents.count == 1 ? "" : "s") scheduled today",
                    accentColor: .orange
                ) {
                    ForEach(state.todayEvents) { event in
                        HomeEventRow(
                            event: event,
                            courseName: store.courseName(for: event.courseID)
                        )
                        if event.id != state.todayEvents.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !state.thisWeekEvents.isEmpty {
                HomeSection(
                    title: "This Week",
                    subtitle: "\(state.thisWeekEvents.count) upcoming item\(state.thisWeekEvents.count == 1 ? "" : "s")",
                    accentColor: .green
                ) {
                    ForEach(Array(state.thisWeekEvents.prefix(8))) { event in
                        HomeEventRow(
                            event: event,
                            courseName: store.courseName(for: event.courseID)
                        )
                        if event.id != state.thisWeekEvents.prefix(8).last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !state.laterEvents.isEmpty {
                HomeSection(
                    title: "Later",
                    subtitle: "\(state.laterEvents.count) item\(state.laterEvents.count == 1 ? "" : "s") beyond this week",
                    accentColor: .secondary
                ) {
                    ForEach(Array(state.laterEvents.prefix(6))) { event in
                        HomeEventRow(
                            event: event,
                            courseName: store.courseName(for: event.courseID)
                        )
                        if event.id != state.laterEvents.prefix(6).last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }

}

private struct HomeFocusCard: View {
    let item: CanvasStore.DashboardPriorityItem?
    let courseName: (Int?) -> String?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            IconBadge(systemImage: focusIcon, tint: focusTint, size: 48, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Focus")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(.secondary)

                    PillBadge(text: focusBadge, tint: focusTint)

                    Spacer(minLength: 0)
                }

                Text(focusTitle)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(focusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let url = item?.actionableURL {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Open in Canvas")
                            Image(systemName: "arrow.up.forward")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(focusTint)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedCard(focusTint, padding: 20)
    }

    private var focusIcon: String {
        guard let item else {
            return "sparkles"
        }

        return item.isMissing ? "exclamationmark.triangle.fill" : "bolt.fill"
    }

    private var focusTint: Color {
        guard let item else {
            return .green
        }

        return item.isMissing ? .red : .blue
    }

    private var focusBadge: String {
        guard let item else {
            return "All clear"
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
            SectionHeader(title: title, subtitle: subtitle, tint: accentColor)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .appCard(padding: 14)
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
