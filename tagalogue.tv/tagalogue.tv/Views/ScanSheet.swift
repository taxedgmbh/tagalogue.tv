//
//  ScanSheet.swift
//  tagalogue.tv
//
//  A television cannot open a web page: there is no browser on tvOS, and no
//  useful way to type into one from a remote. So anything that has to reach the
//  web — reporting a video, reading the terms, reading the privacy policy —
//  is handed to the phone already in the room, as a code to scan and an address
//  to type if the camera will not cooperate.
//
//  This exists because the channel publishes video sent in by viewers, and
//  App Store Review guideline 1.2 requires an app carrying user-generated
//  content to offer a way to report something objectionable *from inside the
//  app*. A link on the website is not that.
//

import SwiftUI

struct ScanSheet: View {
    let title: String
    let message: String
    let url: URL
    var onClose: () -> Void

    @FocusState private var closeFocused: Bool

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            HStack(alignment: .center, spacing: 80) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .archivo(.black, 57, tracking: -0.02)
                        .foregroundStyle(Theme.paper)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 760, alignment: .leading)
                        .padding(.bottom, 22)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .archivo(.regular, 29)
                        .lineSpacing(6)
                        .foregroundStyle(Theme.paper(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 720, alignment: .leading)
                        .padding(.bottom, 34)

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

                    Button("Done", action: onClose)
                        .buttonStyle(PrimaryActionStyle())
                        .focused($closeFocused)
                        .padding(.top, 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
            .padding(.horizontal, Theme.Metrics.safeH)
        }
        .onAppear { closeFocused = true }
    }
}

/// The addresses the app hands to a phone. Kept in Info.plist rather than in
/// code so they can move with the site without a rebuild — the same reasoning
/// as the catalog URL.
enum ChannelLinks {
    static var report: URL? { url(for: "TagalogueReportURL") }
    static var terms: URL? { url(for: "TagalogueTermsURL") }
    static var privacy: URL? { url(for: "TagaloguePrivacyURL") }
    static var support: URL? { url(for: "TagalogueSupportURL") }

    private static func url(for key: String) -> URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
