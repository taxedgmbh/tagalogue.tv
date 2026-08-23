//
//  EpisodeArt.swift
//  tagalogue.tv
//
//  An episode's artwork, falling back to the design's hatch placeholder when
//  there is none. Every surface that used to draw PlaceholderArt directly goes
//  through here, so real stills light up the whole interface at once.
//
//  The two styles below exist because of a preview asset that has since been
//  removed: a 3:4 social poster with its own baked-in headline, in an interface
//  that is 16:9 with its own typography. Centre-cropped
//  into the hero it becomes an unreadable slice, and on the detail screen the
//  poster's "BELOVED FORMER SWISS PRESIDENT" panel lands straight on top of the
//  app's meta line. Hence two styles below: large surfaces contain the artwork
//  over a blurred wash instead of cropping it, which is what a TV app does with
//  portrait key art. Real 16:9 stills will look right in either.
//

import SwiftUI
import UIKit

/// How a frame treats artwork whose shape does not match it.
enum ArtStyle {
    /// Centre-crop to fill. Correct for 16:9 stills; crops portrait art hard.
    case thumbnail
    /// Whole artwork held to one side over a blurred, darkened copy of itself,
    /// leaving a clean area for the app's own type. For the hero and the
    /// detail still, where the interface draws a title over the image.
    case showcase
}

struct EpisodeArt: View {
    var episode: Episode?
    var style: ArtStyle = .thumbnail
    /// Passed through to the placeholder when there is no artwork.
    var light: Bool = false
    var label: String? = nil

    var body: some View {
        if let name = episode?.artworkResource, name.hasPrefix("http") {
            // A published episode's poster is a URL — Cloudflare Stream renders
            // it from the video, or R2 serves an uploaded one. URLSession's own
            // cache keeps it off the network after the first fetch.
            remote(name)
        } else if let name = episode?.artworkResource, let image = BundledArtwork.image(named: name) {
            switch style {
            case .thumbnail: thumbnail(image)
            case .showcase:  showcase(image)
            }
        } else {
            PlaceholderArt(light: light, label: label)
        }
    }

    @ViewBuilder private func remote(_ address: String) -> some View {
        if let url = URL(string: address) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    switch style {
                    case .thumbnail:
                        Color.clear.overlay(image.resizable().aspectRatio(contentMode: .fill)).clipped()
                    case .showcase:
                        showcaseRemote(image)
                    }
                case .failure:
                    PlaceholderArt(light: light, label: label)
                default:
                    // The hatch is the loading state too — no spinner, and the
                    // layout never shifts when the picture arrives.
                    PlaceholderArt(light: light, label: nil)
                }
            }
            .accessibilityHidden(true)
        } else {
            PlaceholderArt(light: light, label: label)
        }
    }

    private func showcaseRemote(_ image: Image) -> some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .overlay(image.resizable().aspectRatio(contentMode: .fill).blur(radius: 60, opaque: true).saturation(0.7))
                .clipped()
            Theme.ink.opacity(0.62)
            image.resizable().aspectRatio(contentMode: .fit)
                .padding(.vertical, 24)
                .padding(.trailing, Theme.Metrics.safeH)
        }
        .clipped()
    }

    private func thumbnail(_ image: UIImage) -> some View {
        Color.clear
            .overlay(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .clipped()
            .accessibilityHidden(true)
    }

    private func showcase(_ image: UIImage) -> some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 60, opaque: true)
                        .saturation(0.7)
                )
                .clipped()

            Theme.ink.opacity(0.62)

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.vertical, 24)
                .padding(.trailing, Theme.Metrics.safeH)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Loads and caches artwork bundled as a loose resource.
///
/// The catalog names a file rather than an asset-catalog entry: real stills
/// will arrive from Cloudflare alongside the streams, not baked into the app,
/// so the loading path is the same shape it will need to be later.
enum BundledArtwork {
    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]

    static func image(named name: String) -> UIImage? {
        if let hit = cache[name] { return hit }

        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? "jpg" : ext),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }

        cache[name] = image
        return image
    }
}
