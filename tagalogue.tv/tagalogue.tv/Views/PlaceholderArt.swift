//
//  PlaceholderArt.swift
//  tagalogue.tv
//
//  The design doc ships every still as a diagonal hatch and says so plainly:
//  "Stills are placeholders — drop real frames in later." This reproduces that
//  hatch so layouts read correctly until real artwork lands.
//
//  It is drawn as one cached 24pt tile rotated into place rather than ~100
//  filled paths per card. A grid of twelve cards animating their focus lift is
//  the worst case, and re-rasterising vector hatching on every frame of that is
//  exactly the sort of thing a 2nd-generation Apple TV notices.
//

import SwiftUI
import UIKit

struct PlaceholderArt: View {
    var light: Bool = false
    var label: String? = nil

    private var base: Color { light ? Color(hex: 0x302e2d) : Color(hex: 0x232120) }
    private var alt:  Color { light ? Color(hex: 0x272524) : Color(hex: 0x1c1a19) }

    var body: some View {
        GeometryReader { geo in
            // Oversize past the diagonal so the rotated tiling still covers
            // the corners, then clip back to the frame.
            let cover = geo.size.width + geo.size.height

            Image(uiImage: HatchTile.image(light: light))
                .resizable(resizingMode: .tile)
                .frame(width: cover, height: cover)
                .rotationEffect(.degrees(25))          // 115° axis, as the design doc writes it
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .background(base)
        .overlay(alignment: .topTrailing) {
            if let label {
                // The design parks this clear of the copy at right:110, top:40.
                // Centred, it printed straight through the hero synopsis.
                Text(label)
                    .archivo(.medium, 25, tracking: 0.24)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.paper(0.3))
                    .padding(.trailing, 110)
                    .padding(.top, 40)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// One 24pt tile — 12 on, 12 off — rendered once per colourway and reused.
private enum HatchTile {
    nonisolated(unsafe) private static var cache: [Bool: UIImage] = [:]

    static func image(light: Bool) -> UIImage {
        if let hit = cache[light] { return hit }

        let base = light ? UIColor(red: 0x30 / 255, green: 0x2e / 255, blue: 0x2d / 255, alpha: 1)
                         : UIColor(red: 0x23 / 255, green: 0x21 / 255, blue: 0x20 / 255, alpha: 1)
        let alt  = light ? UIColor(red: 0x27 / 255, green: 0x25 / 255, blue: 0x24 / 255, alpha: 1)
                         : UIColor(red: 0x1c / 255, green: 0x1a / 255, blue: 0x19 / 255, alpha: 1)

        let size = CGSize(width: 24, height: 24)
        let made = UIGraphicsImageRenderer(size: size).image { ctx in
            base.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            alt.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 24))
        }
        cache[light] = made
        return made
    }
}
