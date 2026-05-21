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
}

struct ContentView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var selectedSection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("Events Tracker")
            .frame(minWidth: 220, idealWidth: 220, maxWidth: 250)
        } detail: {
            VStack(spacing: 0) {
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.10))
                }

                Group {
                    switch selectedSection {
                    case .dashboard:
                        HomeView()
                    case .search:
                        GlobalSearchView {
                            selectedSection = .courses
                        }
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await store.refresh()
                        }
                    } label: {
                        if store.isSyncing {
                            ProgressView()
                        } else {
                            Label("Sync", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(!store.isConfigured || store.isSyncing)
                }

                ToolbarItem(placement: .automatic) {
                    if let lastSyncDescription = store.lastSyncDescription {
                        Text("Last synced \(lastSyncDescription)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CanvasStore())
    }
}
