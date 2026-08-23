//
//  CategoryGridView.swift
//  tagalogue.tv
//
//  02 · Category grid
//

import SwiftUI

struct CategoryGridView: View {
    let show: Show
    var progressFor: (Episode) -> Resume?
    /// Last card focused here, restored on re-entry so the grid does not throw
    /// you back to the top every time you visit the section.
    @Binding var focusedEpisode: String?
    var onSelect: (Episode) -> Void

    @FocusState private var cardFocus: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 30), count: 4)

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text(show.title)
                    .archivo(.black, 57, tracking: -0.02)
                    .foregroundStyle(Theme.paper)
                    .padding(.bottom, 8)

                Text(show.subtitle)
                    .archivo(.regular, 29)
                    .foregroundStyle(Theme.paper(0.55))
                    .padding(.bottom, 34)

                if show.episodes.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 34) {
                        ForEach(show.episodes) { episode in
                            EpisodeCard(
                                episode: episode,
                                resume: progressFor(episode)
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
        .defaultFocus($cardFocus, show.episodes.first?.id)
        .task {
            // See HomeView: the nav bar claims first focus unless told otherwise.
            try? await Task.sleep(for: .milliseconds(60))
            if let saved = focusedEpisode, show.episodes.contains(where: { $0.id == saved }) {
                cardFocus = saved
            } else {
                cardFocus = show.episodes.first?.id
            }
        }
        .onChange(of: cardFocus) { _, new in
            if let new { focusedEpisode = new }
        }
    }

    /// A strand with nothing published yet. Ordinary for a new channel, and
    /// for a strand that has not had its first episode.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule().padding(.bottom, 30)

            Text("Nothing here yet")
                .archivo(.bold, 31)
                .foregroundStyle(Theme.paper(0.85))
                .padding(.bottom, 12)

            Text("Episodes appear here as soon as they are published.")
                .archivo(.regular, 29)
                .lineSpacing(6)
                .foregroundStyle(Theme.paper(0.55))
                .frame(maxWidth: 820, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
