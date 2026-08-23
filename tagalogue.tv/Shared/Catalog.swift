//
//  Catalog.swift
//  tagalogue.tv  ·  Shared
//
//  Compiled into both the app and the Top Shelf extension, which is why it
//  lives outside the app's source folder and imports nothing but Foundation.
//  The extension must describe episodes exactly as the app does; a second,
//  drifting copy of these rules is how "EPISODE 0" happened once already.
//

import Foundation

/// A show is a strand of the channel — Interviews, Vlogs — holding episodes.
struct Show: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// e.g. "62 episodes · sit-down conversations, recorded across Switzerland"
    let subtitle: String
    let episodes: [Episode]

    // One episode the television cannot read must not cost the viewer the
    // other fourteen. Synthesized decoding is all-or-nothing: a single episode
    // missing a non-optional field — `subtitles` and `chapters` are the easy
    // ones to omit — throws, `Catalog.decode` fails, `RemoteCatalog.fetch`
    // returns nil, and every install silently falls back to whatever it had
    // last. The channel appears frozen with nothing logged and nothing broken
    // on screen, which is the worst shape a failure can take.
    //
    // So episodes are decoded one at a time and the unreadable ones dropped.
    // The catalog is a feed from a server, not a local file: it has to be
    // treated as something that can arrive malformed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        episodes = try container
            .decode([Lossy<Episode>].self, forKey: .episodes)
            .compactMap(\.value)
    }

    init(id: String, title: String, subtitle: String, episodes: [Episode]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.episodes = episodes
    }
}

/// One array element, decoded or not. Its own decoding never throws, so an
/// unreadable element cannot fail the array around it — and, unlike catching
/// the error mid-array, there is no question of whether the decoder's cursor
/// advanced past the bad element or stopped on it.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct Episode: Codable, Identifiable, Hashable {
    let id: String
    let showID: String
    let showTitle: String
    let number: Int
    let title: String
    let synopsis: String
    /// Seconds. The catalog is the authority on how long an episode is —
    /// see `Resume`, which distrusts a stream that disagrees with this.
    let duration: Int
    let streamURL: URL
    /// BCP-47 tags carried as subtitle tracks, e.g. ["en", "tl"].
    let subtitles: [String]
    let isNew: Bool
    let chapters: [Chapter]
    /// A still bundled with the app, by filename. Nil falls back to the
    /// design's hatch placeholder. TEMPORARY preview wiring — real stills will
    /// arrive from Cloudflare alongside the streams.
    let artworkResource: String?
    /// A video bundled with the app, by filename. When present it is played
    /// instead of `streamURL`. TEMPORARY, same reason.
    let videoResource: String?
    /// When the episode went up. Drives "Latest", the hero and the Top Shelf.
    /// A date in the *future* means scheduled: `Catalog` filters it out until
    /// then, so a release needs nothing running on a timer.
    /// Optional so a catalog written before this field still decodes.
    let publishedAt: Date?
    /// When availability ends. Absent means never, which is the normal case;
    /// rights windows and seasonal pieces get one.
    let expiresAt: Date?
    /// "public", "unlisted" or "draft". Absent means public, so a catalog
    /// written before this field still behaves.
    let visibility: String?
    /// Free-text keywords, searched alongside the title and chapters.
    let tags: [String]?
    /// Metadata for parental controls to read. Nothing is enforced here.
    let maturity: String?
    /// A collection this belongs to, beyond its strand.
    let seriesID: String?
    let seriesTitle: String?

    /// Non-destructive trim, in seconds into the source file. The content tool
    /// never re-encodes; the player starts here and stops at `trimEnd`, which
    /// is why a cut can be adjusted or undone later.
    let trimStart: Double?
    let trimEnd: Double?

    /// Where playback begins. Zero unless the episode has been trimmed.
    var startOffset: Double { max(0, trimStart ?? 0) }

    /// Where playback should stop, or nil to run to the end of the file.
    var endOffset: Double? {
        guard let trimEnd, trimEnd > startOffset else { return nil }
        return trimEnd
    }

    /// True once its release time has arrived. Undated episodes are always out.
    func isReleased(asOf now: Date = .now) -> Bool {
        guard let publishedAt else { return true }
        return publishedAt <= now
    }

    /// True once its window has closed. No end date means it never closes.
    func hasExpired(asOf now: Date = .now) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }

    /// Inside its availability window: out, and not yet gone.
    ///
    /// Enforced on the device rather than trusted from the feed, so a catalog
    /// that is cached, stale, or served unfiltered still cannot put expired
    /// content in front of anyone.
    func isAvailable(asOf now: Date = .now) -> Bool {
        isReleased(asOf: now) && !hasExpired(asOf: now)
    }

    /// Days until it goes, or nil when it stays. Lets a rail say "3 days left".
    func daysRemaining(asOf now: Date = .now) -> Int? {
        guard let expiresAt, expiresAt > now else { return nil }
        return Calendar.current.dateComponents([.day], from: now, to: expiresAt).day
    }

    /// Unlisted episodes play perfectly well — they are simply never put in
    /// front of anyone. A deep link still reaches them, which is the point.
    var isListed: Bool { (visibility ?? "public") == "public" }

    /// Drafts should never have left the content tool. Refusing them here too
    /// means one mis-published catalog cannot put a rough cut on the channel.
    var isPublished: Bool { (visibility ?? "public") != "draft" }

    var durationLabel: String {
        duration < 60 ? "\(duration) sec" : "\(duration / 60) min"
    }

    /// What the player should actually open: a bundled preview file when the
    /// catalog names one, otherwise the stream.
    var playbackURL: URL {
        guard let videoResource else { return streamURL }
        // An episode received from a phone names an absolute path; the catalog
        // names a file bundled with the app.
        if videoResource.hasPrefix("/") { return URL(fileURLWithPath: videoResource) }
        let ext = (videoResource as NSString).pathExtension
        let base = (videoResource as NSString).deletingPathExtension
        return Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? "mp4" : ext)
            ?? streamURL
    }

    /// True where the catalog gives an episode no number — the channel's vlogs,
    /// which are dated rather than numbered. Every meta line honours this.
    var isNumbered: Bool { number > 0 }

    /// "INTERVIEWS · EP 42 · 38 MIN", or "VLOGS · 14 MIN" when unnumbered.
    var metaLine: String {
        let parts = isNumbered
            ? [showTitle.uppercased(), "EP \(number)", durationLabel.uppercased()]
            : [showTitle.uppercased(), durationLabel.uppercased()]
        return parts.joined(separator: " · ")
    }

    /// "EP 42 · 38 min" for card meta, or the show and duration when unnumbered.
    var cardMeta: String {
        isNumbered ? "EP \(number) · \(durationLabel)" : "\(showTitle) · \(durationLabel)"
    }

    /// The detail screen's meta line, minus the show name that sits beside it
    /// in accent: "EPISODE 42 · 38 MIN · SUBTITLES EN, TL". Drops the episode
    /// number for unnumbered strands and the subtitle clause when there are none.
    var detailMeta: String {
        var parts: [String] = []
        if isNumbered { parts.append("EPISODE \(number)") }
        parts.append(durationLabel.uppercased())
        if !subtitles.isEmpty { parts.append("SUBTITLES \(subtitleLabel)") }
        return parts.joined(separator: " · ")
    }

    /// "Interviews · EP 42 · 38 min" — a search row always names the show.
    /// Unlike `cardMeta` this never doubles it: `cardMeta` already leads with
    /// the show name for unnumbered strands.
    var rowMeta: String {
        isNumbered ? "\(showTitle) · \(cardMeta)" : cardMeta
    }

    var subtitleLabel: String {
        subtitles.map { $0.uppercased() }.joined(separator: ", ")
    }

    /// What VoiceOver reads for a card. The focus rectangle wraps the artwork
    /// only — by design — so the button itself carries no text and would
    /// otherwise announce as unnamed.
    var accessibilityDescription: String {
        var parts = [title, showTitle]
        if isNumbered { parts.append("Episode \(number)") }
        parts.append(duration < 60 ? "\(duration) seconds" : "\(duration / 60) minutes")
        if isNew { parts.append("New") }
        return parts.joined(separator: ", ")
    }
}

struct Chapter: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// Seconds from the start of the episode.
    let start: Int

    /// "01 · The interview room"
    func label(index: Int) -> String {
        String(format: "%02d · %@", index + 1, title)
    }
}

struct Catalog: Codable {
    let shows: [Show]

    /// Same reasoning as `Show`: a malformed strand should cost the viewer that
    /// strand, not the channel.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shows = try container.decode([Lossy<Show>].self, forKey: .shows).compactMap(\.value)
    }

    init(shows: [Show]) { self.shows = shows }

    /// Everything that belongs in a rail: released, published and listed.
    ///
    /// Scheduling is held back here rather than at the source, so a catalog can
    /// be published once and simply become visible when its time comes — no
    /// cron, no re-deploy.
    var allEpisodes: [Episode] {
        shows.flatMap(\.episodes).filter { $0.isAvailable() && $0.isPublished && $0.isListed }
    }

    /// Everything playable, including unlisted episodes. Used to resolve a deep
    /// link, which is exactly what "unlisted" is for.
    var playableEpisodes: [Episode] {
        shows.flatMap(\.episodes).filter { $0.isAvailable() && $0.isPublished }
    }

    /// Including drafts and anything still scheduled. Only for tooling.
    var everyEpisode: [Episode] { shows.flatMap(\.episodes) }

    func show(id: String) -> Show? {
        guard let show = shows.first(where: { $0.id == id }) else { return nil }
        return Show(id: show.id, title: show.title, subtitle: show.subtitle,
                    episodes: show.episodes.filter { $0.isAvailable() && $0.isPublished && $0.isListed })
    }

    /// Resolves by id across everything playable, so an unlisted episode opens
    /// from a link even though no list contains it.
    func episode(id: String) -> Episode? { playableEpisodes.first { $0.id == id } }

    /// Newest first. Episodes without a date sort to the back rather than
    /// silently claiming to be recent.
    var byRecency: [Episode] {
        allEpisodes.sorted { a, b in
            switch (a.publishedAt, b.publishedAt) {
            case let (x?, y?): return x > y
            case (nil, _?):    return false
            case (_?, nil):    return true
            case (nil, nil):   return a.id < b.id
            }
        }
    }

    /// The rail Home leads with when there is nothing to resume.
    func latest(_ limit: Int = 8) -> [Episode] { Array(byRecency.prefix(limit)) }

    /// Closing within the week, soonest first. Worth surfacing: a viewer who
    /// keeps meaning to watch something should be told it is about to go.
    func leavingSoon(within days: Int = 7) -> [Episode] {
        allEpisodes
            .compactMap { episode -> (Episode, Int)? in
                guard let left = episode.daysRemaining(), left <= days else { return nil }
                return (episode, left)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    var newEpisodes: [Episode] { byRecency.filter(\.isNew) }

    /// The episode the Home hero leads with — the newest flagged episode,
    /// falling back to the newest of anything.
    var featured: Episode? { newEpisodes.first ?? byRecency.first }

    /// Matches title, synopsis, show name and chapter titles. Chapter titles
    /// are the most specific strings the catalog holds — "Leaving Manila",
    /// "The first winter" — and were the obvious omission here.
    func search(_ query: String) -> [Episode] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return byRecency.filter { episode in
            episode.title.lowercased().contains(q)
            || episode.synopsis.lowercased().contains(q)
            || episode.showTitle.lowercased().contains(q)
            || episode.chapters.contains { $0.title.lowercased().contains(q) }
            || (episode.tags ?? []).contains { $0.lowercased().contains(q) }
            || (episode.seriesTitle?.lowercased().contains(q) ?? false)
        }
    }
}

// MARK: - Loading

extension Catalog {
    /// Decodes the bundled catalog. The Top Shelf extension passes the
    /// containing app's bundle, since only the app ships catalog.json.
    static func decode(from bundle: Bundle) throws -> Catalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.missing
        }
        return try decode(try Data(contentsOf: url))
    }

    /// One decoder for the bundled copy, the cached copy and the network copy,
    /// so a catalog that loads from one source cannot fail from another.
    static func decode(_ data: Data) throws -> Catalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Catalog.self, from: data)
        } catch {
            throw CatalogError.undecodable(String(describing: error))
        }
    }

    /// Encoded the way the remote catalog is written, so a round trip through
    /// R2 and back is lossless.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The same catalog with an episode added to a strand, creating the strand
    /// if the channel has not used it before. Newest first within the strand.
    func adding(_ episode: Episode) -> Catalog {
        var updated = shows
        if let index = updated.firstIndex(where: { $0.id == episode.showID }) {
            var episodes = updated[index].episodes.filter { $0.id != episode.id }
            episodes.insert(episode, at: 0)
            updated[index] = Show(
                id: updated[index].id,
                title: updated[index].title,
                subtitle: updated[index].subtitle,
                episodes: episodes
            )
        } else {
            updated.append(Show(
                id: episode.showID,
                title: episode.showTitle,
                subtitle: "\(episode.showTitle) from the channel",
                episodes: [episode]
            ))
        }
        return Catalog(shows: updated)
    }
}

enum CatalogError: LocalizedError {
    case missing
    case undecodable(String)

    var errorDescription: String? {
        switch self {
        case .missing:
            "catalog.json is missing from the bundle."
        case .undecodable(let detail):
            "catalog.json could not be decoded: \(detail)"
        }
    }
}
