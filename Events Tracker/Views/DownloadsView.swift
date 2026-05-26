//
//  DownloadsView.swift
//  Events Tracker
//

import SwiftUI

private enum DownloadStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case downloaded = "Downloaded"
    case downloading = "Downloading"
    case failed = "Failed"
    case notDownloaded = "Not Downloaded"

    var id: String { rawValue }

    func includes(_ record: FileDownloadRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .downloaded:
            return record.state == .downloaded
        case .downloading:
            return record.state == .downloading
        case .failed:
            return record.state == .failed
        case .notDownloaded:
            return record.state == .notDownloaded
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject private var store: CanvasStore
    @State private var searchQuery = ""
    @State private var statusFilter: DownloadStatusFilter = .all
    @State private var selectedCourseID: Int?
    @State private var selectedType = "All"
    @State private var previewItem: QuickLookPreviewItem?

    private var records: [FileDownloadRecord] {
        store.fileDownloadSnapshot.records
    }

    private var visibleRecords: [FileDownloadRecord] {
        records
            .filter { statusFilter.includes($0) }
            .filter { selectedCourseID == nil || $0.courseID == selectedCourseID }
            .filter { selectedType == "All" || $0.typeLabel == selectedType }
            .filter { $0.matchesSearch(searchQuery, courseName: $0.courseID.flatMap(store.courseName(for:))) }
    }

    private var typeOptions: [String] {
        ["All"] + Array(Set(records.map(\.typeLabel))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    title: "Downloads",
                    subtitle: "Files you have seen or downloaded from loaded Canvas course folders."
                ) {
                    Button("Clear Downloaded Files", role: .destructive) {
                        store.clearDownloadedFiles()
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.fileDownloadSnapshot.downloadedRecords.isEmpty)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    SummaryCard(title: "Known Files", value: "\(records.count)", detail: "Files seen while browsing courses.", systemImage: "doc", tint: .blue)
                    SummaryCard(title: "Downloaded", value: "\(records.filter { $0.state == .downloaded }.count)", detail: "Available locally.", systemImage: "arrow.down.circle", tint: .green)
                    SummaryCard(title: "Failed", value: "\(records.filter { $0.state == .failed }.count)", detail: "Downloads that need attention.", systemImage: "exclamationmark.triangle", tint: .red)
                    SummaryCard(
                        title: "Storage",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(store.fileDownloadSnapshot.downloadedByteCount),
                            countStyle: .file
                        ),
                        detail: "Limit: \(store.localDataInventory.downloadCacheLimitLabel).",
                        systemImage: "externaldrive",
                        tint: .purple
                    )
                }

                controls

                if records.isEmpty {
                    SetupPromptView(
                        title: "No Files Seen Yet",
                        message: "Open a course Files tab to load Canvas folders and files. Downloads will appear here after that."
                    )
                } else if visibleRecords.isEmpty {
                    SetupPromptView(
                        title: "No Matching Downloads",
                        message: "Change the search, course, type, or status filters."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleRecords) { record in
                            DownloadRecordRow(record: record, onPreview: previewRecord)

                            if record.id != visibleRecords.last?.id {
                                Divider()
                            }
                        }
                    }
                    .appCard(padding: 16)
                }
            }
            .padding(24)
        }
        .sheet(item: $previewItem) { item in
            QuickLookPreviewSheet(item: item)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("Search downloads", text: $searchQuery)
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

            Picker("Type", selection: $selectedType) {
                ForEach(typeOptions, id: \.self) { type in
                    Text(type)
                        .tag(type)
                }
            }
            .frame(width: 160)

            Picker("Status", selection: $statusFilter) {
                ForEach(DownloadStatusFilter.allCases) { status in
                    Text(status.rawValue)
                        .tag(status)
                }
            }
            .frame(width: 180)

            Spacer()
        }
    }

    private func previewRecord(_ record: FileDownloadRecord) {
        guard let url = store.quickLookURL(for: record) else {
            return
        }

        previewItem = QuickLookPreviewItem(url: url, title: record.file.name)
    }
}

private struct DownloadRecordRow: View {
    @EnvironmentObject private var store: CanvasStore

    let record: FileDownloadRecord
    let onPreview: (FileDownloadRecord) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.state == .downloaded ? "doc.fill" : "doc")
                .foregroundStyle(tint)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(record.file.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    PillBadge(text: record.state.label, tint: tint)

                    if let courseName = record.courseID.flatMap(store.courseName(for:)) {
                        Text(courseName)
                    }

                    Text(record.typeLabel)

                    if let displaySize = record.displaySize {
                        Text(displaySize)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let failureMessage = record.failureMessage, record.state == .failed {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            DownloadActions(record: record, onPreview: onPreview)
        }
        .padding(.vertical, 10)
    }

    private var tint: Color {
        switch record.state {
        case .downloaded:
            return .green
        case .downloading:
            return .blue
        case .failed:
            return .red
        case .notDownloaded:
            return .secondary
        }
    }
}

struct DownloadActions: View {
    @EnvironmentObject private var store: CanvasStore

    let record: FileDownloadRecord
    let onPreview: (FileDownloadRecord) -> Void

    init(record: FileDownloadRecord, onPreview: @escaping (FileDownloadRecord) -> Void = { _ in }) {
        self.record = record
        self.onPreview = onPreview
    }

    var body: some View {
        HStack(spacing: 8) {
            if record.state == .downloaded {
                Button("Preview") {
                    onPreview(record)
                }
                .font(.caption.weight(.semibold))

                Button("Open") {
                    store.openDownloadedFile(record)
                }
                .font(.caption.weight(.semibold))

                Button("Reveal") {
                    store.revealDownloadedFile(record)
                }
                .font(.caption.weight(.semibold))

                Button("Remove", role: .destructive) {
                    store.removeDownloadedFile(record)
                }
                .font(.caption.weight(.semibold))
            } else {
                Button(record.state == .failed ? "Retry" : "Download") {
                    Task {
                        await store.retryDownload(record)
                    }
                }
                .font(.caption.weight(.semibold))
                .disabled(record.state == .downloading)
            }

            if let url = record.file.actionableURL {
                Link("Canvas", destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
    }
}
