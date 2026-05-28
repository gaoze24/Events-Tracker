//
//  GlobalSearchView.swift
//  Events Tracker
//

import SwiftUI

struct GlobalSearchQueryState {
    private(set) var draftQuery = ""
    private(set) var submittedQuery = ""

    var activeQuery: String? {
        guard !shouldShowRecentSearches, !shouldShowPendingSearchPrompt else {
            return nil
        }

        return submittedQuery
    }

    var shouldShowRecentSearches: Bool {
        trimmedDraftQuery.isEmpty
    }

    var shouldShowPendingSearchPrompt: Bool {
        !trimmedDraftQuery.isEmpty && trimmedDraftQuery != submittedQuery
    }

    mutating func updateDraftQuery(_ query: String) {
        draftQuery = query

        if trimmedDraftQuery.isEmpty {
            submittedQuery = ""
        }
    }

    mutating func submitSearch() {
        let trimmedQuery = trimmedDraftQuery
        draftQuery = trimmedQuery
        submittedQuery = trimmedQuery
    }

    mutating func useRecentSearchTerm(_ term: String) {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        draftQuery = trimmedTerm
        submittedQuery = trimmedTerm
    }

    private var trimmedDraftQuery: String {
        draftQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GlobalSearchDisplayState {
    let visibleResults: [GlobalSearchResult]
    let topResults: [GlobalSearchResult]
    let groupedResults: [(GlobalSearchResultKind, [GlobalSearchResult])]
    let resultCountLabel: String

    init(results: [GlobalSearchResult], selectedKind: GlobalSearchResultKind?) {
        let filteredResults = results.filter { $0.matchesKind(selectedKind) }
        visibleResults = filteredResults

        if let selectedKind {
            topResults = []
            groupedResults = GlobalSearchResultKind.allCases.compactMap { kind in
                guard kind == selectedKind else {
                    return nil
                }

                return filteredResults.isEmpty ? nil : (kind, filteredResults)
            }
            resultCountLabel = "\(filteredResults.count) \(selectedKind.rawValue.lowercased()) result\(filteredResults.count == 1 ? "" : "s")"
            return
        }

        let top = Array(filteredResults.prefix(5))
        topResults = top
        let topResultIDs = Set(top.map(\.id))
        let sectionResults = filteredResults.filter { !topResultIDs.contains($0.id) }
        let resultsByKind = Dictionary(grouping: sectionResults, by: \.kind)
        groupedResults = GlobalSearchResultKind.allCases.compactMap { kind in
            let matches = resultsByKind[kind] ?? []
            return matches.isEmpty ? nil : (kind, matches)
        }
        let sectionCount = groupedResults.count + (top.isEmpty ? 0 : 1)
        resultCountLabel = "\(filteredResults.count) results across \(sectionCount) sections"
    }
}

struct GlobalSearchView: View {
    @EnvironmentObject private var store: CanvasStore
    let onNavigateToCourse: () -> Void

    @State private var searchState = GlobalSearchQueryState()
    @State private var selectedKind: GlobalSearchResultKind?

    var body: some View {
        let activeQuery = searchState.activeQuery
        let displayState = activeQuery.map { query in
            GlobalSearchDisplayState(
                results: store.globalSearchResults(for: query),
                selectedKind: selectedKind
            )
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    title: "Search",
                    subtitle: "Searches data already synced or loaded in this app, including courses, assignments, modules, files, announcements, people, and cached detail pages."
                )

                searchControls

                if searchState.shouldShowRecentSearches {
                    recentSearches
                } else if searchState.shouldShowPendingSearchPrompt {
                    pendingSearchPrompt
                } else if let displayState, displayState.visibleResults.isEmpty {
                    SetupPromptView(
                        title: "No Matching Results",
                        message: "Try another term or load more course sections first. Search only covers currently synced and cached data.",
                        systemImage: "magnifyingglass",
                        tint: .indigo
                    )
                } else if let displayState {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(displayState.resultCountLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !displayState.topResults.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Top Results", systemImage: "sparkles", tint: .indigo)

                                resultSection(displayState.topResults)
                            }
                        }

                        ForEach(displayState.groupedResults, id: \.0) { kind, results in
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: kind.rawValue, systemImage: kind.systemImage, tint: .blue)

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
            TextField(
                "Search everything loaded",
                text: Binding(
                    get: { searchState.draftQuery },
                    set: { searchState.updateDraftQuery($0) }
                )
            )
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260, idealWidth: 420, maxWidth: 560)
                .onSubmit {
                    submitSearch()
                }

            Button("Search") {
                submitSearch()
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

    private var pendingSearchPrompt: some View {
        SetupPromptView(
            title: "Ready to Search",
            message: "Press Return or Search to search loaded Canvas data.",
            systemImage: "magnifyingglass",
            tint: .indigo
        )
    }

    private func submitSearch() {
        searchState.submitSearch()

        if let query = searchState.activeQuery {
            store.rememberSearchTerm(query)
        }
    }

    @ViewBuilder
    private func resultSection(_ results: [GlobalSearchResult]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(results) { result in
                GlobalSearchResultRow(result: result, onNavigateToCourse: onNavigateToCourse)

                if result.id != results.last?.id {
                    Divider()
                }
            }
        }
        .appCard(padding: 14)
    }

    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Recent Searches", systemImage: "clock.arrow.circlepath", tint: .indigo)

                Button("Clear") {
                    store.clearRecentSearchTerms()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(store.recentSearchTerms.isEmpty)
            }

            if store.recentSearchTerms.isEmpty {
                SetupPromptView(
                    title: "Start Searching",
                    message: "Search for a course, assignment, module item, file, announcement, person, or cached detail page.",
                    systemImage: "magnifyingglass",
                    tint: .indigo
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(store.recentSearchTerms, id: \.self) { term in
                        Button {
                            searchState.useRecentSearchTerm(term)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(term)
                                    .lineLimit(1)
                            }
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
