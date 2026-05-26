//
//  SharedComponents.swift
//  Events Tracker
//
//  Created by Codex on 13/4/26.
//

import SwiftUI

enum DisplayFormatters {
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func formatted(date: Date?, allDay: Bool = false) -> String {
        guard let date else {
            return "No scheduled date"
        }

        if allDay {
            return dateOnly.string(from: date)
        }

        return dateTime.string(from: date)
    }

    static func rowDateText(date: Date?, allDay: Bool = false) -> String {
        formatted(date: date, allDay: allDay)
    }

    static func relativeString(date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func formattedPoints(_ value: Double?) -> String? {
        guard let value else {
            return nil
        }

        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.1f", value)
    }
}

struct SetupPromptView: View {
    let title: String
    let message: String
    var systemImage: String = "link.badge.plus"
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        MetricCard(
            title: title,
            value: value,
            detail: detail,
            systemImage: systemImage,
            tint: tint
        )
    }
}

struct PillBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.4)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
            )
            .foregroundStyle(tint)
    }
}

struct UpcomingEventRow: View {
    let event: UpcomingEvent
    let courseName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.headline)

                    if let courseName {
                        Text(courseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                PillBadge(
                    text: event.kindLabel,
                    tint: event.isAssignment ? .blue : .green
                )
            }

            HStack(spacing: 12) {
                Label(
                    DisplayFormatters.rowDateText(date: event.displayDate, allDay: event.allDay),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if let url = event.actionableURL {
                    Link("Open in Canvas", destination: url)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct MissingSubmissionRow: View {
    let submission: MissingSubmission
    let courseName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(submission.name)
                        .font(.headline)

                    if let courseName {
                        Text(courseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                PillBadge(text: "Missing", tint: .red)
            }

            HStack(spacing: 12) {
                Label(
                    DisplayFormatters.rowDateText(date: submission.dueAt),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if let url = submission.htmlURL {
                    Link("Open in Canvas", destination: url)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct CourseListRow: View {
    let course: Course
    var isPinned = false
    var isHidden = false
    var isDefault = false
    var isOfflinePriority = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(course.name)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let courseCode = course.courseCode, !courseCode.isEmpty {
                    Text(courseCode)
                        .font(.caption)
                }

                if let termName = course.enrollmentTerm?.name, !termName.isEmpty {
                    Text(termName)
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if isPinned || isHidden || isDefault || isOfflinePriority {
                HStack(spacing: 6) {
                    if isDefault {
                        PillBadge(text: "Default", tint: .blue)
                    }

                    if isPinned {
                        PillBadge(text: "Pinned", tint: .purple)
                    }

                    if isOfflinePriority {
                        PillBadge(text: "Offline", tint: .orange)
                    }

                    if isHidden {
                        PillBadge(text: "Hidden", tint: .gray)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CourseModuleCard: View {
    let module: CourseModule
    var onOpenNativeDetail: ((CourseModuleItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(module.name)
                        .font(.title3.weight(.semibold))

                    HStack(spacing: 10) {
                        if module.visibleItemCount > 0 {
                            Label("\(module.visibleItemCount) items", systemImage: "list.bullet")
                        }

                        if let unlockAt = module.unlockAt {
                            Label(DisplayFormatters.formatted(date: unlockAt), systemImage: "lock.open")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let workflowState = module.workflowState, !workflowState.isEmpty {
                    PillBadge(text: workflowState.capitalized, tint: .blue)
                }
            }

            if module.sortedItems.isEmpty {
                Text("Canvas did not return any visible module items for this module.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(module.sortedItems) { item in
                    CourseModuleItemRow(item: item, onOpenNativeDetail: onOpenNativeDetail)

                    if item.id != module.sortedItems.last?.id {
                        Divider()
                    }
                }
            }
        }
        .appCard()
    }
}

struct CourseModuleItemRow: View {
    let item: CourseModuleItem
    var onOpenNativeDetail: ((CourseModuleItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImageName)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        PillBadge(text: item.itemTypeLabel, tint: .green)

                        if item.isLockedForUser {
                            PillBadge(text: "Locked", tint: .red)
                        }
                    }
                }

                Spacer()

                if item.supportsNativeDetail {
                    Button("Details") {
                        onOpenNativeDetail?(item)
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(onOpenNativeDetail == nil)
                }

                if let url = item.actionableURL {
                    Link("Open", destination: url)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.leading, CGFloat(item.indent ?? 0) * 20)

            HStack(spacing: 12) {
                if let dueAt = item.dueAt {
                    Label(DisplayFormatters.formatted(date: dueAt), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let pointsDescription = item.pointsDescription {
                    Label(pointsDescription, systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lockExplanation = item.contentDetails?.lockExplanation, !lockExplanation.isEmpty {
                    Text(lockExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.leading, CGFloat(item.indent ?? 0) * 20 + 30)
        }
        .padding(.vertical, 6)
    }
}

private extension CourseAssignmentStatus {
    var tint: Color {
        switch self {
        case .missing, .late:
            return .red
        case .graded:
            return .green
        case .submitted, .excused:
            return .blue
        case .upcoming:
            return .orange
        case .unscheduled:
            return .secondary
        }
    }
}

struct CourseAssignmentRow: View {
    let assignment: CourseAssignment
    let courseName: String?
    var showCourseName = false

    private var metadataText: String? {
        if let scoreDescription = assignment.scoreDescription {
            return "Score \(scoreDescription)"
        }

        if let pointsDescription = assignment.pointsDescription {
            return "\(pointsDescription) pts possible"
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(assignment.name)
                        .font(.headline)

                    if showCourseName, let courseName {
                        Text(courseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    PillBadge(text: assignment.status.rawValue, tint: assignment.status.tint)

                    if assignment.submission?.late == true, assignment.status != .late {
                        PillBadge(text: "Late", tint: .red)
                    }
                }
            }

            HStack(spacing: 8) {
                if let relative = DisplayFormatters.relativeString(date: assignment.dueAt) {
                    Text(relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(DisplayFormatters.formatted(date: assignment.dueAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let metadataText {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AssignmentExternalActions(assignment: assignment)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AssignmentExternalActions: View {
    let assignment: CourseAssignment
    var font: Font = .caption.weight(.semibold)

    var body: some View {
        HStack(spacing: 10) {
            if assignment.showsSubmissionAction, let submissionURL = assignment.submissionURL {
                Link(assignment.submissionActionTitle, destination: submissionURL)
                    .font(font)
            }

            if let canvasURL = assignment.canvasURL {
                Link("Open in Canvas", destination: canvasURL)
                    .font(font)
            }
        }
    }
}

struct AssignmentCompactActions: View {
    let assignment: CourseAssignment

    var body: some View {
        HStack(spacing: 8) {
            if assignment.showsSubmissionAction, let submissionURL = assignment.submissionURL {
                Link(destination: submissionURL) {
                    Image(systemName: assignment.submissionActionTitle == "View Submission" ? "doc.text.magnifyingglass" : "paperplane")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }
                .help(assignment.submissionActionTitle)
            }

            if let canvasURL = assignment.canvasURL {
                Link(destination: canvasURL) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .font(.caption)
                }
                .help("Open in Canvas")
            }
        }
    }
}

struct AssignmentDetailView: View {
    let assignment: CourseAssignment
    let courseName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(assignment.name)
                            .font(.largeTitle.weight(.semibold))

                        if let courseName {
                            Text(courseName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    PillBadge(text: assignment.status.rawValue, tint: assignment.status.tint)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    AssignmentDetailMetric(title: "Due", value: DisplayFormatters.formatted(date: assignment.dueAt), systemImage: "clock", tint: .blue)
                    AssignmentDetailMetric(title: "Points", value: assignment.pointsDescription.map { "\($0) pts" } ?? "No points", systemImage: "number", tint: .purple)
                    AssignmentDetailMetric(title: "Score", value: assignment.scoreDescription ?? "Not scored", systemImage: "checkmark.seal", tint: .green)
                    AssignmentDetailMetric(title: "Grade", value: assignment.gradeDescription ?? "Not graded", systemImage: "graduationcap", tint: .orange)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Submission")
                        .font(.title2.weight(.semibold))

                    AssignmentDetailInfoRow(title: "State", value: assignment.submission?.workflowState ?? assignment.status.rawValue)
                    AssignmentDetailInfoRow(title: "Submitted", value: DisplayFormatters.relativeString(date: assignment.submission?.submittedAt) ?? DisplayFormatters.formatted(date: assignment.submission?.submittedAt))
                    AssignmentDetailInfoRow(title: "Graded", value: DisplayFormatters.relativeString(date: assignment.submission?.gradedAt) ?? DisplayFormatters.formatted(date: assignment.submission?.gradedAt))
                    AssignmentDetailInfoRow(title: "Type", value: assignment.submission?.submissionType ?? assignment.submissionTypes?.joined(separator: ", ") ?? "Not specified")
                    AssignmentDetailInfoRow(title: "Attempt", value: assignment.submission?.attempt.map(String.init) ?? "No attempt recorded")

                    AssignmentExternalActions(assignment: assignment, font: .headline)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Availability")
                        .font(.title2.weight(.semibold))

                    AssignmentDetailInfoRow(title: "Unlocks", value: DisplayFormatters.formatted(date: assignment.unlockAt))
                    AssignmentDetailInfoRow(title: "Locks", value: DisplayFormatters.formatted(date: assignment.lockAt))
                    AssignmentDetailInfoRow(title: "Published", value: assignment.published == false ? "No" : "Yes")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.title2.weight(.semibold))

                    Text(assignment.summaryText ?? "No assignment description available.")
                        .foregroundStyle(assignment.summaryText == nil ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

private struct AssignmentDetailMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(value)
                    .font(.headline)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 14)
    }
}

private struct AssignmentDetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }
}
