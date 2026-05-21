//
//  SyncCenterView.swift
//  Events Tracker
//

import SwiftUI

struct SyncCenterView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var isPreloadingOfflineCourses = false
    @State private var refreshingCourseID: Int?

    private var inventory: LocalDataInventory {
        store.localDataInventory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summaryCards
                actions
                courseReadinessSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Center")
                    .font(.largeTitle.weight(.semibold))

                Text("Review local cache health, prepare course metadata for offline use, and clear local data selectively.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                if store.isSyncing {
                    ProgressView()
                } else {
                    Label("Sync Dashboard", systemImage: "arrow.clockwise")
                }
            }
            .disabled(!store.isConfigured || store.isSyncing)
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            SummaryCard(
                title: "Dashboard",
                value: inventory.lastDashboardSync.map { DisplayFormatters.relativeFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "Never",
                detail: "Last successful dashboard sync.",
                systemImage: "rectangle.3.group",
                tint: .blue
            )
            SummaryCard(
                title: "Course Cache",
                value: "\(inventory.courseDetailCourseCount)",
                detail: "Courses with cached detail metadata.",
                systemImage: "externaldrive",
                tint: .purple
            )
            SummaryCard(
                title: "Downloads",
                value: ByteCountFormatter.string(fromByteCount: Int64(inventory.downloadedByteCount), countStyle: .file),
                detail: "\(inventory.downloadedFileCount) downloaded of \(inventory.knownFileCount) known files. Limit: \(inventory.downloadCacheLimitLabel).",
                systemImage: "arrow.down.circle",
                tint: .green
            )
            SummaryCard(
                title: "Offline Priority",
                value: "\(inventory.offlinePriorityCourseCount)",
                detail: "Courses protected and preloaded for offline review.",
                systemImage: "pin",
                tint: .orange
            )
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.title2.weight(.semibold))

            HStack(spacing: 12) {
                Button {
                    Task {
                        isPreloadingOfflineCourses = true
                        await store.preloadOfflinePriorityCourseMetadata()
                        isPreloadingOfflineCourses = false
                    }
                } label: {
                    if isPreloadingOfflineCourses {
                        ProgressView()
                    } else {
                        Label("Preload Offline Courses", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(!store.isConfigured || inventory.offlinePriorityCourseCount == 0 || isPreloadingOfflineCourses)

                Button("Clear Dashboard Cache", role: .destructive) {
                    store.clearDashboardCache()
                }
                .disabled(inventory.lastDashboardSync == nil)

                Button("Clear Course Detail Cache", role: .destructive) {
                    store.clearCourseDetailCache()
                }
                .disabled(inventory.courseDetailCourseCount == 0)

                Button("Clear Downloads", role: .destructive) {
                    store.clearDownloadedFiles()
                }
                .disabled(inventory.downloadedFileCount == 0)

                Button("Clear All Local Data", role: .destructive) {
                    store.clearLocalData()
                }
            }

            Text("Preloading stores course metadata only. File bodies are downloaded only when you use the existing Download action.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var courseReadinessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Course Offline Readiness")
                    .font(.title2.weight(.semibold))

                Spacer()

                Text("\(store.courseOfflineReadiness.filter(\.isFullyCached).count) ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if store.courseOfflineReadiness.isEmpty {
                SetupPromptView(
                    title: "No Courses Loaded",
                    message: "Sync the dashboard before preparing courses for offline use."
                )
                .frame(minHeight: 260)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.courseOfflineReadiness) { readiness in
                        CourseOfflineReadinessRow(
                            readiness: readiness,
                            isPreloading: store.preloadingCourseIDs.contains(readiness.courseID)
                                || refreshingCourseID == readiness.courseID,
                            onTogglePriority: {
                                store.toggleOfflinePriorityCourse(readiness.courseID)
                            },
                            onRefresh: {
                                Task {
                                    refreshingCourseID = readiness.courseID
                                    await store.preloadCourseMetadata(courseID: readiness.courseID)
                                    refreshingCourseID = nil
                                }
                            }
                        )

                        if readiness.id != store.courseOfflineReadiness.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct CourseOfflineReadinessRow: View {
    let readiness: CourseOfflineReadiness
    let isPreloading: Bool
    let onTogglePriority: () -> Void
    let onRefresh: () -> Void

    private var statusTint: Color {
        readiness.isFullyCached ? .green : .orange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: readiness.isFullyCached ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(statusTint)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(readiness.courseName)
                        .font(.headline)

                    if readiness.isOfflinePriority {
                        PillBadge(text: "Offline Priority", tint: .orange)
                    }

                    PillBadge(
                        text: "\(readiness.cachedSectionCount)/\(readiness.totalSectionCount) cached",
                        tint: statusTint
                    )
                }

                HStack(spacing: 8) {
                    readinessBadge("Assignments", readiness.hasAssignments)
                    readinessBadge("Modules", readiness.hasModules)
                    readinessBadge("Files", readiness.hasFilesMetadata)
                    readinessBadge("Announcements", readiness.hasAnnouncements)
                    readinessBadge("Syllabus", readiness.hasSyllabus)
                    readinessBadge("People", readiness.hasPeople)
                }

                if let lastAccessedAt = readiness.lastAccessedAt {
                    Text("Last cached \(DisplayFormatters.relativeFormatter.localizedString(for: lastAccessedAt, relativeTo: Date()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(readiness.isOfflinePriority ? "Unmark Priority" : "Mark Priority") {
                    onTogglePriority()
                }

                Button {
                    onRefresh()
                } label: {
                    if isPreloading {
                        ProgressView()
                    } else {
                        Text("Refresh Metadata")
                    }
                }
                .disabled(isPreloading)
            }
        }
        .padding(.vertical, 10)
    }

    private func readinessBadge(_ title: String, _ isCached: Bool) -> some View {
        Label(title, systemImage: isCached ? "checkmark.circle" : "circle")
            .font(.caption)
            .foregroundStyle(isCached ? .secondary : .tertiary)
    }
}
