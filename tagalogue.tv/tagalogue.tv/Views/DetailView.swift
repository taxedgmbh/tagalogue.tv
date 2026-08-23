//
//  DetailView.swift
//  tagalogue.tv
//
//  03 · Episode detail
//

import SwiftUI
import SwiftData

struct DetailView: View {
    let episode: Episode
    /// Other episodes from the same strand. Fourteen of fifteen episodes carry
    /// no chapters, and without this the bottom half of the screen is bare ink.
    let related: [Episode]
    var onPlay: (Episode, Double) -> Void
    var onOpen: (Episode) -> Void

    @Environment(\.modelContext) private var context
    @Query private var progress: [WatchProgress]
    @Query private var list: [ListEntry]

    private enum Action: Hashable { case play, resume, list, report }

    @FocusState private var action: Action?
    @State private var reporting = false
    @FocusState private var cardFocus: String?

    private var resume: Resume? {
        episode.resume(from: progress.first { $0.episodeID == episode.id })
    }
    private var inList: Bool {
        list.contains { $0.episodeID == episode.id }
    }

    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .top) {
                still
                content.padding(.top, 300)
            }
        }
        .scrollClipDisabled()
        .background(Theme.ink)
        .defaultFocus($action, .play)
        // Carries the episode's contentId while the page is open, which is
        // what "Hey Siri, add this to my Up Next" reads. See UpNext.swift.
        .userActivity(UpNext.activityType) { activity in
            UpNext.describe(activity, for: episode)
        }
        .fullScreenCover(isPresented: $reporting) {
            if let url = ChannelLinks.report {
                ScanSheet(
                    title: "Report this episode",
                    message: "Scan the code and tell us what is wrong with \"\(episode.title)\". "
                           + "A person reads every report. If something breaks the channel's "
                           + "rules it comes down, and nothing needs to happen on your side.",
                    url: url,
                    onClose: { reporting = false }
                )
            }
        }
    }

    private var still: some View {
        ZStack {
            EpisodeArt(episode: episode, style: .showcase, light: true, label: "Episode still")
                .frame(height: 600)
            LinearGradient(
                stops: [
                    .init(color: Theme.ink,                  location: 0),
                    .init(color: Theme.ink.opacity(0.7),     location: 0.38),
                    .init(color: Theme.ink.opacity(0.15),    location: 1)
                ],
                startPoint: .bottom, endPoint: .top
            )
            .frame(height: 600)
        }
        .frame(height: 600)
        .clipped()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Text(episode.showTitle.uppercased())
                    .archivo(.bold, 25, tracking: 0.16)
                    .foregroundStyle(Theme.accent)
                // Built from the model's own rule, which knows that a vlog
                // carries no episode number. Hand-rolling it here is what put
                // "EPISODE 0" on all six vlogs.
                Text(episode.detailMeta)
                    .archivo(.semibold, 25, tracking: 0.14)
                    .foregroundStyle(Theme.paper(0.55))
            }
            .padding(.bottom, 18)
            .accessibilityElement(children: .combine)

            Text(episode.title)
                .archivo(.black, 66, tracking: -0.02)
                .foregroundStyle(Theme.paper)
                // Without fixedSize the ZStack proposes a single line's height
                // and a long title truncates instead of wrapping — the design
                // sets this to two lines inside 1200.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 1200, alignment: .leading)
                .padding(.bottom, 18)

            Text(episode.synopsis)
                .archivo(.regular, 31)
                .lineSpacing(7)
                .foregroundStyle(Theme.paper(0.7))
                .frame(maxWidth: 980, alignment: .leading)
                .padding(.bottom, 30)

            if let resume, resume.fraction > 0 {
                progressReadout(resume).padding(.bottom, 30)
            }

            actions.padding(.bottom, 56)

            if !episode.chapters.isEmpty {
                chapters.padding(.bottom, related.isEmpty ? 0 : 56)
            }

            if !related.isEmpty { relatedRail }
        }
        .padding(.horizontal, Theme.Metrics.safeH)
        .padding(.bottom, Theme.Metrics.safeV)
    }

    /// How far in you are, spelled out. The Resume button carries a timecode
    /// but nothing used to draw the position it refers to.
    private func progressReadout(_ resume: Resume) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressRule(fraction: resume.fraction, isComplete: resume.isComplete)
                .frame(width: 720)
            Text(resume.isComplete ? "Watched" : resume.positionLabel)
                .archivo(.semibold, 23, tracking: 0.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.paper(0.55))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(resume.isComplete ? "Watched" : "Watched \(resume.positionLabel)")
    }

    private var actions: some View {
        HStack(spacing: 16) {
            Button("Play from start") { onPlay(episode, 0) }
                .buttonStyle(PrimaryActionStyle())
                .focused($action, equals: .play)

            if let resume, resume.isResumable {
                Button("Resume \(Resume.timecode(resume.startPosition))") {
                    onPlay(episode, resume.startPosition)
                }
                .buttonStyle(SecondaryActionStyle())
                .focused($action, equals: .resume)
            }

            Button(inList ? "In My List" : "Add to My List") { toggleList() }
                .buttonStyle(SecondaryActionStyle())
                .focused($action, equals: .list)
                .accessibilityHint(inList ? "Removes this episode from My List"
                                          : "Saves this episode to the My List section")

            // Guideline 1.2: anything a viewer sent in has to be reportable
            // from the screen showing it, not only from the website.
            if ChannelLinks.report != nil {
                Button("Report") { reporting = true }
                    .buttonStyle(SecondaryActionStyle())
                    .focused($action, equals: .report)
                    .accessibilityHint("Tell the channel something is wrong with this episode")
            }
        }
    }

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule().padding(.bottom, 26)

            Text("Chapters")
                .sectionLabel(size: 25, opacity: 0.55)
                .padding(.bottom, 18)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 26) {
                    ForEach(Array(episode.chapters.enumerated()), id: \.element.id) { index, chapter in
                        ChapterCard(
                            episode: episode,
                            label: chapter.label(index: index),
                            start: chapter.start,
                            width: 340,
                            height: 192
                        ) {
                            onPlay(episode, Double(chapter.start))
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.trailing, Theme.Metrics.safeH)
            }
            .scrollClipDisabled()
        }
    }

    private var relatedRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule().padding(.bottom, 26)

            EpisodeRail(
                title: "More from \(episode.showTitle)",
                episodes: related,
                cardWidth: 340,
                artHeight: 192,
                focusedEpisode: $cardFocus,
                onSelect: onOpen
            )
        }
    }

    private func toggleList() {
        if let existing = list.first(where: { $0.episodeID == episode.id }) {
            context.delete(existing)
        } else {
            context.insert(ListEntry(episodeID: episode.id))
        }
    }
}

struct ChapterCard: View {
    var episode: Episode?
    let label: String
    /// Seconds from the start, spoken by VoiceOver so the card is not just
    /// "01, The interview room" with no sense of where it sits.
    var start: Int
    var width: CGFloat
    var height: CGFloat
    var action: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                EpisodeArt(episode: episode).frame(width: width, height: height)
            }
            .buttonStyle(ArtCardStyle())
            .focused($focused)
            .accessibilityLabel(label)
            .accessibilityValue("Starts at \(Resume.timecode(Double(start)))")
            .accessibilityHint("Plays from this chapter")

            Text(label)
                .archivo(.bold, 29)
                .foregroundStyle(focused ? Theme.paper : Theme.paper(0.75))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .frame(width: width, alignment: .leading)
        .animation(.easeOut(duration: 0.15), value: focused)
        .accessibilityElement(children: .contain)
    }
}
