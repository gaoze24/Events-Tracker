//
//  GlobalSearchView.swift
//  Events Tracker
//

import SwiftUI

struct GlobalSearchView: View {
    @EnvironmentObject private var store: CanvasStore
    let onNavigateToCourse: () -> Void

    @State private var query = ""
    @State private var selectedKind: GlobalSearchResultKind?

    private var allResults: [GlobalSearchResult] {
        store.globalSearchResults(for: query)
    }

    private var visibleResults: [GlobalSearchResult] {
        allResults.filter { $0.matchesKind(selectedKind) }
    }

    private var topResults: [GlobalSearchResult] {
        guard selectedKind == nil else {
            return []
        }

        return Array(visibleResults.prefix(5))
    }

    private var groupedResults: [(GlobalSearchResultKind, [GlobalSearchResult])] {
        GlobalSearchResultKind.allCases.compactMap { kind in
            let matches = visibleResults.filter { $0.kind == kind }
            return matches.isEmpty ? nil : (kind, matches)
        }
    }

    private var resultCountLabel: String {
        if let selectedKind {
            return "\(visibleResults.count) \(selectedKind.rawValue.lowercased()) result\(visibleResults.count == 1 ? "" : "s")"
        }

        return "\(visibleResults.count) results across \(groupedResults.count) sections"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search")
                        .font(.largeTitle.weight(.semibold))

                    Text("Searches data already synced or loaded in this app, including courses, assignments, modules, files, announcements, people, and cached detail pages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                searchControls

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    recentSearches
                } else if visibleResults.isEmpty {
                    SetupPromptView(
                        title: "No Matching Results",
                        message: "Try another term or load more course sections first. Search only covers currently synced and cached data."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(resultCountLabel)
                            .font(.headline)

                        if !topResults.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Top Results")
                                    .font(.headline)

                                resultSection(topResults)
                            }
                        }

                        ForEach(groupedResults, id: \.0) { kind, results in
                            VStack(alignment: .leading, spacing: 10) {
                                Label(kind.rawValue, systemImage: kind.systemImage)
                                    .font(.headline)

                                resultSection(results)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var searchControls: some View {
        HStack(spacing: 12) {
            TextField("Search everything loaded", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260, idealWidth: 420, maxWidth: 560)
                .onSubmit {
                    store.rememberSearchTerm(query)
                }

            Button("Search") {
                store.rememberSearchTerm(query)
            }
            .keyboardShortcut(.defaultAction)

            Picker("Type", selection: $selectedKind) {
                Text("All Types")
                    .tag(nil as GlobalSearchResultKind?)

                ForEach(GlobalSearchResultKind.allCases) { kind in
                    Text(kind.rawValue)
                        .tag(Optional(kind))
                }
            }
            .frame(width: 180)

            Spacer()
        }
    }

    @ViewBuilder
    private func resultSection(_ results: [GlobalSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(results) { result in
                GlobalSearchResultRow(result: result, onNavigateToCourse: onNavigateToCourse)

                if result.id != results.last?.id {
                    Divider()
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)

                Spacer()

                Button("Clear") {
                    store.clearRecentSearchTerms()
                }
                .disabled(store.recentSearchTerms.isEmpty)
            }

            if store.recentSearchTerms.isEmpty {
                SetupPromptView(
                    title: "Start Searching",
                    message: "Search for a course, assignment, module item, file, announcement, person, or cached detail page."
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(store.recentSearchTerms, id: \.self) { term in
                        Button(term) {
                            query = term
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

private struct GlobalSearchResultRow: View {
    @EnvironmentObject private var store: CanvasStore

    let result: GlobalSearchResult
    let onNavigateToCourse: () -> Void

    private var openLabel: String {
        switch result.kind {
        case .course:
            return "Go to Course"
        case .assignment, .missing, .event:
            return "Open in Canvas"
        case .file:
            return "Open File"
        default:
            return "Open"
        }
    }

    private var showsUseCourseAction: Bool {
        result.kind != .course && result.courseID != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.kind.systemImage)
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(result.title)
                    .font(.headline)

                HStack(spacing: 10) {
                    if let subtitle = result.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                    }

                    if let courseName = result.courseName, !courseName.isEmpty {
                        Text(courseName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if showsUseCourseAction, let courseID = result.courseID {
                Button("Use Course") {
                    store.selectedCourseID = courseID
                    onNavigateToCourse()
                }
                .font(.caption.weight(.semibold))
            }

            if let url = result.url {
                Link(openLabel, destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 10)
    }
}
