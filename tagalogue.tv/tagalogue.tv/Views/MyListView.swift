//
//  MyListView.swift
//  tagalogue.tv
//
//  The destination for "Add to My List".
//
//  The design package draws four nav sections and no list screen, but the
//  button had nowhere to lead: episodes could be saved and never seen again.
//  A rail on Home was the first fix and it was not enough — a rail that only
//  appears once you have already saved something cannot answer "where did my
//  list go?". So My List is a section, and it says what it is when empty.
//

import SwiftUI
import SwiftData

struct MyListView: View {
    let catalog: Catalog
    var progressFor: (Episode) -> Resume?
    @Binding var focusedEpisode: String?
    var onSelect: (Episode) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \ListEntry.addedAt, order: .reverse) private var entries: [ListEntry]

    @FocusState private var cardFocus: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 30), count: 4)

    private var episodes: [Episode] {
        let byID = Dictionary(catalog.allEpisodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return entries.compactMap { byID[$0.episodeID] }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text("My List")
                    .archivo(.black, 57, tracking: -0.02)
                    .foregroundStyle(Theme.paper)
                    .padding(.bottom, 8)

                Text(subtitle)
                    .archivo(.regular, 29)
                    .foregroundStyle(Theme.paper(0.55))
                    .padding(.bottom, 34)

                if episodes.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 34) {
                        ForEach(episodes) { episode in
                            EpisodeCard(
                                episode: episode,
                                resume: progressFor(episode),
                                actionDescription: "Show details"
                            ) {
                                onSelect(episode)
                            }
                            .focused($cardFocus, equals: episode.id)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.safeH)
            .padding(.top, 54)
            .padding(.bottom, Theme.Metrics.safeV)
        }
        .scrollClipDisabled()
        .task {
            // See HomeView: the nav bar claims first focus unless told otherwise.
            try? await Task.sleep(for: .milliseconds(60))
            if let saved = focusedEpisode, episodes.contains(where: { $0.id == saved }) {
                cardFocus = saved
            } else {
                cardFocus = episodes.first?.id
            }
        }
        .onChange(of: cardFocus) { _, new in
            if let new { focusedEpisode = new }
        }
    }

    private var subtitle: String {
        switch episodes.count {
        case 0: "Episodes you save, kept for later"
        case 1: "1 episode"
        default: "\(episodes.count) episodes"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule().padding(.bottom, 30)

            Text("Nothing saved yet")
                .archivo(.bold, 31)
                .foregroundStyle(Theme.paper(0.85))
                .padding(.bottom, 12)

            Text("Open any episode and choose Add to My List. Saved episodes appear here and in a row on Home.")
                .archivo(.regular, 29)
                .lineSpacing(6)
                .foregroundStyle(Theme.paper(0.55))
                .frame(maxWidth: 820, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
