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

    /// True once a network copy has been seen — this launch or a previous one.
    /// Set from the cache at launch too, because a cached copy *is* a copy the
    /// channel once sent us.
    private(set) var isRemote = false

    /// True when the last attempt to reach the channel failed and nothing has
    /// ever been fetched. Distinct from an empty channel, which is a perfectly
    /// ordinary state and reads completely differently to a viewer.
    private(set) var isUnreachable = false

    init() {
        load()
    }

    /// Fetches the published catalog and swaps it in. Safe to call repeatedly.
    func refresh() async {
        guard let fresh = await RemoteCatalog.fetch() else {
            // Only worth saying out loud when there is nothing to show. With a
            // cached copy on screen a failed refresh is invisible and should
            // stay that way — the channel as it was last seen is a good answer.
            isUnreachable = !isRemote
            return
        }
        catalog = fresh
        isRemote = true
        isUnreachable = false
        loadError = nil
    }

    /// Everything playable right now, for lookups by id (deep links, routes).
    var allEpisodes: [Episode] { catalog.allEpisodes }

    /// Resolves an id for a deep link.
    ///
    /// Goes through `Catalog.episode(id:)`, which searches `playableEpisodes`
    /// rather than `allEpisodes` — the difference is unlisted episodes, and
    /// reaching one by link is the entire point of "unlisted". Searching
    /// `allEpisodes` here quietly made every unlisted link a no-op.
    func anyEpisode(id: String) -> Episode? { catalog.episode(id: id) }

    func load() {
        // The cached network copy wins at launch: it is the channel as it was
        // last seen, which beats the seed baked in at build time. Both are
        // replaced the moment `refresh()` succeeds.
        if let cached = RemoteCatalog.cached(), !cached.shows.isEmpty {
            catalog = cached
            isRemote = true
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
