//
//  MediaProbe.swift
//  tagalogue.tv
//
//  Reading facts out of a video file: how long it is, and what a frame of it
//  looks like. Both the player's ambient backdrop and phone ingest need this,
//  and a second copy of the AVAssetImageGenerator dance is exactly the kind of
//  drift this project has been bitten by before.
//

import AVFoundation
import CoreGraphics
import UIKit

enum MediaProbe {

    /// Seconds, or nil for a live stream or an asset that will not load.
    static func duration(of url: URL) async -> Double? {
        let seconds = try? await AVURLAsset(url: url).load(.duration).seconds
        guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    /// A frame from the video.
    ///
    /// `at` is a request, not a promise: the generator is allowed a generous
    /// tolerance so it can land on a nearby keyframe instead of decoding a
    /// long way for an exact time. Pass nil to take one a third of the way in.
    ///
    /// `maxSize` is a ceiling, not a target — the generator keeps the aspect
    /// ratio. Callers asking for a blurred wash want this small; a poster
    /// destined for a 420pt card wants it large.
    static func posterFrame(
        of url: URL,
        at seconds: Double? = nil,
        maxSize: CGSize = CGSize(width: 1280, height: 1280)
    ) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)

        guard let duration = await duration(of: url) else { return nil }
        let wanted = seconds ?? duration / 3

        // Try the asked-for time, then progressively safer ones. A clip whose
        // first frames are black or still decoding should still get a poster.
        for candidate in [wanted, duration / 2, duration / 3, 1, 0] where candidate <= duration {
            let time = CMTime(seconds: max(0, min(candidate, duration - 0.1)), preferredTimescale: 600)
            if let (frame, _) = try? await generator.image(at: time) { return frame }
        }
        return nil
    }

    /// Several frames spread through the clip, so a poster can be chosen
    /// rather than accepted. Returns the time alongside each frame.
    static func candidateFrames(of url: URL, count: Int = 4) async -> [(seconds: Double, image: CGImage)] {
        guard let duration = await duration(of: url) else { return [] }
        var frames: [(Double, CGImage)] = []
        for step in 0..<count {
            let at = duration * (Double(step) + 0.5) / Double(count)
            if let image = await posterFrame(of: url, at: at) { frames.append((at, image)) }
        }
        return frames
    }
}
