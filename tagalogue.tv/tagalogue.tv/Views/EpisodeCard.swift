//
//  EpisodeCard.swift
//  tagalogue.tv
//
//  The focus rule applies to the art only — the caption sits below it,
//  outside the bordered rectangle, exactly as the design doc draws it.
//
//  Because the caption is outside the button, the button's own label is a
//  wordless rectangle. Everything focusable here therefore carries an explicit
//  accessibility label; without one VoiceOver announces the whole grid as
//  unnamed buttons.
//

import SwiftUI

struct EpisodeCard: View {
    let episode: Episode
    var width: CGFloat? = nil
    var artHeight: CGFloat? = nil
    /// Reconciled progress, when there is any. Draws the rule along the bottom
    /// of the art and, when complete, marks the card watched.
    var resume: Resume? = nil
    var captionOverride: String? = nil
    /// Home's Continue Watching plays straight from the card; grids open detail.
    var actionDescription: String = "Show details"
    /// Position in the chart, when this card is in one. 1-based.
    var rank: Int? = nil
    var action: () -> Void

    @FocusState private var focused: Bool

    private var caption: String { captionOverride ?? episode.cardMeta }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                art
            }
            .buttonStyle(ArtCardStyle())
            .focused($focused)
            .accessibilityLabel(episode.accessibilityDescription)
            // The badge itself is hidden from VoiceOver, so "watched" has to
            // reach it here or it is a purely visual state.
            .accessibilityValue(
                [rank.map { "Number \($0)" }, caption,
                 resume?.isComplete == true ? "Watched" : nil]
                    .compactMap(\.self).joined(separator: ". ")
            )
            .accessibilityHint(actionDescription)

            Text(episode.title)
                .archivo(.bold, 31)
                .foregroundStyle(focused ? Theme.paper : Theme.paper(0.85))
                // Two lines, always reserved: real episode titles run long
                // ("Nurses of Basel: twenty years on the night shift") and a
                // one-line limit truncated most of the grid mid-word. Reserving
                // the space keeps every caption in a row on the same baseline.
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .padding(.top, 16)

            Text(caption)
                .archivo(.regular, 25)
                .foregroundStyle(Theme.paper(focused ? 0.75 : 0.6))
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .animation(.easeOut(duration: 0.15), value: focused)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var art: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let artHeight {
                    EpisodeArt(episode: episode).frame(height: artHeight)
                } else {
                    EpisodeArt(episode: episode).aspectRatio(16.0 / 9.0, contentMode: .fit)
                }
            }

            if let resume, resume.fraction > 0 {
                ProgressRule(fraction: resume.fraction, isComplete: resume.isComplete)
            }
        }
        .overlay(alignment: .topLeading) {
            if episode.isNew {
                NewBadge().padding(10)
            }
        }
        // Opposite corner from NEW: a newly published episode you have already
        // finished is both, and they must not stack on top of each other.
        .overlay(alignment: .topTrailing) {
            if resume?.isComplete == true {
                WatchedBadge().padding(10)
            }
        }
        // The chart numeral. Paper, not accent — red is focus, the primary
        // action and NEW, and a rank is none of those. Set outside the art on
        // the leading edge so it reads as a position rather than as a label
        // printed on the picture.
        .overlay(alignment: .bottomLeading) {
            if let rank {
                Text("\(rank)")
                    .archivo(.black, 96, tracking: -0.04)
                    .foregroundStyle(Theme.paper)
                    .shadow(color: Theme.ink.opacity(0.9), radius: 10, y: 2)
                    .padding(.leading, 14)
                    .padding(.bottom, 10)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Square corners, 2pt idle rule, 4pt accent rule, 4% lift. No glow, no radius.
struct ArtCardStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Rectangle().strokeBorder(
                    focused ? Theme.accent : Theme.paper(Theme.Metrics.idleRuleOpacity),
                    lineWidth: focused ? Theme.Metrics.focusBorder : Theme.Metrics.rule
                )
            )
            .scaleEffect(focused ? Theme.Metrics.focusScale : 1)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}
