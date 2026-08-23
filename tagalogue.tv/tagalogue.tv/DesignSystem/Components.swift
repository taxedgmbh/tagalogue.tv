//
//  Components.swift
//  tagalogue.tv
//
//  The small marks the design doc reuses across screens. Keeping them in one
//  place is what stops the accent rule — "red marks focus, the primary action
//  and the NEW badge, nothing else" — from being re-litigated per screen.
//

import SwiftUI

/// Solid accent plate. The one badge the accent rule sanctions.
struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .archivo(.extrabold, 23, tracking: 0.14)
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Theme.accent)
            .accessibilityHidden(true)   // already spoken in the card's label
    }
}

/// The 8pt rule along the bottom of a card's artwork.
///
/// Accent while an episode is part-watched, paper once it is finished — the
/// same shape carrying two states, rather than introducing a tick or a second
/// vocabulary for "watched".
struct ProgressRule: View {
    /// 0...1
    var fraction: Double
    var isComplete: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.paper(0.25))
                Rectangle()
                    .fill(isComplete ? Theme.paper(0.75) : Theme.accent)
                    .frame(width: geo.size.width * min(max(isComplete ? 1 : fraction, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// The 2pt divider the design doc sets above a section heading.
struct SectionRule: View {
    var opacity: Double = 0.18

    var body: some View {
        Rectangle()
            .fill(Theme.paper(opacity))
            .frame(height: Theme.Metrics.rule)
            .accessibilityHidden(true)
    }
}

/// Flush-left heading over a horizontal rail, matching screen 01's
/// "CONTINUE WATCHING".
struct RailHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .sectionLabel()
            .padding(.bottom, 20)
            .accessibilityAddTraits(.isHeader)
    }
}
