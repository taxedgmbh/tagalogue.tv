//
//  RemoteCatalog.swift
//  tagalogue.tv
//
//  The catalog stops being a file baked into the app.
//
//  Three layers, in the order they are trusted:
//
//    1. The copy fetched from the network this launch — the channel as it is now.
//    2. The copy cached on disk from a previous launch — the channel as it was,
//       which is what an Apple TV with no internet should still show.
//    3. `catalog.json` in the bundle — the seed, so a fresh install has
//       something to draw before its first successful fetch.
//
//  The bundle copy is never the *answer* once a remote one exists; it is the
//  floor. A viewer should never see an empty screen because Cloudflare was slow.
//

import Foundation

enum RemoteCatalog {

    /// Set `TagalogueCatalogURL` in Info.plist. Absent, the app runs on the
    /// bundled catalog alone, which is exactly how it behaved before.
    ///
    /// `TagalogueCatalogFallbackURL` is tried only when the first one fails.
    /// One hostname is one point of failure, and not a theoretical one: while
    /// the domain's old nameservers were still being cached, `cdn.tagalogue.tv`
    /// did not exist as far as some resolvers were concerned, and a television
    /// on one of those could not reach the channel at all. The bucket's own
    /// address does not depend on that record.
    static var urls: [URL] {
        ["TagalogueCatalogURL", "TagalogueCatalogFallbackURL"].compactMap { key in
            // `Bundle.main` is the app in the app and the .appex in the Top
            // Shelf extension, and only the app declares these — so fall
            // through to the containing app rather than duplicating the
            // addresses in a second Info.plist that would then drift.
            let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String)
                ?? (Bundle.containingApp.object(forInfoDictionaryKey: key) as? String)
            guard let trimmed = raw?.trimmingCharacters(in: .whitespaces).nilIfEmptyString,
                  let url = URL(string: trimmed)
            else { return nil }
            return url
        }
    }

    private static var cacheURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("catalog-remote.json")
    }

    // MARK: Reading

    /// The most recent catalog on disk, if any. Read synchronously at launch so
    /// the interface has real content before the first frame.
    static func cached() -> Catalog? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? Catalog.decode(data)
    }

    /// Fetches, validates and caches. Returns nil when there is nothing new or
    /// nothing reachable — never throws at the caller, because a failed refresh
    /// is a normal condition, not an error state for the viewer.
    /// - Parameters:
    ///   - attempts: passes over the addresses. The app can afford two; the
    ///     Top Shelf extension is given a few seconds by the system and takes
    ///     one.
    ///   - timeout: per request.
    static func fetch(attempts: Int = 2, timeout: TimeInterval = 15) async -> Catalog? {
        // Two passes over the addresses rather than one. A single dropped
        // packet at launch used to mean a stale channel until something forced
        // the app to look again, which on tvOS can be days: the app is
        // suspended, not quit. The second pass costs a second of waiting in
        // the case where the first already worked — nothing, because it
        // returns on the first success.
        for attempt in 0..<max(1, attempts) {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(1))
            }
            for url in urls {
                if let catalog = await fetch(from: url, timeout: timeout) { return catalog }
            }
        }
        return nil
    }

    private static func fetch(from url: URL, timeout: TimeInterval) async -> Catalog? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let catalog = try? Catalog.decode(data),
              // A catalog with no shows is a deploy accident, not an update.
              // Refuse it rather than blanking the channel.
              !catalog.shows.isEmpty
        else { return nil }

        try? data.write(to: cacheURL, options: .atomic)
        return catalog
    }
}

private extension String {
    var nilIfEmptyString: String? { isEmpty ? nil : self }
}
