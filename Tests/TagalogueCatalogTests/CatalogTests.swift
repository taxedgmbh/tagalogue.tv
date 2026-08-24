//
//  CatalogTests.swift
//
//  The three visibility gates, scheduling, expiry, lossy decoding and deep
//  link resolution — the logic that decides what reaches a television, and the
//  only logic in the project where being wrong is silent.
//

import XCTest
@testable import TagalogueCatalog

final class CatalogTests: XCTestCase {

    // MARK: Fixture

    /// One episode, with everything the Swift model requires and nothing it
    /// does not. Overrides are spliced in as raw JSON so a test can express
    /// "this field is missing entirely", which is the case that matters.
    private func episodeJSON(
        id: String,
        title: String = "An episode",
        publishedAt: String? = "2020-01-01T00:00:00Z",
        expiresAt: String? = nil,
        visibility: String? = "public",
        extra: String = ""
    ) -> String {
        var fields = [
            "\"id\":\"\(id)\"",
            "\"showID\":\"interviews\"",
            "\"showTitle\":\"Interviews\"",
            "\"number\":0",
            "\"title\":\"\(title)\"",
            "\"synopsis\":\"A synopsis\"",
            "\"duration\":600",
            "\"streamURL\":\"https://example.com/\(id).m3u8\"",
            "\"subtitles\":[]",
            "\"isNew\":false",
            "\"chapters\":[]",
        ]
        if let publishedAt { fields.append("\"publishedAt\":\"\(publishedAt)\"") }
        if let expiresAt { fields.append("\"expiresAt\":\"\(expiresAt)\"") }
        if let visibility { fields.append("\"visibility\":\"\(visibility)\"") }
        if !extra.isEmpty { fields.append(extra) }
        return "{\(fields.joined(separator: ","))}"
    }

    private func catalog(_ episodes: [String], topToday: [String]? = nil) throws -> Catalog {
        var json = "{\"shows\":[{\"id\":\"interviews\",\"title\":\"Interviews\","
        json += "\"subtitle\":\"Sit-down conversations\",\"episodes\":[\(episodes.joined(separator: ","))]}]"
        if let topToday {
            json += ",\"topToday\":[\(topToday.map { "\"\($0)\"" }.joined(separator: ","))]"
        }
        json += "}"
        return try Catalog.decode(Data(json.utf8))
    }

    private func iso(_ offsetSeconds: TimeInterval) -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: Date().addingTimeInterval(offsetSeconds))
    }

    // MARK: The three gates

    func testPublicEpisodeIsVisibleEverywhere() throws {
        let c = try catalog([episodeJSON(id: "a")])
        XCTAssertEqual(c.allEpisodes.map(\.id), ["a"])
        XCTAssertEqual(c.playableEpisodes.map(\.id), ["a"])
        XCTAssertEqual(c.everyEpisode.map(\.id), ["a"])
    }

    func testDraftIsHiddenFromListsAndFromPlayback() throws {
        let c = try catalog([episodeJSON(id: "a", visibility: "draft")])
        XCTAssertTrue(c.allEpisodes.isEmpty, "a draft must never appear in a rail")
        XCTAssertTrue(c.playableEpisodes.isEmpty, "a draft must not be playable, even by link")
        XCTAssertEqual(c.everyEpisode.count, 1, "tooling still sees it")
    }

    /// The whole point of "unlisted": absent from every list, reachable by link.
    func testUnlistedIsHiddenFromListsButStillPlayable() throws {
        let c = try catalog([episodeJSON(id: "a", visibility: "unlisted")])
        XCTAssertTrue(c.allEpisodes.isEmpty)
        XCTAssertEqual(c.playableEpisodes.map(\.id), ["a"])
    }

    /// Regression: `episode(id:)` resolved through `playableEpisodes` while the
    /// app's own lookup went through `allEpisodes`, so every deep link to an
    /// unlisted episode silently did nothing.
    func testDeepLinkResolvesAnUnlistedEpisode() throws {
        let c = try catalog([episodeJSON(id: "secret", visibility: "unlisted")])
        XCTAssertNotNil(c.episode(id: "secret"))
    }

    func testDeepLinkDoesNotResolveADraft() throws {
        let c = try catalog([episodeJSON(id: "wip", visibility: "draft")])
        XCTAssertNil(c.episode(id: "wip"))
    }

    // MARK: Scheduling and expiry

    func testFutureEpisodeIsHeldBackUntilItsMoment() throws {
        let c = try catalog([episodeJSON(id: "a", publishedAt: iso(3600))])
        XCTAssertTrue(c.allEpisodes.isEmpty, "scheduling needs no cron; the gate does it")
        XCTAssertEqual(c.everyEpisode.count, 1)
    }

    func testExpiredEpisodeDropsOut() throws {
        let c = try catalog([episodeJSON(id: "a", publishedAt: iso(-7200), expiresAt: iso(-3600))])
        XCTAssertTrue(c.allEpisodes.isEmpty)
        XCTAssertTrue(c.playableEpisodes.isEmpty)
    }

    func testEpisodeInsideItsWindowIsVisible() throws {
        let c = try catalog([episodeJSON(id: "a", publishedAt: iso(-3600), expiresAt: iso(3600))])
        XCTAssertEqual(c.allEpisodes.map(\.id), ["a"])
    }

    // MARK: Lossy decoding

    /// The safety net `CLAUDE.md` describes: one unreadable episode used to
    /// throw, which failed the whole decode, which left every install on its
    /// last cached copy with nothing visibly wrong.
    func testOneMalformedEpisodeCostsOnlyThatEpisode() throws {
        let broken = "{\"id\":\"broken\",\"title\":\"No stream URL and no anything else\"}"
        let c = try catalog([episodeJSON(id: "good"), broken])
        XCTAssertEqual(c.allEpisodes.map(\.id), ["good"])
    }

    func testAnEpisodeMissingChaptersIsStillDropped_notTheCatalog() throws {
        // `chapters` and `subtitles` are non-optional in the Swift model.
        let noChapters = """
        {"id":"x","showID":"interviews","showTitle":"Interviews","number":0,\
        "title":"T","synopsis":"S","duration":10,\
        "streamURL":"https://example.com/x.m3u8","subtitles":[],"isNew":false}
        """
        let c = try catalog([episodeJSON(id: "good"), noChapters])
        XCTAssertEqual(c.allEpisodes.map(\.id), ["good"])
        XCTAssertEqual(c.shows.count, 1, "the strand survives")
    }

    // MARK: Ordering and the chart

    func testLatestIsNewestFirst() throws {
        let c = try catalog([
            episodeJSON(id: "old", publishedAt: iso(-9000)),
            episodeJSON(id: "new", publishedAt: iso(-60)),
            episodeJSON(id: "mid", publishedAt: iso(-3000)),
        ])
        XCTAssertEqual(c.latest(3).map(\.id), ["new", "mid", "old"])
    }

    func testChartResolvesOnlyToEpisodesAViewerCanSee() throws {
        let c = try catalog(
            [episodeJSON(id: "live"), episodeJSON(id: "hidden", visibility: "draft")],
            topToday: ["hidden", "live", "gone"]
        )
        XCTAssertEqual(c.topEpisodes.map(\.id), ["live"],
                       "a draft and a deleted id must not become ranks pointing at nothing")
    }

    func testNoChartMeansNoRail() throws {
        let c = try catalog([episodeJSON(id: "a")])
        XCTAssertTrue(c.topEpisodes.isEmpty)
    }

    // MARK: Deep links

    func testDeepLinkRoundTrips() {
        let detail = DeepLink.detail("cf-123")
        XCTAssertEqual(DeepLink.destination(for: detail), .detail(episodeID: "cf-123"))

        let play = DeepLink.play("cf-123")
        XCTAssertEqual(DeepLink.destination(for: play), .play(episodeID: "cf-123"))
    }

    func testUnknownURLIsIgnored() {
        XCTAssertNil(DeepLink.destination(for: URL(string: "https://tagalogue.tv/")!))
    }
}
