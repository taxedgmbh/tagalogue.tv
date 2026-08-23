//
//  TopShelfProvider.swift
//  TopShelf
//
//  The channel's latest episodes on the tvOS home screen — the surface a
//  viewer sees before they ever open the app, and the one thing the project
//  was leaving entirely to a static image.
//
//  The extension ships code only. catalog.json lives in the containing app,
//  and the models come from Shared/Catalog.swift, compiled into both targets:
//  the Top Shelf must never describe an episode differently from the app.
//

import Foundation
import TVServices
import UIKit

final class TopShelfProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        guard let catalog = try? Catalog.decode(from: .containingApp) else {
            completionHandler(nil)
            return
        }

        let artwork = TopShelfArtwork.placeholderURL()

        let items = catalog.latest(8).map { episode -> TVTopShelfSectionedItem in
            let item = TVTopShelfSectionedItem(identifier: episode.id)
            item.title = episode.title
            item.imageShape = .hdtv
            if let artwork {
                item.setImageURL(artwork, for: .screenScale1x)
                item.setImageURL(artwork, for: .screenScale2x)
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

extension Bundle {
    /// The .appex sits at `<App>.app/PlugIns/<Name>.appex`, so the containing
    /// app is the nearest enclosing `.app`. Only the app ships catalog.json.
    static var containingApp: Bundle {
        var url = Bundle.main.bundleURL
        while url.pathExtension != "app" && url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
        }
        return Bundle(url: url) ?? .main
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
