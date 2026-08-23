//
//  tagalogue_tvApp.swift
//  tagalogue.tv
//
//  Created by Emanuel Flury on 22.08.2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct tagalogue_tvApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WatchProgress.self,
            ListEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
