//
//  CatalogLoader.swift
//  tagalogue.tv
//

import Foundation
import Observation

@Observable
final class CatalogStore {
    private(set) var catalog: Catalog = Catalog(shows: [])
    private(set) var loadError: String?

    /// True once a network copy has been seen this launch.
    private(set) var isRemote = false

    init() {
        load()
    }

    /// Fetches the published catalog and swaps it in. Safe to call repeatedly.
    func refresh() async {
        guard let fresh = await RemoteCatalog.fetch() else { return }
        catalog = fresh
        isRemote = true
        loadError = nil
    }

    /// Publishing writes straight into the in-memory catalog so the new episode
    /// appears immediately, without waiting for the next fetch to come round.
    func merge(published episode: Episode) {
        catalog = catalog.adding(episode)
    }

    /// Everything playable right now, for lookups by id (deep links, routes).
    var allEpisodes: [Episode] { catalog.allEpisodes }

    func anyEpisode(id: String) -> Episode? { allEpisodes.first { $0.id == id } }

    func load() {
        // The cached network copy wins at launch: it is the channel as it was
        // last seen, which beats the seed baked in at build time. Both are
        // replaced the moment `refresh()` succeeds.
        if let cached = RemoteCatalog.cached(), !cached.shows.isEmpty {
            catalog = cached
            loadError = nil
            return
        }
        do {
            // Decoding lives in Shared/Catalog.swift so the Top Shelf
            // extension reads the catalog by exactly the same rules.
            catalog = try Catalog.decode(from: .main)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
