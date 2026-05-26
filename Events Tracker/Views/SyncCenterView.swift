//
//  SyncCenterView.swift
//  Events Tracker
//

import SwiftUI

struct SyncCenterView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var isPreloadingOfflineCourses = false
    @State private var refreshingCourseID: Int?
    @State private var offlineSelection = OfflineDownloadSelection()

    private var inventory: LocalDataInventory {
        store.localDataInventory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summaryCards
                actions
                offlineDownloadPlanner
                courseReadinessSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        ScreenHeader(
            title: "Sync Center",
            subtitle: "Review local cache health, prepare course metadata for offline use, and clear local data selectively."
        ) {
            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                if store.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Sync Dashboard", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
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

    private var offlineDownloadPlanner: some View {
        OfflineDownloadPlannerView(selection: $offlineSelection)
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
                .appCard(padding: 16)
            }
        }
    }
}

private struct OfflineDownloadPlannerView: View {
    @EnvironmentObject private var store: CanvasStore
    @Binding var selection: OfflineDownloadSelection
    @State private var selectedCourseID: Int?
    @State private var isLoadingMetadata = false

    private var preferredCourses: [Course] {
        store.preferredCourses()
    }

    private var preferredCourseIDs: [Int] {
        preferredCourses.map(\.id)
    }

    private var selectedCourse: Course? {
        guard let selectedCourseID else {
            return nil
        }

        return preferredCourses.first(where: { course in
            course.id == selectedCourseID
        })
    }

    private var selectedCourseIDBinding: Binding<Int?> {
        Binding(
            get: { selectedCourseID },
            set: { selectedCourseID = $0 }
        )
    }

    private var selectedCourseIDValue: Int? {
        selectedCourseID.flatMap { courseID in
            preferredCourses.first(where: { $0.id == courseID })
        }?.id
    }

    private var folders: [CanvasFolder] {
        store.folders(for: selectedCourse?.id)
    }

    private var plan: OfflineDownloadPlan {
        store.offlineDownloadPlan(selection: selection)
    }

    private var isDownloadingPlan: Bool {
        store.offlineBulkDownloadProgress?.isComplete == false
    }

    private var hasSelection: Bool {
        !selection.selectedCourseIDs.isEmpty
            || !selection.selectedFolderIDs.isEmpty
            || !selection.selectedFileIDs.isEmpty
    }

    private var isSelectedCourseSelected: Bool {
        selectedCourse.map { selection.selectedCourseIDs.contains($0.id) } ?? false
    }

    private var skippedBreakdownDetail: String {
        let alreadyDownloaded = plan.skippedCount(for: .alreadyDownloaded)
        let alreadyDownloading = plan.skippedCount(for: .alreadyDownloading)
        let unavailable = plan.skippedCount(for: .unavailable)
        let missingDownloadURL = plan.skippedCount(for: .missingDownloadURL)

        return "Downloaded \(alreadyDownloaded) · Downloading \(alreadyDownloading) · Unavailable \(unavailable) · Missing URL \(missingDownloadURL)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Offline Download Planner")
                        .font(.title2.weight(.semibold))

                    Text("Choose course files to download for offline use. Metadata preload remains separate from file downloads.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await loadMetadata()
                    }
                } label: {
                    if isLoadingMetadata {
                        ProgressView()
                    } else {
                        Text("Load Metadata")
                    }
                }
                .disabled(!store.isConfigured || selectedCourse == nil || isLoadingMetadata)
            }

            plannerControls
            plannerProgressSummary
            plannerSummary
            plannerTree
        }
        .onAppear {
            normalizeSelectedCourseID()
        }
        .onChange(of: preferredCourseIDs) {
            normalizeSelectedCourseID()
        }
    }

    private var plannerControls: some View {
        HStack(spacing: 12) {
            Picker("Course", selection: selectedCourseIDBinding) {
                ForEach(preferredCourses) { course in
                    Text(course.name)
                        .tag(Optional(course.id))
                }
            }
            .frame(width: 260)
            .disabled(preferredCourses.isEmpty)

            Button("Select Course Files") {
                if let courseID = selectedCourse?.id {
                    selection.selectedCourseIDs.insert(courseID)
                }
            }
            .disabled(selectedCourse == nil)

            Button("Clear Selection") {
                selection = OfflineDownloadSelection()
            }
            .disabled(!hasSelection)

            Spacer()

            Button {
                Task {
                    await store.downloadOfflinePlan(plan)
                }
            } label: {
                if let progress = store.offlineBulkDownloadProgress, !progress.isComplete {
                    Text("\(progress.processedCount)/\(progress.totalCount)")
                } else {
                    Text("Download Selected")
                }
            }
            .disabled(!store.isConfigured || plan.isEmpty || isDownloadingPlan)
        }
    }

    private var plannerSummary: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            OfflinePlannerSummaryCard(
                title: "Selected",
                value: "\(plan.fileCount)",
                detail: "Files queued for download.",
                systemImage: "checklist",
                tint: .blue
            )
            OfflinePlannerSummaryCard(
                title: "Estimated",
                value: ByteCountFormatter.string(fromByteCount: Int64(plan.estimatedByteCount), countStyle: .file),
                detail: "\(plan.unknownSizeCount) unknown-size files.",
                systemImage: "externaldrive",
                tint: .purple
            )
            OfflinePlannerSummaryCard(
                title: "Skipped",
                value: "\(plan.skippedCount)",
                detail: skippedBreakdownDetail,
                systemImage: "forward.end",
                tint: .orange
            )
            OfflinePlannerSummaryCard(
                title: "Limit",
                value: store.localDataInventory.downloadCacheLimitLabel,
                detail: "Downloaded: \(ByteCountFormatter.string(fromByteCount: Int64(store.fileDownloadSnapshot.downloadedByteCount), countStyle: .file)).",
                systemImage: "gauge",
                tint: .green
            )
        }
    }

    @ViewBuilder
    private var plannerProgressSummary: some View {
        if let progress = store.offlineBulkDownloadProgress {
            HStack(spacing: 8) {
                Label("Completed \(progress.completedCount) · Failed \(progress.failedCount) · Skipped \(progress.skippedCount)", systemImage: "arrow.down.circle")

                Spacer()

                Text("\(progress.processedCount)/\(progress.totalCount) processed")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
        }
    }

    private var plannerTree: some View {
        VStack(alignment: .leading, spacing: 0) {
            if selectedCourse == nil {
                SetupPromptView(
                    title: "No Course Selected",
                    message: "Sync courses before planning offline downloads."
                )
                .frame(minHeight: 180)
            } else if folders.isEmpty {
                SetupPromptView(
                    title: "No File Metadata Loaded",
                    message: "Load metadata for this course before selecting files."
                )
                .frame(minHeight: 180)
            } else {
                ForEach(folders) { folder in
                    OfflineFolderSelectionRow(
                        folder: folder,
                        files: store.files(for: folder.id),
                        isCourseSelected: isSelectedCourseSelected,
                        selection: $selection
                    )

                    if folder.id != folders.last?.id {
                        Divider()
                    }
                }
            }
        }
        .appCard(padding: 16)
    }

    private func loadMetadata() async {
        guard let courseID = selectedCourse?.id else {
            return
        }

        isLoadingMetadata = true
        await store.preloadCourseMetadata(courseID: courseID)
        isLoadingMetadata = false
    }

    private func normalizeSelectedCourseID() {
        guard !preferredCourseIDs.isEmpty else {
            selectedCourseID = nil
            return
        }

        if let selectedCourseIDValue {
            selectedCourseID = selectedCourseIDValue
        } else {
            selectedCourseID = preferredCourseIDs.first
        }
    }
}

private struct OfflinePlannerSummaryCard: View {
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

private struct OfflineFolderSelectionRow: View {
    let folder: CanvasFolder
    let files: [CanvasFile]
    let isCourseSelected: Bool
    @Binding var selection: OfflineDownloadSelection

    private var isFolderSelected: Bool {
        selection.selectedFolderIDs.contains(folder.id)
    }

    private var isSelected: Bool {
        isCourseSelected || isFolderSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    toggleFolder()
                } label: {
                    Label(folder.displayName, systemImage: isSelected ? "checkmark.square" : "square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isCourseSelected ? .secondary : .primary)
                .disabled(isCourseSelected)

                Spacer()

                Text("\(files.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isCourseSelected {
                    PillBadge(text: "Course Selected", tint: .blue)
                }
            }

            ForEach(files) { file in
                OfflineFileSelectionRow(
                    file: file,
                    isCourseSelected: isCourseSelected,
                    selection: $selection
                )
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 10)
    }

    private func toggleFolder() {
        if isFolderSelected {
            selection.selectedFolderIDs.remove(folder.id)
        } else {
            selection.selectedFolderIDs.insert(folder.id)
        }
    }
}

private struct OfflineFileSelectionRow: View {
    @EnvironmentObject private var store: CanvasStore

    let file: CanvasFile
    let isCourseSelected: Bool
    @Binding var selection: OfflineDownloadSelection

    private var isExplicitlySelected: Bool {
        selection.selectedFileIDs.contains(file.id)
    }

    private var isInheritedSelection: Bool {
        file.folderID.map(selection.selectedFolderIDs.contains) == true
    }

    private var isSelected: Bool {
        isExplicitlySelected || isInheritedSelection || isCourseSelected
    }

    private var statusBadges: [OfflineFileStatusBadge] {
        var badges: [OfflineFileStatusBadge] = []
        let record = store.downloadRecord(for: file)

        if file.isUnavailable {
            badges.append(OfflineFileStatusBadge(text: "Unavailable", tint: .orange))
        }

        if record?.state == .downloaded {
            badges.append(OfflineFileStatusBadge(text: "Downloaded", tint: .green))
        }

        if record?.state == .downloading || store.isDownloading(file) {
            badges.append(OfflineFileStatusBadge(text: "Downloading", tint: .blue))
        }

        if file.url == nil {
            badges.append(OfflineFileStatusBadge(text: "Missing URL", tint: .red))
        }

        return badges
    }

    private var isSkippedByPlan: Bool {
        !statusBadges.isEmpty
    }

    private var isReadOnly: Bool {
        isCourseSelected || isInheritedSelection || isSkippedByPlan
    }

    var body: some View {
        HStack {
            Button {
                toggleFile()
            } label: {
                Label(file.name, systemImage: isSelected ? "checkmark.square" : "square")
            }
            .buttonStyle(.plain)
            .foregroundStyle(isReadOnly ? .secondary : .primary)
            .disabled(isReadOnly)

            Spacer()

            if let sizeDescription = file.sizeDescription {
                Text(sizeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isCourseSelected {
                PillBadge(text: "Course Selected", tint: .blue)
            } else if isInheritedSelection {
                PillBadge(text: "Folder Selected", tint: .blue)
            }

            ForEach(statusBadges) { badge in
                PillBadge(text: badge.text, tint: badge.tint)
            }
        }
    }

    private func toggleFile() {
        if selection.selectedFileIDs.contains(file.id) {
            selection.selectedFileIDs.remove(file.id)
        } else {
            selection.selectedFileIDs.insert(file.id)
        }
    }
}

private struct OfflineFileStatusBadge: Identifiable {
    let text: String
    let tint: Color

    var id: String { text }
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
