//
//  EpisodeRail.swift
//  tagalogue.tv
//
//  The horizontal strip screen 01 draws under "CONTINUE WATCHING", pulled out
//  so Home, detail and anywhere else that needs a row of episodes all set the
//  same 420 × 236 card on the same 30pt gap.
//

import SwiftUI

struct EpisodeRail: View {
    let title: String
    let episodes: [Episode]

    var cardWidth: CGFloat = 420
    var artHeight: CGFloat = 236
    /// Reconciled progress per episode, when the rail should show it.
    var resumeFor: (Episode) -> Resume? = { _ in nil }
    /// Replaces the card's own meta line — "20 min left" on Continue Watching.
    var captionFor: (Episode) -> String? = { _ in nil }
    var actionDescription: String = "Show details"
    /// Numbers the cards 1, 2, 3… — the chart rail, and nothing else.
    var ranked: Bool = false

    @FocusState.Binding var focusedEpisode: String?
    var onSelect: (Episode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RailHeading(title: title)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Theme.Metrics.cardGap) {
                    ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                        EpisodeCard(
                            episode: episode,
                            width: cardWidth,
                            artHeight: artHeight,
                            resume: resumeFor(episode),
                            captionOverride: captionFor(episode),
                            actionDescription: actionDescription,
                            rank: ranked ? index + 1 : nil
                        ) {
                            onSelect(episode)
                        }
                        .focused($focusedEpisode, equals: episode.id)
                    }
                }
                // Room for the 4% focus lift to breathe without the scroll
                // view clipping it.
                .padding(.vertical, 12)
                .padding(.trailing, Theme.Metrics.safeH)
            }
            .scrollClipDisabled()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
