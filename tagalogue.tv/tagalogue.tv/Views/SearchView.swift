//
//  SearchView.swift
//  tagalogue.tv
//
//  05 · Search — keyboard left, results right, as the design draws it.
//

import SwiftUI

struct SearchView: View {
    let catalog: Catalog
    var onSelect: (Episode) -> Void

    @State private var query = ""
    @FocusState private var focusedKey: String?
    @FocusState private var focusedResult: String?

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespaces)
    }
    private var isBrowsing: Bool { trimmed.isEmpty }
    private var results: [Episode] {
        // An empty query used to return nothing at all, so arriving at the tab
        // showed a heading over blank ink. Browsing the catalog is the more
        // useful resting state.
        isBrowsing ? catalog.byRecency : catalog.search(query)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 90) {
            SearchKeyboard(query: $query, focusedKey: $focusedKey)
                .focusSection()

            resultsColumn
                .focusSection()
        }
        .padding(.leading, Theme.Metrics.safeH)
        .padding(.trailing, Theme.Metrics.safeH)
        .padding(.top, 62)
        .padding(.bottom, Theme.Metrics.safeV)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .defaultFocus($focusedKey, "A")
        .task {
            // See HomeView: the nav bar claims first focus unless told otherwise.
            try? await Task.sleep(for: .milliseconds(60))
            if focusedResult == nil { focusedKey = "A" }
        }
    }

    @ViewBuilder private var resultsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(resultsLabel)
                .sectionLabel(size: 25, opacity: 0.55)
                .padding(.bottom, 22)
                .accessibilityAddTraits(.isHeader)

            if results.isEmpty {
                noResults
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(results) { episode in
                            SearchResultRow(episode: episode) { onSelect(episode) }
                                .focused($focusedResult, equals: episode.id)
                        }
                    }
                    .padding(.bottom, Theme.Metrics.safeV)
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing matches “\(trimmed)”")
                .archivo(.bold, 31)
                .foregroundStyle(Theme.paper(0.85))
            Text("Search episode titles, descriptions and chapters.")
                .archivo(.regular, 25)
                .foregroundStyle(Theme.paper(0.55))
        }
        .padding(.top, 8)
    }

    private var resultsLabel: String {
        if isBrowsing { return "All episodes" }
        return results.count == 1 ? "1 result" : "\(results.count) results"
    }
}

struct SearchResultRow: View {
    let episode: Episode
    var action: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                EpisodeArt(episode: episode)
                    .frame(width: 250, height: 140)
                    .overlay(alignment: .topLeading) {
                        if episode.isNew { NewBadge().padding(8) }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .archivo(.bold, 31)
                        .foregroundStyle(focused ? Theme.paper : Theme.paper(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(episode.rowMeta)
                        .archivo(.regular, 25)
                        .foregroundStyle(Theme.paper(focused ? 0.7 : 0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .buttonStyle(ResultRowStyle())
        .focused($focused)
        .accessibilityLabel(episode.accessibilityDescription)
        .accessibilityHint("Show details")
    }
}

private struct ResultRowStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Rectangle().strokeBorder(
                    focused ? Theme.accent : .clear,
                    lineWidth: Theme.Metrics.focusBorder
                )
            )
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}
