//
//  EventsView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

private enum EventsDisplayMode: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case week = "Week"
    case agenda = "Agenda"

    var id: String { rawValue }
}

struct EventsView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var displayMode: EventsDisplayMode = .calendar
    @State private var selectedDate = Date()
    @State private var visibleMonth = Date()

    private let calendar = Calendar.current
    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var selectedCourseBinding: Binding<Int?> {
        Binding(
            get: { store.selectedCourseID },
            set: { newValue in
                store.selectedCourseID = newValue
                store.setDefaultEventsCourse(newValue)
            }
        )
    }

    private var filteredUpcomingEvents: [UpcomingEvent] {
        store.filteredUpcomingEvents(courseID: store.selectedCourseID)
    }

    private var filteredMissingSubmissions: [MissingSubmission] {
        store.filteredMissingSubmissions(courseID: store.selectedCourseID)
    }

    private var calendarItems: [CalendarEventItem] {
        CalendarEventItem.items(
            upcomingEvents: filteredUpcomingEvents,
            missingSubmissions: filteredMissingSubmissions
        )
    }

    private var datedItems: [CalendarEventItem] {
        calendarItems.filter { $0.date != nil }
    }

    private var undatedItems: [CalendarEventItem] {
        calendarItems.filter { $0.date == nil }
    }

    private var selectedDayItems: [CalendarEventItem] {
        CalendarEventItem.datedItems(calendarItems, on: selectedDate, calendar: calendar)
    }

    private var weekDays: [Date] {
        CalendarEventItem.visibleWeekDays(containing: selectedDate, calendar: calendar)
    }

    private var monthDays: [Date] {
        CalendarEventItem.visibleMonthDays(containing: visibleMonth, calendar: calendar)
    }

    private var selectedCourseTitle: String {
        store.selectedCourseName ?? "All Courses"
    }

    var body: some View {
        if !store.isConfigured {
            SetupPromptView(
                title: "Canvas Events Need a Connection",
                message: "Add your Canvas credentials in Settings to load assignments, calendar events, and missing work."
            )
        } else {
            HStack(spacing: 0) {
                List(selection: selectedCourseBinding) {
                    Text("All Courses")
                        .tag(nil as Int?)

                    ForEach(store.preferredCourses()) { course in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.name)
                            if let termName = course.enrollmentTerm?.name, !termName.isEmpty {
                                Text(termName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(Optional(course.id))
                    }
                }
                .frame(minWidth: 250, idealWidth: 260, maxWidth: 280)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        title: selectedCourseTitle,
                        subtitle: "\(filteredUpcomingEvents.count) upcoming · \(filteredMissingSubmissions.count) missing"
                    ) {
                        HStack(spacing: 10) {
                            Button {
                                selectedDate = Date()
                                visibleMonth = Date()
                            } label: {
                                Label("Today", systemImage: "scope")
                            }
                            .buttonStyle(.bordered)

                            Picker("View", selection: $displayMode) {
                                ForEach(EventsDisplayMode.allCases) { item in
                                    Text(item.rawValue)
                                        .tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                        }
                    }

                    if calendarItems.isEmpty {
                        SetupPromptView(
                            title: "No Calendar Items",
                            message: "Canvas is not reporting upcoming events or missing work for \(selectedCourseTitle.lowercased())."
                        )
                    } else {
                        switch displayMode {
                        case .calendar:
                            calendarMode
                        case .week:
                            weekMode
                        case .agenda:
                            agendaMode
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onAppear {
                if store.selectedCourseID == nil,
                   let defaultCourseID = store.resolvedDefaultEventsCourseID() {
                    store.selectedCourseID = defaultCourseID
                }
            }
        }
    }

    private var calendarMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    changeVisibleMonth(by: -1)
                } label: {
                    Label("Previous Month", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }

                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title2.weight(.semibold))

                Button {
                    changeVisibleMonth(by: 1)
                } label: {
                    Label("Next Month", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }

                Spacer()

                Text("\(datedItems.count) dated · \(undatedItems.count) undated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                LazyVGrid(columns: monthColumns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthDays, id: \.self) { day in
                        CalendarDayCell(
                            day: day,
                            items: CalendarEventItem.datedItems(calendarItems, on: day, calendar: calendar),
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                            isInVisibleMonth: calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month),
                            isToday: calendar.isDateInToday(day)
                        ) {
                            selectedDate = day
                        }
                    }
                }
                .frame(minWidth: 520)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.6)

                        Text(selectedDate.formatted(.dateTime.month().day()))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                    }

                    EventItemsPanel(
                        title: "Selected Day",
                        emptyTitle: "No items on this day",
                        items: selectedDayItems,
                        courseName: store.courseName(for:)
                    )

                    if !undatedItems.isEmpty {
                        EventItemsPanel(
                            title: "Needs Scheduling",
                            emptyTitle: "No undated items",
                            items: undatedItems,
                            courseName: store.courseName(for:)
                        )
                    }
                }
                .frame(width: 340, alignment: .topLeading)
                .appCard(padding: 16)
            }
        }
    }

    private var weekMode: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    changeSelectedWeek(by: -1)
                } label: {
                    Label("Previous Week", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }

                Text(weekTitle)
                    .font(.title2.weight(.semibold))

                Button {
                    changeSelectedWeek(by: 1)
                } label: {
                    Label("Next Week", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }

                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(weekDays, id: \.self) { day in
                    WeekDayColumn(
                        day: day,
                        items: CalendarEventItem.datedItems(calendarItems, on: day, calendar: calendar),
                        isToday: calendar.isDateInToday(day),
                        courseName: store.courseName(for:)
                    )
                }
            }
        }
    }

    private var agendaMode: some View {
        let groupedItems = CalendarEventItem.groupByDay(calendarItems, calendar: calendar)
        let sortedDays = groupedItems.keys.sorted()

        return VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Agenda", systemImage: "list.bullet.rectangle", tint: .accentColor)

            if !undatedItems.isEmpty {
                EventItemsPanel(
                    title: "Needs Scheduling",
                    emptyTitle: "No undated items",
                    items: undatedItems,
                    courseName: store.courseName(for:)
                )
                .tintedCard(.orange, padding: 16)
            }

            if sortedDays.isEmpty {
                SetupPromptView(
                    title: "No Dated Items",
                    message: "The current Canvas items do not have dates to place on the agenda.",
                    systemImage: "calendar.badge.exclamationmark",
                    tint: .orange
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedDays, id: \.self) { day in
                        EventItemsPanel(
                            title: day.formatted(.dateTime.weekday(.wide).month().day()),
                            emptyTitle: "No items",
                            items: groupedItems[day] ?? [],
                            courseName: store.courseName(for:)
                        )
                        .appCard(padding: 14)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        calendar.shortStandaloneWeekdaySymbols
    }

    private var weekTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else {
            return "Week"
        }

        return "\(first.formatted(.dateTime.month().day())) - \(last.formatted(.dateTime.month().day().year()))"
    }

    private func changeVisibleMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else {
            return
        }

        visibleMonth = newMonth
        selectedDate = newMonth
    }

    private func changeSelectedWeek(by offset: Int) {
        guard let newDate = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else {
            return
        }

        selectedDate = newDate
        visibleMonth = newDate
    }
}

struct EventsView_Previews: PreviewProvider {
    static var previews: some View {
        EventsView()
            .environmentObject(CanvasStore())
    }
}

private struct CalendarDayCell: View {
    let day: Date
    let items: [CalendarEventItem]
    let isSelected: Bool
    let isInVisibleMonth: Bool
    let isToday: Bool
    let onSelect: () -> Void

    private var missingCount: Int {
        items.filter(\.isMissing).count
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 15, weight: isToday ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(dayNumberStyle)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(isToday ? Color.accentColor : Color.clear)
                        )

                    Spacer()
                }

                HStack(spacing: 4) {
                    ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                        Circle()
                            .fill(item.isMissing ? Color.red : Color.blue)
                            .frame(width: 6, height: 6)
                    }

                    if items.count > 4 {
                        Text("+\(items.count - 4)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if missingCount > 0 {
                    Text("\(missingCount) overdue")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(minHeight: 92, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var dayNumberStyle: Color {
        if isToday {
            return .white
        }

        return isInVisibleMonth ? .primary : .secondary
    }

    private var background: Color {
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }

        return isInVisibleMonth ? Color.cardBackground : Color.subtleBackground
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.65)
        }

        return Color.cardBorder
    }
}

private struct WeekDayColumn: View {
    let day: Date
    let items: [CalendarEventItem]
    let isToday: Bool
    let courseName: (Int?) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .foregroundStyle(isToday ? Color.accentColor : Color.secondary)

                    Text(day.formatted(.dateTime.month().day()))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }

                Spacer()

                if isToday {
                    Text("Today")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if items.isEmpty {
                Text("No items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    CompactEventItemRow(item: item, courseName: courseName(item.courseID))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous)
                .fill(isToday ? Color.accentColor.opacity(0.10) : Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous)
                .strokeBorder(isToday ? Color.accentColor.opacity(0.35) : Color.cardBorder, lineWidth: 1)
        )
    }
}

private struct EventItemsPanel: View {
    let title: String
    let emptyTitle: String
    let items: [CalendarEventItem]
    let courseName: (Int?) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text(emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        CompactEventItemRow(item: item, courseName: courseName(item.courseID))

                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct CompactEventItemRow: View {
    let item: CalendarEventItem
    let courseName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.isMissing ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                .foregroundStyle(item.isMissing ? .red : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    PillBadge(text: item.kindLabel, tint: item.isMissing ? .red : .blue)
                }

                HStack(spacing: 8) {
                    if let courseName {
                        Text(courseName)
                    }

                    if let date = item.date {
                        Text(DisplayFormatters.formatted(date: date))
                    } else {
                        Text("No date")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = item.actionableURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.secondary.opacity(0.65))
                }
            }
        }
        .padding(.vertical, 8)
    }
}
