//
//  ModuleItemDetailView.swift
//  Events Tracker
//

import SwiftUI

struct ModuleItemDetailView: View {
    let item: CourseModuleItem
    let detail: CourseModuleItemDetail?
    let isLoading: Bool
    let courseName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if isLoading && detail == nil {
                    ProgressView("Loading \(item.itemTypeLabel.lowercased()) details...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 32)
                } else if let detail {
                    detailContent(detail)
                } else {
                    SetupPromptView(
                        title: "Details Not Available",
                        message: "Events Tracker could not load a native detail view for this module item. You can still open it in Canvas."
                    )
                }

                if let url = item.actionableURL {
                    Link("Open in Canvas", destination: url)
                        .font(.headline)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImageName)
                    .foregroundStyle(.secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.largeTitle.weight(.semibold))

                    Text(courseName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                PillBadge(text: item.itemTypeLabel, tint: .green)
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: CourseModuleItemDetail) -> some View {
        switch detail {
        case .quiz(let quiz):
            quizContent(quiz)
        case .discussion(let discussion):
            discussionContent(discussion)
        case .page(let page):
            pageContent(page)
        }
    }

    private func quizContent(_ quiz: CourseQuizDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                DetailMetric(title: "Due", value: DisplayFormatters.formatted(date: quiz.dueAt), systemImage: "clock")
                DetailMetric(title: "Points", value: formattedPoints(quiz.pointsPossible), systemImage: "number")
                DetailMetric(title: "Questions", value: quiz.questionCount.map(String.init) ?? "Not provided", systemImage: "questionmark.circle")
                DetailMetric(title: "Attempts", value: attemptsLabel(quiz.allowedAttempts), systemImage: "arrow.counterclockwise")
                DetailMetric(title: "Time Limit", value: quiz.timeLimit.map { "\($0) min" } ?? "Not timed", systemImage: "timer")
                DetailMetric(title: "Type", value: quiz.quizType?.capitalized ?? "Quiz", systemImage: "checklist")
            }

            statusBadges(published: quiz.published, locked: quiz.lockedForUser)

            DetailBody(title: "Description", text: quiz.summaryText)
        }
    }

    private func discussionContent(_ discussion: CourseDiscussionDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                DetailMetric(title: "Author", value: discussion.authorName ?? "Not provided", systemImage: "person")
                DetailMetric(title: "Posted", value: DisplayFormatters.formatted(date: discussion.postedAt), systemImage: "clock")
                DetailMetric(title: "Replies", value: discussion.discussionSubentryCount.map(String.init) ?? "Not provided", systemImage: "bubble.left.and.bubble.right")
                DetailMetric(title: "Unread", value: discussion.unreadCount.map(String.init) ?? "Not provided", systemImage: "circle")
            }

            HStack(spacing: 8) {
                if discussion.pinned == true {
                    PillBadge(text: "Pinned", tint: .blue)
                }

                if discussion.requireInitialPost == true {
                    PillBadge(text: "Initial Post Required", tint: .orange)
                }
            }

            statusBadges(published: discussion.published, locked: discussion.locked == true || discussion.lockedForUser == true)

            DetailBody(title: "Discussion", text: discussion.summaryText)
        }
    }

    private func pageContent(_ page: CoursePageDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                DetailMetric(title: "Created", value: DisplayFormatters.formatted(date: page.createdAt), systemImage: "calendar")
                DetailMetric(title: "Updated", value: DisplayFormatters.formatted(date: page.updatedAt), systemImage: "clock")
            }

            HStack(spacing: 8) {
                if page.frontPage == true {
                    PillBadge(text: "Front Page", tint: .blue)
                }
                statusBadges(published: page.published, locked: false)
            }

            DetailBody(title: "Page", text: page.summaryText)
        }
    }

    @ViewBuilder
    private func statusBadges(published: Bool?, locked: Bool?) -> some View {
        HStack(spacing: 8) {
            PillBadge(text: published == false ? "Unpublished" : "Published", tint: published == false ? .orange : .green)

            if locked == true {
                PillBadge(text: "Locked", tint: .red)
            }
        }
    }

    private func formattedPoints(_ points: Double?) -> String {
        guard let points else {
            return "No points"
        }

        if points.rounded() == points {
            return "\(Int(points)) pts"
        }

        return String(format: "%.1f pts", points)
    }

    private func attemptsLabel(_ attempts: Int?) -> String {
        guard let attempts else {
            return "Not provided"
        }

        return attempts < 0 ? "Unlimited" : "\(attempts)"
    }
}

private struct DetailMetric: View {
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
        .appCard(padding: 14)
    }
}

private struct DetailBody: View {
    let title: String
    let text: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(text ?? "Canvas did not return visible body content for this item.")
                .foregroundStyle(text == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
