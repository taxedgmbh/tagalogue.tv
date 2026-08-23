//
//  UpNext.swift
//  tagalogue.tv
//
//  Groundwork for the Apple TV app's Up Next row.
//
//  Read this before assuming episodes will show up there. Up Next is not an
//  API an app can write to. Apple's integration has four parts:
//
//    1. A catalog feed submitted to Apple, which assigns every episode a
//       stable `contentId`. Business onboarding, not code.
//    2. The **universal search extended entitlement** on the provisioning
//       profile, which Apple grants as part of that onboarding.
//    3. Playback reported through the Now Playing API, carrying the same
//       contentId plus duration and elapsed time, so Up Next knows whether an
//       episode is finished or resumable.
//    4. `NSUserActivity` while a detail page is on screen, carrying the same
//       contentId, so "Hey Siri, add this to my Up Next" has something to add.
//
//  Parts 3 and 4 are here. Parts 1 and 2 are Taxed GmbH's to arrange with
//  Apple; until they exist this code earns its keep anyway — Now Playing
//  drives the Siri Remote's info panel and the system's playback state, and
//  the user activity makes episodes handoff- and Siri-addressable.
//
//  NOTE: `contentID` is currently the catalog's own episode id. When the feed
//  is submitted it must be whatever id that feed declares, or the two halves
//  will not match up.
//

import Foundation
import MediaPlayer

enum UpNext {

    /// Must also be listed under NSUserActivityTypes in Info.plist.
    static let activityType = "tv.tagalogue.appletv.viewing"
    static let contentIDKey = "contentId"

    /// The id Apple's catalog feed will key on. One place to change it.
    static func contentID(for episode: Episode) -> String { episode.id }

    // MARK: Now Playing

    /// Publishes what is playing, so the system — and eventually Up Next —
    /// knows the episode, how long it is and how far in the viewer has got.
    static func report(episode: Episode, position: Double, duration: Double, rate: Double) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.showTitle,
            MPMediaItemPropertyMediaType: MPMediaType.tvShow.rawValue,
            MPNowPlayingInfoPropertyExternalContentIdentifier: contentID(for: episode),
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPMediaItemPropertyPlaybackDuration: duration
        ]
        if episode.isNumbered {
            info[MPMediaItemPropertyAlbumTrackNumber] = episode.number
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    static func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: User activity

    static let deepLinkKey = "deepLink"

    /// Populates the activity a detail screen advertises while it is open.
    static func describe(_ activity: NSUserActivity, for episode: Episode) {
        activity.title = episode.title
        // `webpageURL` is NOT the place for the deep link: NSUserActivity
        // validates it as http/https and *throws* on any other scheme, which
        // took down every detail page. The custom-scheme link travels in
        // userInfo, where it is just data.
        activity.userInfo = [
            contentIDKey: contentID(for: episode),
            deepLinkKey: DeepLink.detail(episode.id).absoluteString
        ]
        activity.requiredUserInfoKeys = [contentIDKey]
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        // isEligibleForPrediction and persistentIdentifier are iOS-only.
    }
}
