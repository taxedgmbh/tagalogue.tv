// swift-tools-version: 5.9
//
// A test package, not a shipping one.
//
// The app is an Xcode project and stays one. This exists so the logic in
// `Shared/` — which both the app and the Top Shelf extension compile, and
// which decides what a viewer is allowed to see — can be tested with
// `swift test`, without adding a target to the project that builds and signs
// the shipping app.
//
// It deliberately covers only Foundation-pure code. `WatchProgress` is a
// SwiftData @Model and belongs to the app target; `Resume`, which lives beside
// it, is pure but is not worth dragging SwiftData in here for.

import PackageDescription

let package = Package(
    name: "TagalogueCatalog",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "TagalogueCatalog",
            path: "tagalogue.tv/Shared"
        ),
        .testTarget(
            name: "TagalogueCatalogTests",
            dependencies: ["TagalogueCatalog"],
            path: "Tests/TagalogueCatalogTests"
        ),
    ]
)
