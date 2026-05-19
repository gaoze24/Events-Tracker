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

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "link.badge.plus",
            description: Text(message)
        )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PillBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule())
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
                    DisplayFormatters.formatted(date: event.displayDate, allDay: event.allDay),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let relative = DisplayFormatters.relativeString(date: event.displayDate) {
                    Text(relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                    DisplayFormatters.formatted(date: submission.dueAt),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let relative = DisplayFormatters.relativeString(date: submission.dueAt) {
                    Text(relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                if let url = assignment.htmlURL {
                    Link("Open in Canvas", destination: url)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 8)
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
                    AssignmentDetailMetric(title: "Due", value: DisplayFormatters.formatted(date: assignment.dueAt), systemImage: "clock")
                    AssignmentDetailMetric(title: "Points", value: assignment.pointsDescription.map { "\($0) pts" } ?? "No points", systemImage: "number")
                    AssignmentDetailMetric(title: "Score", value: assignment.scoreDescription ?? "Not scored", systemImage: "checkmark.seal")
                    AssignmentDetailMetric(title: "Grade", value: assignment.gradeDescription ?? "Not graded", systemImage: "graduationcap")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Submission")
                        .font(.title2.weight(.semibold))

                    AssignmentDetailInfoRow(title: "State", value: assignment.submission?.workflowState ?? assignment.status.rawValue)
                    AssignmentDetailInfoRow(title: "Submitted", value: DisplayFormatters.relativeString(date: assignment.submission?.submittedAt) ?? DisplayFormatters.formatted(date: assignment.submission?.submittedAt))
                    AssignmentDetailInfoRow(title: "Graded", value: DisplayFormatters.relativeString(date: assignment.submission?.gradedAt) ?? DisplayFormatters.formatted(date: assignment.submission?.gradedAt))
                    AssignmentDetailInfoRow(title: "Type", value: assignment.submission?.submissionType ?? assignment.submissionTypes?.joined(separator: ", ") ?? "Not specified")
                    AssignmentDetailInfoRow(title: "Attempt", value: assignment.submission?.attempt.map(String.init) ?? "No attempt recorded")
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

                if let htmlURL = assignment.htmlURL {
                    Link("Open in Canvas", destination: htmlURL)
                        .font(.headline)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
