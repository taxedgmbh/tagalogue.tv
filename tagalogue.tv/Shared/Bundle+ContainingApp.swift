//
//  Bundle+ContainingApp.swift
//  Shared
//
//  Compiled into both targets, because both need it for different reasons:
//  the Top Shelf extension reads the app's Info.plist and its bundled catalog
//  through this, and `RemoteCatalog` — which now runs in both — reads the
//  catalog addresses through it too.
//
//  In the app this is a no-op: `Bundle.main` is already the .app, so the loop
//  exits immediately.
//

import Foundation

extension Bundle {
    /// The .appex sits at `<App>.app/PlugIns/<Name>.appex`, so the containing
    /// app is the nearest enclosing `.app`.
    static var containingApp: Bundle {
        var url = Bundle.main.bundleURL
        while url.pathExtension != "app" && url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
        }
        return Bundle(url: url) ?? .main
    }
}
