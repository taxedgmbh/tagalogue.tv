//
//  NavBar.swift
//  tagalogue.tv
//
//  96pt bar: mark on the left, then the sections. The active section is
//  underlined with a 4pt accent rule.
//

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    // Order is the order on screen, and it is the order a viewer moves through:
    // the channel as a whole, then the three strands that make it up, then the
    // things that are theirs, then the way to go looking. Search sits last
    // because it is what you reach for when browsing has not worked.
    case home = "Home"
    case interviews = "Interviews"
    case vlogs = "Vlogs"
    case community = "Community"
    case myList = "My List"
    case search = "Search"

    var id: String { rawValue }

    /// Sections that map onto a show in the catalog.
    var showID: String? {
        switch self {
        case .interviews: "interviews"
        case .vlogs: "vlogs"
        default: nil
        }
    }
}

struct NavBar: View {
    @Binding var selection: AppSection
    var showsRule: Bool = false

    var body: some View {
        HStack(spacing: 56) {
            Image("mark-dark")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .accessibilityLabel("Tagalogue TV")

            HStack(spacing: 44) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Text(section.rawValue)
                    }
                    .buttonStyle(NavItemStyle(isActive: section == selection))
                    .accessibilityLabel(section.rawValue)
                    .accessibilityAddTraits(section == selection ? [.isSelected] : [])
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Metrics.safeH)
        .frame(height: Theme.Metrics.navHeight)
        .overlay(alignment: .bottom) {
            if showsRule {
                Rectangle()
                    .fill(Theme.paper(0.14))
                    .frame(height: Theme.Metrics.rule)
            }
        }
    }
}

private struct NavItemStyle: ButtonStyle {
    var isActive: Bool
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .archivo(.bold, 31, tracking: 0.02)
            .foregroundStyle(isActive || focused ? Theme.paper : Theme.paper(0.5))
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(focused ? Theme.paper : (isActive ? Theme.accent : .clear))
                    .frame(height: 4)
            }
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}
