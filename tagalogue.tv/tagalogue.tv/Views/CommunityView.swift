//
//  CommunityView.swift
//  tagalogue.tv
//
//  07 · Community — where the people who watch send something back.
//
//  The code on screen leads to the channel's own submission page, not to this
//  Apple TV. That matters: a follower's video has to reach Taxed GmbH, not sit
//  on the television in their living room. It also means this screen needs no
//  server, no local network permission and no special build — it draws a code
//  and lists what has been approved.
//
//  Nothing a viewer sends appears here until an editor has watched it. That is
//  the whole reason the submission goes to the content tool first.
//

import SwiftUI

struct CommunityView: View {
    let catalog: Catalog
    var progressFor: (Episode) -> Resume?
    @Binding var focusedEpisode: String?
    var onSelect: (Episode) -> Void

    @FocusState private var cardFocus: String?

    /// Set `TagalogueSubmitURL` in Info.plist. Without it the invitation is
    /// hidden rather than showing a code that leads nowhere.
    private var submitURL: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "TagalogueSubmitURL") as? String,
              let url = URL(string: text.trimmingCharacters(in: .whitespaces)),
              !text.isEmpty
        else { return nil }
        return url
    }

    private var episodes: [Episode] {
        catalog.allEpisodes.filter { $0.showID == "community" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let submitURL {
                invitation(submitURL)
                    .padding(.horizontal, Theme.Metrics.safeH)
                    // Air under the nav bar, which carries the mark on this
                    // same left edge — the label was sitting almost against it.
                    .padding(.top, 72)
            }

            if !episodes.isEmpty {
                if submitURL != nil {
                    SectionRule()
                        .padding(.horizontal, Theme.Metrics.safeH)
                        .padding(.top, 48).padding(.bottom, 28)
                }
                // Only the grid scrolls. The invitation is the point of the
                // screen and it stays put: moving focus onto a card used to
                // scroll the heading up underneath the nav bar, so the screen
                // arrived already past its own title.
                ScrollView(.vertical) {
                    grid
                        .padding(.horizontal, Theme.Metrics.safeH)
                        .padding(.bottom, Theme.Metrics.safeV)
                }
                .scrollClipDisabled()
            } else if submitURL != nil {
                SectionRule()
                    .padding(.horizontal, Theme.Metrics.safeH)
                    .padding(.top, 48).padding(.bottom, 26)
                Text("Nothing has been sent in yet. Be the first.")
                    .archivo(.regular, 29)
                    .foregroundStyle(Theme.paper(0.5))
                    .padding(.horizontal, Theme.Metrics.safeH)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            if let saved = focusedEpisode, episodes.contains(where: { $0.id == saved }) {
                cardFocus = saved
            } else {
                cardFocus = episodes.first?.id
            }
        }
        .onChange(of: cardFocus) { _, new in
            if let new { focusedEpisode = new }
        }
    }

    private func invitation(_ url: URL) -> some View {
        // Centred against each other rather than both pinned to the top: the
        // copy column is much taller than the code, and top-aligning left the
        // code stranded against a long paragraph.
        HStack(alignment: .center, spacing: 80) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Community")
                    .sectionLabel(size: 25, opacity: 0.55)
                    .padding(.bottom, 24)
                    .accessibilityAddTraits(.isHeader)

                Text("Share your thoughts")
                    .archivo(.black, 62, tracking: -0.02)
                    .foregroundStyle(Theme.paper)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 820, alignment: .leading)
                    .padding(.bottom, 22)

                Text("Point your phone at the code, record something, and send it in. "
                     + "We watch every one before it goes out.")
                    .archivo(.regular, 29)
                    .lineSpacing(6)
                    .foregroundStyle(Theme.paper(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 820, alignment: .leading)
                    .padding(.bottom, 36)

                // The address, for anyone whose phone will not scan. Given a
                // plate of its own so it reads as something to copy rather
                // than as another line of the paragraph, and set in Archivo:
                // this interface has one family, and a lone monospaced string
                // was the only thing in the app breaking that.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Or type this in")
                        .archivo(.bold, 23, tracking: 0.16)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.paper(0.55))
                    Text(url.absoluteString)
                        .archivo(.semibold, 33, tracking: 0.01)
                        .foregroundStyle(Theme.paper)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .overlay(
                    Rectangle().strokeBorder(
                        Theme.paper(Theme.Metrics.idleRuleOpacity),
                        lineWidth: Theme.Metrics.rule
                    )
                )
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            code(url)
        }
    }

    /// The code, drawn 1:1 at whatever whole-module size it came out at, on a
    /// paper plate with a quiet zone around it. Never resized in the view —
    /// resampling it is what made the grid uneven in the first place.
    @ViewBuilder private func code(_ url: URL) -> some View {
        if let code = QRCode.image(for: url.absoluteString, fitting: 340) {
            VStack(spacing: 20) {
                Image(uiImage: code)
                    .interpolation(.none)
                    .padding(28)
                    .background(Theme.paper)
                    .accessibilityLabel("QR code linking to \(url.absoluteString)")

                Text("Scan with your phone")
                    .archivo(.bold, 23, tracking: 0.16)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.paper(0.55))
                    .accessibilityHidden(true)
            }
            .fixedSize()
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sent in by you")
                .sectionLabel(size: 25, opacity: 0.55)
                .padding(.bottom, 20)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 4),
                alignment: .leading, spacing: 34
            ) {
                ForEach(episodes) { episode in
                    EpisodeCard(episode: episode, resume: progressFor(episode)) {
                        onSelect(episode)
                    }
                    .focused($cardFocus, equals: episode.id)
                }
            }
        }
    }
}
