//
//  InboxView.swift
//  Events Tracker
//

import SwiftUI

private enum InboxStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unread = "Unread"
    case read = "Read"
    case archived = "Archived"

    var id: String { rawValue }

    func includes(_ conversation: CanvasConversation) -> Bool {
        switch self {
        case .all:
            return true
        case .unread:
            return conversation.workflowState == .unread
        case .read:
            return conversation.workflowState == .read
        case .archived:
            return conversation.workflowState == .archived
        }
    }
}

struct InboxView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var searchQuery = ""
    @State private var statusFilter: InboxStatusFilter = .all
    @State private var selectedCourseID: Int?

    private var conversations: [CanvasConversation] {
        store.inboxConversations
    }

    private var visibleConversations: [CanvasConversation] {
        conversations
            .filter { statusFilter.includes($0) }
            .filter { selectedCourseID == nil || $0.courseIDs.contains(selectedCourseID!) }
            .filter { $0.matchesSearch(searchQuery) }
    }

    private var lastRefreshDescription: String {
        guard let inboxLastLoadedAt = store.inboxLastLoadedAt else {
            return "Not loaded yet"
        }

        return DisplayFormatters.relativeString(date: inboxLastLoadedAt)
            ?? DisplayFormatters.formatted(date: inboxLastLoadedAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inbox")
                            .font(.largeTitle.weight(.semibold))

                        Text("Review and lightly manage Canvas conversations without leaving the app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            await store.refreshInboxConversations()
                        }
                    } label: {
                        if store.loadingInbox {
                            ProgressView()
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(!store.isConfigured || store.loadingInbox)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    SummaryCard(title: "Messages", value: "\(conversations.count)", detail: "Loaded Canvas conversations.", systemImage: "tray", tint: .blue)
                    SummaryCard(title: "Unread", value: "\(conversations.filter(\.isUnread).count)", detail: "Need attention.", systemImage: "envelope.badge", tint: .orange)
                    SummaryCard(title: "Archived", value: "\(conversations.filter(\.isArchived).count)", detail: "Moved out of the active inbox.", systemImage: "archivebox", tint: .secondary)
                    SummaryCard(title: "Last Refresh", value: lastRefreshDescription, detail: "When Inbox was last loaded.", systemImage: "clock", tint: .purple)
                }

                controls

                if !store.isConfigured {
                    SetupPromptView(
                        title: "Connect Canvas",
                        message: "Add your Canvas URL and token in Settings before loading Inbox."
                    )
                } else if store.loadingInbox && conversations.isEmpty {
                    ProgressView("Loading conversations...")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if conversations.isEmpty {
                    SetupPromptView(
                        title: "No Conversations Loaded",
                        message: "Refresh Inbox to load recent Canvas conversations."
                    )
                } else if visibleConversations.isEmpty {
                    SetupPromptView(
                        title: "No Matching Conversations",
                        message: "Change the search, course, or status filters."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleConversations) { conversation in
                            InboxConversationRow(conversation: conversation)

                            if conversation.id != visibleConversations.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(24)
        }
        .task {
            await store.loadInboxConversationsIfNeeded()
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("Search conversations", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240, idealWidth: 320, maxWidth: 420)

            Picker("Course", selection: $selectedCourseID) {
                Text("All Courses")
                    .tag(nil as Int?)

                ForEach(store.preferredCourses()) { course in
                    Text(course.name)
                        .tag(Optional(course.id))
                }
            }
            .frame(width: 220)

            Picker("Status", selection: $statusFilter) {
                ForEach(InboxStatusFilter.allCases) { status in
                    Text(status.rawValue)
                        .tag(status)
                }
            }
            .frame(width: 180)

            Spacer()
        }
    }
}

private struct InboxConversationRow: View {
    @EnvironmentObject private var store: CanvasStore

    let conversation: CanvasConversation

    private var timestampDescription: String? {
        DisplayFormatters.relativeString(date: conversation.lastMessageAt)
            ?? conversation.lastMessageAt.map { DisplayFormatters.formatted(date: $0) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: conversation.isUnread ? "envelope.badge.fill" : "envelope")
                .foregroundStyle(conversation.isUnread ? .orange : .blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conversation.displaySubject)
                        .font(.headline)

                    if conversation.isUnread {
                        PillBadge(text: "Unread", tint: .orange)
                    } else if conversation.isArchived {
                        PillBadge(text: "Archived", tint: .secondary)
                    }
                }

                if let lastMessage = conversation.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Text(conversation.participantSummary)

                    if let contextName = conversation.contextName, !contextName.isEmpty {
                        Text(contextName)
                    }

                    if let messageCount = conversation.messageCount {
                        Label("\(messageCount)", systemImage: "bubble.left.and.bubble.right")
                    }

                    if let timestampDescription {
                        Label(timestampDescription, systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            InboxConversationActions(conversation: conversation)
        }
        .padding(.vertical, 10)
    }
}

private struct InboxConversationActions: View {
    @EnvironmentObject private var store: CanvasStore

    let conversation: CanvasConversation

    var body: some View {
        HStack(spacing: 8) {
            if conversation.isUnread {
                Button("Mark Read") {
                    Task {
                        await store.markConversationRead(conversation)
                    }
                }
                .font(.caption.weight(.semibold))
            } else {
                Button("Mark Unread") {
                    Task {
                        await store.markConversationUnread(conversation)
                    }
                }
                .font(.caption.weight(.semibold))
            }

            if !conversation.isArchived {
                Button("Archive") {
                    Task {
                        await store.archiveConversation(conversation)
                    }
                }
                .font(.caption.weight(.semibold))
            }

            if let url = conversation.canvasURL(baseURL: store.config.normalizedBaseURL) {
                Link("Canvas", destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
    }
}
