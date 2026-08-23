//
//  DeepLink.swift
//  tagalogue.tv  ·  Shared
//
//  The Top Shelf hands the app a URL when a viewer picks an episode from the
//  home screen. Both ends build and read it through here so the scheme can
//  only be spelled one way.
//
//  Registered as CFBundleURLTypes in the app's Info.plist.
//

import Foundation

enum DeepLink {
    static let scheme = "tagaloguetv"

    /// tagaloguetv://episode/int-42
    static func detail(_ episodeID: String) -> URL {
        URL(string: "\(scheme)://episode/\(episodeID)")!
    }

    /// tagaloguetv://play/int-42
    static func play(_ episodeID: String) -> URL {
        URL(string: "\(scheme)://play/\(episodeID)")!
    }

    enum Destination: Equatable {
        case detail(episodeID: String)
        case play(episodeID: String)
    }

    static func destination(for url: URL) -> Destination? {
        guard url.scheme == scheme else { return nil }
        let id = url.lastPathComponent
        guard !id.isEmpty else { return nil }
        switch url.host {
        case "episode": return .detail(episodeID: id)
        case "play":    return .play(episodeID: id)
        default:        return nil
        }
    }
}
