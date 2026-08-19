//
//  ContentView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 24/3/25.
//

import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case search = "Search"
    case sync = "Sync"
    case inbox = "Inbox"
    case assignments = "Assignments"
    case courses = "Courses"
    case events = "Events"
    case downloads = "Downloads"
    case profile = "Profile"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "rectangle.3.group"
        case .search:
            return "magnifyingglass"
        case .sync:
            return "arrow.triangle.2.circlepath"
        case .inbox:
            return "tray"
        case .assignments:
            return "checklist"
        case .courses:
            return "books.vertical"
        case .events:
            return "calendar"
        case .downloads:
            return "arrow.down.circle"
        case .profile:
            return "person.crop.circle"
        case .settings:
            return "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard:
            return .blue
        case .search:
            return .indigo
        case .sync:
            return .teal
        case .inbox:
            return .orange
        case .assignments:
            return .pink
        case .courses:
            return .purple
        case .events:
            return .green
        case .downloads:
            return .cyan
        case .profile:
            return .mint
        case .settings:
            return .gray
        }
    }
}

private enum AppSectionGroup: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case workspace = "Workspace"
    case account = "Account"

    var id: String { rawValue }

    var sections: [AppSection] {
        switch self {
        case .overview:
            return [.dashboard, .search, .sync]
        case .workspace:
            return [.inbox, .assignments, .courses, .events, .downloads]
        case .account:
            return [.profile, .settings]
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var selectedSection: AppSection? = .dashboard
    @AppStorage(AppUIStyle.storageKey) private var appUIStyleRaw = AppUIStyle.vivid.rawValue

    private var appUIStyle: AppUIStyle {
        AppUIStyle(rawValue: appUIStyleRaw) ?? .vivid
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarHeader
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                List(selection: $selectedSection) {
                    ForEach(AppSectionGroup.allCases) { group in
                        Section {
                            ForEach(group.sections) { section in
                                sidebarRow(for: section)
                                    .tag(section)
                            }
                        } header: {
                            Text(group.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .kerning(0.6)
                        }
                    }
                }
            }
            .navigationTitle("Events Tracker")
            .frame(minWidth: 240, idealWidth: 240, maxWidth: 280)
        } detail: {
            VStack(spacing: 0) {
                if let errorMessage = store.errorMessage {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Color.red.opacity(0.10)
                    )
                    .overlay(
                        Rectangle()
                            .fill(Color.red.opacity(0.25))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                }

                Group {
                    switch selectedSection {
                    case .dashboard:
                        HomeView()
                    case .search:
                        GlobalSearchView {
                            selectedSection = .courses
                        }
                    case .sync:
                        SyncCenterView()
                    case .inbox:
                        InboxView()
                    case .assignments:
                        AssignmentsView()
                    case .courses:
                        CoursesView()
                    case .events:
                        EventsView()
                    case .downloads:
                        DownloadsView()
                    case .profile:
                        ProfileView()
                    case .settings:
                        SettingsView()
                    case nil:
                        HomeView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .auroraBackdrop()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await store.refresh()
                        }
                    } label: {
                        if store.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Sync", systemImage: "arrow.clockwise")
                        }
                    }
                    .help(store.isSyncing ? "Syncing Canvas data" : "Sync Canvas data now")
                    .disabled(!store.isConfigured || store.isSyncing)
                }

                ToolbarItem(placement: .automatic) {
                    if let lastSyncDescription = store.lastSyncDescription {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.isSyncing ? Color.blue : Color.green)
                                .frame(width: 7, height: 7)
                            Text("Synced \(lastSyncDescription)")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                    }
                }
            }
        }
        .environment(\.appUIStyle, appUIStyle)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: appUIStyle.isVivid ? 11 : 10, style: .continuous)
                    .fill(
                        appUIStyle.isVivid
                            ? AppTheme.brandGradient
                            : LinearGradient(
                                colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: appUIStyle.isVivid ? 38 : 36, height: appUIStyle.isVivid ? 38 : 36)

                if appUIStyle.isVivid {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        .frame(width: 38, height: 38)
                }

                Image("AppLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: appUIStyle.isVivid ? 23 : 22, height: appUIStyle.isVivid ? 23 : 22)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(appUIStyle.isVivid ? 0.2 : 0), radius: 1, x: 0, y: 1)
            }
            .shadow(color: Color.indigo.opacity(appUIStyle.isVivid ? 0.45 : 0), radius: 8, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("Events Tracker")
                    .font(.headline)

                Text(store.isConfigured ? store.hostLabel : "Not connected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func sidebarRow(for section: AppSection) -> some View {
        HStack(spacing: 10) {
            sidebarIcon(for: section)

            Text(section.rawValue)

            Spacer(minLength: 0)

            if let badge = sidebarBadge(for: section) {
                Text(badge.text)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badge.tint.opacity(0.18))
                    )
                    .foregroundStyle(badge.tint)
            } else if section == .sync && store.isSyncing {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func sidebarIcon(for section: AppSection) -> some View {
        if appUIStyle.isVivid {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [section.tint.opacity(0.95), section.tint.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: section.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            .shadow(color: section.tint.opacity(0.35), radius: 3, x: 0, y: 1)
        } else {
            Image(systemName: section.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(section.tint)
                .frame(width: 20, height: 20)
        }
    }

    private struct SidebarBadge {
        let text: String
        let tint: Color
    }

    private func sidebarBadge(for section: AppSection) -> SidebarBadge? {
        switch section {
        case .inbox:
            let unread = store.inboxConversations.filter(\.isUnread).count
            return unread > 0 ? SidebarBadge(text: "\(unread)", tint: .orange) : nil
        case .assignments:
            let overdue = store.missingSubmissions.count
            return overdue > 0 ? SidebarBadge(text: "\(overdue)", tint: .red) : nil
        case .downloads:
            let inProgress = store.fileDownloadSnapshot.records.filter { $0.state == .downloading }.count
            return inProgress > 0 ? SidebarBadge(text: "\(inProgress)", tint: .cyan) : nil
        default:
            return nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CanvasStore())
    }
}
