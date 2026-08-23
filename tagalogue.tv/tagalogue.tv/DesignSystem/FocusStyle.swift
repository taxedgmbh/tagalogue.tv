//
//  FocusStyle.swift
//  tagalogue.tv
//
//  The design doc is explicit: "4px accent border and a 4% lift.
//  Never a glow, never a rounded corner."
//
//  tvOS's stock focus effect is a rounded, glowing hover lift, so every
//  focusable surface here opts out of it and draws the border itself.
//

import SwiftUI

/// A card-shaped focusable surface: square corners, 2px idle rule,
/// 4px accent rule and a 4% lift when focused.
struct FocusCard: ViewModifier {
    var isFocused: Bool
    var idleOpacity: Double = Theme.Metrics.idleRuleOpacity

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .strokeBorder(
                        isFocused ? Theme.accent : Theme.paper(idleOpacity),
                        lineWidth: isFocused ? Theme.Metrics.focusBorder : Theme.Metrics.rule
                    )
            )
            .scaleEffect(isFocused ? Theme.Metrics.focusScale : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    func focusCard(_ isFocused: Bool, idleOpacity: Double = Theme.Metrics.idleRuleOpacity) -> some View {
        modifier(FocusCard(isFocused: isFocused, idleOpacity: idleOpacity))
    }

    /// Strips tvOS's default rounded/glowing button chrome so our own
    /// rectangles are the only focus signal.
    func plainFocusable() -> some View {
        self.buttonStyle(.plain)
    }
}

/// Primary action: solid accent fill, flush-left label per Modernist.
struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.extrabold, 29))
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .overlay(
                Rectangle().strokeBorder(
                    focused ? Theme.paper : .clear,
                    lineWidth: Theme.Metrics.focusBorder
                )
            )
            .scaleEffect(focused ? Theme.Metrics.focusScale : 1)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// Secondary action: 2px outline, no fill.
struct SecondaryActionStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.extrabold, 29))
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .overlay(
                Rectangle().strokeBorder(
                    focused ? Theme.accent : Theme.paper(0.4),
                    lineWidth: focused ? Theme.Metrics.focusBorder : Theme.Metrics.rule
                )
            )
            .scaleEffect(focused ? Theme.Metrics.focusScale : 1)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}
