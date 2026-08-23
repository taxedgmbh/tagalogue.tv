//
//  Theme.swift
//  tagalogue.tv
//
//  Modernist, inverted onto an ink ground.
//  Tokens and rules come from "Apple TV App.dc.html" in the design package.
//

import SwiftUI

enum Theme {

    // MARK: Colour
    //
    // Confirmed against the shipped brand assets: the accent rule along the
    // bottom of TopShelfWide.png samples as a uniform #ec3013 on a uniform
    // #0b0a0a ground.

    static let ink    = Color(hex: 0x0b0a0a)   // ground
    static let paper  = Color(hex: 0xf3f2f2)   // text on ink
    static let accent = Color(hex: 0xec3013)   // focus, primary action, NEW badge — nothing else

    /// Dimmed paper, used for secondary copy and unfocused labels.
    static func paper(_ opacity: Double) -> Color { paper.opacity(opacity) }

    // MARK: Layout
    //
    // tvOS renders at 1920x1080 points, so every value in the design doc maps
    // 1:1 to a SwiftUI point — no conversion needed.

    enum Metrics {
        static let safeH: CGFloat = 90      // 5% overscan, left and right
        static let safeV: CGFloat = 60      // 5% overscan, top and bottom
        static let navHeight: CGFloat = 96
        static let rule: CGFloat = 2        // the standard divider weight
        static let focusBorder: CGFloat = 4
        static let focusScale: CGFloat = 1.04
        /// tvOS's smallest built-in text style is Caption 2 at 23pt, so
        /// nothing in the interface goes below it. The design doc says 19,
        /// written for a browser; 23 is the tvOS equivalent of the same intent
        /// and is what the interface actually follows.
        static let typeFloor: CGFloat = 23

        /// Idle rule opacity. Non-text UI needs 3:1 against the ink ground;
        /// paper at 0.22 measured 1.83:1, which is why this is 0.40 (~3.6:1).
        static let idleRuleOpacity: Double = 0.40

        /// Vertical gap between stacked rails on Home.
        static let railGap: CGFloat = 52
        /// Horizontal gap between cards in a rail, from the design doc.
        static let cardGap: CGFloat = 30
    }

    // MARK: Type
    //
    // Archivo is bundled (see Info.plist UIAppFonts). These are the PostScript
    // names produced when the variable font is instanced to static weights.

    enum Face: String {
        case regular   = "ArchivoRoman-Regular"
        case medium    = "ArchivoRoman-Medium"
        case semibold  = "ArchivoRoman-SemiBold"
        case bold      = "ArchivoRoman-Bold"
        case extrabold = "ArchivoRoman-ExtraBold"
        case black     = "ArchivoRoman-Black"
    }

    static func font(_ face: Face, _ size: CGFloat) -> Font {
        .custom(face.rawValue, size: size, relativeTo: textStyle(for: size))
    }

    /// Binds each size to the nearest tvOS built-in text style so bundled
    /// Archivo still responds to Dynamic Type. tvOS's own scale runs
    /// Caption 2 23 · Caption 1 25 · Body 29 · Callout 31 · Title 3 48 ·
    /// Title 2 57 · Title 1 76 — nothing here should sit below 23pt.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<24:  return .caption2
        case ..<27:  return .caption
        case ..<30:  return .body
        case ..<40:  return .callout
        case ..<50:  return .title3
        case ..<60:  return .title2
        default:     return .title
        }
    }
}

// MARK: - Text conveniences

extension View {
    /// Sets face, size and letter-spacing in one call.
    ///
    /// Tracking is expressed in em, as the design doc writes it, and is always
    /// resolved against the size the text is actually set at. Applying the two
    /// separately is how the interface drifted 16–24% tight: the sizes were
    /// raised to clear the type floor and the trackings kept resolving against
    /// the design doc's original browser px.
    func archivo(_ face: Theme.Face, _ size: CGFloat, tracking em: CGFloat = 0) -> some View {
        self.font(Theme.font(face, size))
            .tracking(em * size)
    }

    /// Uppercase section label: 700 weight, wide tracking.
    func sectionLabel(size: CGFloat = 25, opacity: Double = 0.6) -> some View {
        self.archivo(.bold, size, tracking: 0.12)
            .textCase(.uppercase)
            .foregroundStyle(Theme.paper(opacity))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8)  & 0xff) / 255,
            blue:  Double( hex        & 0xff) / 255,
            opacity: 1
        )
    }
}
