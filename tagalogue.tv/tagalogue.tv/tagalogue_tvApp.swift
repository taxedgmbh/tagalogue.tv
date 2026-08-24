//
//  tagalogue_tvApp.swift
//  tagalogue.tv
//
//  Created by Emanuel Flury on 22.08.2026.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

@main
struct tagalogue_tvApp: App {
    /// Resume positions and My List.
    ///
    /// Both are conveniences: losing them costs a viewer their place in an
    /// episode, which is a bad evening. Refusing to launch costs them the
    /// channel entirely, with no remedy but deleting the app — so an
    /// unreadable store is stepped down through rather than fatal.
    ///
    /// The steps are: the store as it is, then a fresh one in its place, then
    /// memory only. The channel itself is unaffected by all of this; it comes
    /// from the network.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([WatchProgress.self, ListEntry.self])

        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
        ) { return container }

        // Unreadable on disk — a bad migration, a truncated write, a purge
        // under storage pressure. Take the store and its write-ahead log out of
        // the way and start again.
        let storeURL = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
        for suffix in ["", "-shm", "-wal"] {
            let sidecar = storeURL.deletingLastPathComponent()
                .appendingPathComponent(storeURL.lastPathComponent + suffix)
            try? FileManager.default.removeItem(at: sidecar)
        }

        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
        ) { return container }

        // Last resort: this launch keeps no history, but it launches.
        return try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }()

    init() {
        #if DEBUG
        Diagnostics.reportArchivoAvailability()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

#if DEBUG
enum Diagnostics {
    /// Archivo is bundled, not a system face — if UIAppFonts is misconfigured the
    /// whole interface silently falls back to the system sans, which is easy to
    /// miss on a TV. This says so in the console instead.
    static func reportArchivoAvailability() {
        let names = UIFont.familyNames
            .filter { $0.localizedCaseInsensitiveContains("archivo") }
            .flatMap { UIFont.fontNames(forFamilyName: $0) }
            .sorted()
        if names.isEmpty {
            print("[Tagalogue] Archivo did NOT register — check UIAppFonts in Info.plist. Falling back to system font.")
        } else {
            print("[Tagalogue] Archivo registered: \(names.joined(separator: ", "))")
        }
    }
}
#endif
