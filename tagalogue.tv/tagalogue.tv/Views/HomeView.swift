//
//  HomeView.swift
//  tagalogue.tv
//
//  01 · Home — hero and rails
//

import SwiftUI

struct HomeView: View {
    let catalog: Catalog
    let progress: [WatchProgress]
    let list: [ListEntry]
    /// Last card focused here, so returning to Home lands where you left.
    @Binding var focusedEpisode: String?
    var onPlay: (Episode) -> Void
    var onDetail: (Episode) -> Void

    private enum HeroAction: Hashable { case play, info }

    @FocusState private var heroAction: HeroAction?
    @FocusState private var cardFocus: String?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                if isEmpty {
                    emptyState
                } else {
                    if let featured = catalog.featured {
                        hero(featured)
                    }
                    rails
                        .padding(.top, 44)
                        .padding(.bottom, Theme.Metrics.safeV)
                }
            }
        }
        .scrollClipDisabled()
        // Without this the interface opens with focus parked on "Home" in the
        // nav bar, so the first press of the remote is spent travelling down
        // to the thing the screen exists to offer.
        .defaultFocus($heroAction, .play)
        .task {
            // `defaultFocus` alone loses to the nav bar, which is the first
            // focus section in the window and simply claims focus first — so
            // say it outright, once layout has settled.
            try? await Task.sleep(for: .milliseconds(60))
            if let saved = focusedEpisode, allRailEpisodes.contains(where: { $0.id == saved }) {
                cardFocus = saved
            } else {
                heroAction = .play
            }
        }
        .onChange(of: cardFocus) { _, new in
            if let new { focusedEpisode = new }
        }
    }

    // MARK: Empty

    /// Nothing to show: a new install before its first fetch, or a channel
    /// whose first episode has not been published yet. Both are ordinary
    /// states, not errors, so this says what is true and stops there.
    private var isEmpty: Bool {
        allRailEpisodes.isEmpty && catalog.featured == nil
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("TAGALOGUE TV")
                .archivo(.bold, 23, tracking: 0.22)
                .foregroundStyle(Theme.accent)

            Text("Nothing on air yet")
                .archivo(.black, 76, tracking: -0.01)
                .foregroundStyle(Theme.paper)

            Text("New episodes appear here as soon as they are published.")
                .archivo(.regular, 31, tracking: 0)
                .foregroundStyle(Theme.paper(0.62))
                .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Theme.Metrics.safeH)
        .padding(.top, 180)
    }

    // MARK: Hero

    private func hero(_ episode: Episode) -> some View {
        ZStack(alignment: .bottomLeading) {
            EpisodeArt(episode: episode, style: .showcase, light: true, label: "Hero still 1920 × 520")
                .frame(height: 520)

            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x0a0909).opacity(0.97), location: 0),
                    .init(color: Color(hex: 0x0a0909).opacity(0.85), location: 0.44),
                    .init(color: Color(hex: 0x0a0909).opacity(0),    location: 0.78)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 520)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    if episode.isNew { NewBadge() }
                    Text(episode.metaLine)
                        .archivo(.semibold, 23, tracking: 0.14)
                        .foregroundStyle(Theme.paper(0.62))
                }
                .padding(.bottom, 20)

                Text(episode.title)
                    .archivo(.black, 62, tracking: -0.02)
                    .foregroundStyle(Theme.paper)
                    .lineLimit(2)
                    .padding(.bottom, 16)

                Text(episode.synopsis)
                    .archivo(.regular, 29)
                    .lineSpacing(6)
                    .lineLimit(4)
                    .foregroundStyle(Theme.paper(0.7))
                    .frame(maxWidth: 700, alignment: .leading)
                    .padding(.bottom, 26)

                HStack(spacing: 16) {
                    // Says what it will actually do. The hero has always
                    // resumed mid-episode; it just used to claim it was
                    // starting from the top.
                    Button(heroPlayLabel(episode)) { onPlay(episode) }
                        .buttonStyle(PrimaryActionStyle())
                        .focused($heroAction, equals: .play)

                    Button("More info") { onDetail(episode) }
                        .buttonStyle(SecondaryActionStyle())
                        .focused($heroAction, equals: .info)
                        .accessibilityHint("Details for \(episode.title)")
                }
            }
            .frame(width: 860, alignment: .leading)
            .padding(.leading, Theme.Metrics.safeH)
            .padding(.bottom, 44)
        }
        .frame(height: 520)
        .clipped()
    }

    private func heroPlayLabel(_ episode: Episode) -> String {
        guard let r = resume(for: episode), r.isResumable else { return "Play" }
        return "Resume \(Resume.timecode(r.startPosition))"
    }

    // MARK: Rails

    @ViewBuilder private var rails: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.railGap) {
            if !resumable.isEmpty {
                EpisodeRail(
                    title: "Continue watching",
                    episodes: resumable.map(\.0),
                    resumeFor: { resume(for: $0) },
                    captionFor: { resume(for: $0)?.remainingLabel },
                    actionDescription: "Resume playing",
                    focusedEpisode: $cardFocus,
                    onSelect: onPlay
                )
            }

            if !myList.isEmpty {
                EpisodeRail(
                    title: "My list",
                    episodes: myList,
                    resumeFor: { resume(for: $0) },
                    focusedEpisode: $cardFocus,
                    onSelect: onDetail
                )
            }

            // Above Latest on purpose: something about to go is more urgent
            // than something that just arrived.
            if !catalog.leavingSoon().isEmpty {
                EpisodeRail(
                    title: "Leaving soon",
                    episodes: catalog.leavingSoon(),
                    resumeFor: { resume(for: $0) },
                    captionFor: { episode in
                        guard let days = episode.daysRemaining() else { return nil }
                        return days <= 0 ? "Last day" : days == 1 ? "1 day left" : "\(days) days left"
                    },
                    focusedEpisode: $cardFocus,
                    onSelect: onDetail
                )
            }

            // A rail with no cards is a heading floating over nothing, which
            // reads as a bug rather than as an empty channel.
            if !catalog.latest().isEmpty {
                EpisodeRail(
                    title: "Latest",
                    episodes: catalog.latest(),
                    resumeFor: { resume(for: $0) },
                    focusedEpisode: $cardFocus,
                    onSelect: onDetail
                )
            }

            ForEach(catalog.shows.filter { !$0.episodes.isEmpty }) { show in
                EpisodeRail(
                    title: show.title,
                    episodes: show.episodes,
                    resumeFor: { resume(for: $0) },
                    focusedEpisode: $cardFocus,
                    onSelect: onDetail
                )
            }
        }
        .padding(.leading, Theme.Metrics.safeH)
    }

    // MARK: Data

    private func resume(for episode: Episode) -> Resume? {
        episode.resume(from: progress.first { $0.episodeID == episode.id })
    }

    /// Part-watched episodes, most recent first.
    private var resumable: [(Episode, Resume)] {
        let byID = Dictionary(catalog.allEpisodes.map { ($0.id, $0) },
                              uniquingKeysWith: { a, _ in a })
        return progress
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { p -> (Episode, Resume)? in
                guard let episode = byID[p.episodeID],
                      let r = episode.resume(from: p),
                      r.isResumable
                else { return nil }
                return (episode, r)
            }
    }

    /// Saved episodes, most recently added first. This is the rail that gives
    /// "Add to My List" somewhere to land — it used to be a write-only store.
    private var myList: [Episode] {
        let byID = Dictionary(catalog.allEpisodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return list
            .sorted { $0.addedAt > $1.addedAt }
            .compactMap { byID[$0.episodeID] }
    }

    private var allRailEpisodes: [Episode] {
        resumable.map(\.0) + myList + catalog.leavingSoon()
            + catalog.latest() + catalog.allEpisodes
    }
}
