//
//  ContentView.swift
//  tagalogue.tv
//

import SwiftUI
import SwiftData

enum Route: Hashable {
    case detail(Episode)
    case player(episode: Episode, startAt: Double)
}

struct ContentView: View {
    @State private var store = CatalogStore()
    @State private var section: AppSection = .home
    @State private var path: [Route] = []

    /// The card last focused in each section. tvOS scrolls to follow focus, so
    /// restoring focus on re-entry restores the scroll position with it —
    /// Home → Interviews → Home no longer dumps you back at the top.
    @State private var lastFocused: [AppSection: String] = [:]

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var progress: [WatchProgress]
    @Query private var list: [ListEntry]

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                NavBar(selection: $section, showsRule: section != .home)
                    .padding(.top, Theme.Metrics.safeV)
                    // Home disables scroll clipping so a focused card can lift
                    // past the edge of its rail without being cut off. The
                    // cost is that scrolled content is free to draw outside
                    // the scroll view entirely — including straight over the
                    // nav bar. A scrim to keep the bar readable over whatever
                    // is passing under it, and a zIndex so it passes *under*.
                    .background(alignment: .top) {
                        LinearGradient(
                            colors: [Theme.ink.opacity(0.96), Theme.ink.opacity(0.82), Theme.ink.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: Theme.Metrics.navHeight + Theme.Metrics.safeV + 40)
                        .allowsHitTesting(false)
                    }
                    .focusSection()
                    .zIndex(1)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.ink)
            // Has to sit *inside* the NavigationStack, on the content itself.
            // On the stack it only let the background bleed: the stack still
            // handed its root the full insets, which then stacked with the
            // 90/60 padding below and put every screen ~89pt right and 120pt
            // low, clipping the full-bleed hero 80pt short of the frame.
            .ignoresSafeArea()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let episode):
                    DetailView(
                        episode: episode,
                        related: related(to: episode),
                        onPlay: { ep, start in path.append(.player(episode: ep, startAt: start)) },
                        onOpen: { path.append(.detail($0)) }
                    )
                    .background(Theme.ink)
                    .ignoresSafeArea()

                case .player(let episode, let startAt):
                    PlayerScreen(
                        episode: episode,
                        startAt: startAt,
                        onProgress: { position, duration in
                            record(episode: episode, position: position, duration: duration)
                        },
                        onFinished: {
                            markComplete(episode)
                            pop()
                        },
                        onExit: { pop() }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .background(Theme.ink)
        .onOpenURL { open($0) }
        .task {
            // The channel may have changed since this Apple TV last looked.
            await store.refresh()
        }
        // `.task` runs once, when the view first appears. tvOS suspends an app
        // rather than terminating it, so coming back to the channel days later
        // is usually a *resume* — the view never reappears and the catalog was
        // never re-read. An episode published in the meantime stayed invisible
        // until something forced a cold launch, which reads as "the app has to
        // be updated to get new videos". It does not; it has to look again.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refresh() }
        }
    }

    /// Handles `tagaloguetv://` links from the Top Shelf. An unknown episode id
    /// is ignored rather than pushing an empty screen — the catalog can have
    /// moved on since the home screen last cached the shelf.
    private func open(_ url: URL) {
        guard let destination = DeepLink.destination(for: url) else { return }
        switch destination {
        case .detail(let id):
            guard let episode = store.anyEpisode(id: id) else { return }
            path = [.detail(episode)]
        case .play(let id):
            guard let episode = store.anyEpisode(id: id) else { return }
            path = [.player(episode: episode, startAt: resume(for: episode)?.startPosition ?? 0)]
        }
    }

    @ViewBuilder private var content: some View {
        if let error = store.loadError {
            unavailable(error)
        } else {
            switch section {
            case .home:
                HomeView(
                    catalog: store.catalog,
                    progress: progress,
                    list: list,
                    focusedEpisode: focusBinding(for: .home),
                    onPlay: { play($0) },
                    onDetail: { path.append(.detail($0)) }
                )
                .focusSection()

            case .interviews, .vlogs:
                if let id = section.showID, let show = store.catalog.show(id: id) {
                    CategoryGridView(
                        show: show,
                        progressFor: { resume(for: $0) },
                        focusedEpisode: focusBinding(for: section)
                    ) {
                        path.append(.detail($0))
                    }
                    .focusSection()
                }

            case .myList:
                MyListView(
                    catalog: store.catalog,
                    progressFor: { resume(for: $0) },
                    focusedEpisode: focusBinding(for: .myList)
                ) {
                    path.append(.detail($0))
                }
                .focusSection()

            case .community:
                CommunityView(
                    catalog: store.catalog,
                    progressFor: { resume(for: $0) },
                    focusedEpisode: focusBinding(for: .community)
                ) {
                    path.append(.detail($0))
                }
                .focusSection()

            case .search:
                SearchView(catalog: store.catalog) { path.append(.detail($0)) }
                    .focusSection()
            }
        }
    }

    private func unavailable(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Catalog unavailable")
                .archivo(.black, 48, tracking: -0.02)
                .foregroundStyle(Theme.paper)
            Text(error)
                .archivo(.regular, 29)
                .foregroundStyle(Theme.paper(0.6))
                .frame(maxWidth: 900, alignment: .leading)
        }
        .padding(.horizontal, Theme.Metrics.safeH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: Focus restoration

    private func focusBinding(for section: AppSection) -> Binding<String?> {
        Binding(
            get: { lastFocused[section] },
            set: { if let new = $0 { lastFocused[section] = new } }
        )
    }

    // MARK: Playback

    /// Reconciled progress for an episode, or nil when it has never been played.
    private func resume(for episode: Episode) -> Resume? {
        episode.resume(from: progress.first { $0.episodeID == episode.id })
    }

    /// Starts at the stored position when there is one worth resuming, held
    /// clear of the end so a stale marker cannot drop the viewer on the credits.
    private func play(_ episode: Episode) {
        path.append(.player(episode: episode, startAt: resume(for: episode)?.startPosition ?? 0))
    }

    private func related(to episode: Episode) -> [Episode] {
        store.catalog.byRecency
            .filter { $0.showID == episode.showID && $0.id != episode.id }
            .prefix(8)
            .map { $0 }
    }

    private func record(episode: Episode, position: Double, duration: Double) {
        guard position > 0 else { return }
        write(episodeID: episode.id, position: position, duration: duration)
    }

    /// Called when playback reaches the end. Stores the catalog's own duration
    /// on both sides so the episode reads as complete regardless of what the
    /// asset claimed its length was.
    private func markComplete(_ episode: Episode) {
        let full = Double(episode.duration)
        write(episodeID: episode.id, position: full, duration: full)
    }

    private func write(episodeID: String, position: Double, duration: Double) {
        if let existing = progress.first(where: { $0.episodeID == episodeID }) {
            existing.position = position
            existing.duration = duration
            existing.updatedAt = .now
        } else {
            context.insert(WatchProgress(episodeID: episodeID, position: position, duration: duration))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WatchProgress.self, ListEntry.self], inMemory: true)
}
