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
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                if let submitURL { invitation(submitURL) }

                if !episodes.isEmpty {
                    if submitURL != nil {
                        SectionRule().padding(.top, 52).padding(.bottom, 30)
                    }
                    grid
                } else if submitURL != nil {
                    SectionRule().padding(.top, 52).padding(.bottom, 26)
                    Text("Nothing has been sent in yet. Be the first.")
                        .archivo(.regular, 29)
                        .foregroundStyle(Theme.paper(0.5))
                }
            }
            .padding(.horizontal, Theme.Metrics.safeH)
            .padding(.top, 54)
            .padding(.bottom, Theme.Metrics.safeV)
        }
        .scrollClipDisabled()
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
        HStack(alignment: .top, spacing: 90) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Community")
                    .sectionLabel(size: 25, opacity: 0.55)
                    .padding(.bottom, 20)
                    .accessibilityAddTraits(.isHeader)

                Text("Share your thoughts")
                    .archivo(.black, 57, tracking: -0.02)
                    .foregroundStyle(Theme.paper)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.bottom, 18)

                Text("Point your phone at the code, record something, and send it in. "
                     + "We watch every one before it goes out.")
                    .archivo(.regular, 29)
                    .lineSpacing(6)
                    .foregroundStyle(Theme.paper(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 700, alignment: .leading)
                    .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Or type this in")
                        .archivo(.semibold, 23, tracking: 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.paper(0.45))
                    Text(url.absoluteString)
                        .font(.system(size: 31, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.paper)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let code = QRCode.image(for: url.absoluteString) {
                Image(uiImage: code)
                    .resizable()
                    // No smoothing: scaled-up QR modules must stay hard-edged
                    // or a phone camera across the room struggles.
                    .interpolation(.none)
                    .frame(width: 360, height: 360)
                    .padding(26)
                    .background(Theme.paper)
                    .accessibilityLabel("QR code linking to \(url.absoluteString)")
            }
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
