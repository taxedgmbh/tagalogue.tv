//
//  TopShelfProvider.swift
//  TopShelf
//
//  The channel's latest episodes on the tvOS home screen — the surface a
//  viewer sees before they ever open the app, and the one thing the project
//  was leaving entirely to a static image.
//
//  The extension ships code only. The models — and now the fetcher — come from
//  Shared/, compiled into both targets: the Top Shelf must never describe an
//  episode differently from the app.
//
//  It used to read the *bundled* catalog.json, which has held zero episodes
//  since the catalog went remote. The shelf was therefore empty on every Apple
//  TV, permanently, and had been since the day it stopped being a static file.
//  It fetches the real catalog now, on the same addresses the app uses, with
//  its own cache to fall back on and the bundled seed beneath that.
//

import Foundation
import TVServices
import UIKit

final class TopShelfProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        Task {
            let catalog = await Self.bestAvailableCatalog()
            let episodes = catalog.latest(8)

            guard !episodes.isEmpty else {
                // Nothing to show is a real answer: it leaves the static Top
                // Shelf image in place rather than an empty shelf.
                completionHandler(nil)
                return
            }

            let fallback = TopShelfArtwork.placeholderURL()
            let items = episodes.map { episode -> TVTopShelfSectionedItem in
                let item = TVTopShelfSectionedItem(identifier: episode.id)
                item.title = episode.title
                item.imageShape = .hdtv

                // The episode's own still, which the shelf never used to ask
                // for. Only an http(s) address is any use here — a bundled
                // name means nothing inside an extension, and a file path
                // belongs to the app's container, not this one.
                if let art = episode.artworkResource,
                   art.hasPrefix("http"),
                   let url = URL(string: art) {
                    item.setImageURL(url, for: .screenScale1x)
                    item.setImageURL(url, for: .screenScale2x)
                } else if let fallback {
                    item.setImageURL(fallback, for: .screenScale1x)
                    item.setImageURL(fallback, for: .screenScale2x)
                }

                item.displayAction = TVTopShelfAction(url: DeepLink.detail(episode.id))
                item.playAction = TVTopShelfAction(url: DeepLink.play(episode.id))
                return item
            }

            let collection = TVTopShelfItemCollection(items: items)
            collection.title = "Latest"
            completionHandler(TVTopShelfSectionedContent(sections: [collection]))
        }
    }

    /// Network first, then this extension's own cache, then the bundled seed.
    ///
    /// One attempt on a short timeout: the system gives a content provider a
    /// few seconds, and a shelf that arrives late is a shelf nobody sees. The
    /// fetch writes the cache on its way through, so a slow launch still
    /// leaves the next one fast.
    private static func bestAvailableCatalog() async -> Catalog {
        if let fresh = await RemoteCatalog.fetch(attempts: 1, timeout: 6) { return fresh }
        if let cached = RemoteCatalog.cached(), !cached.shows.isEmpty { return cached }
        return (try? Catalog.decode(from: .containingApp)) ?? Catalog(shows: [])
    }
}

/// Stands in until real episode stills land, drawn as the same 115° hatch the
/// app uses so the Top Shelf does not look like a different product.
private enum TopShelfArtwork {
    static func placeholderURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let url = dir.appendingPathComponent("topshelf-hatch.png")
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let size = CGSize(width: 800, height: 450)   // 16:9, matching .hdtv
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0x23 / 255, green: 0x21 / 255, blue: 0x20 / 255, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            cg.saveGState()
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: 25 * .pi / 180)
            UIColor(red: 0x1c / 255, green: 0x1a / 255, blue: 0x19 / 255, alpha: 1).setFill()
            let reach = size.width + size.height
            var x = -reach
            while x < reach {
                cg.fill(CGRect(x: x, y: -reach, width: 12, height: reach * 2))
                x += 24
            }
            cg.restoreGState()
        }

        guard let data = image.pngData(), (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}
