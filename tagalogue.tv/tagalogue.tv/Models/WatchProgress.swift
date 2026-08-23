//
//  WatchProgress.swift
//  tagalogue.tv
//
//  Resume positions and My List, persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class WatchProgress {
    /// Episode id.
    @Attribute(.unique) var episodeID: String
    /// Seconds watched.
    var position: Double
    /// Duration as the *asset* reported it, which is not necessarily what the
    /// catalog says. Kept for diagnostics; `Resume` decides which to believe.
    var duration: Double
    var updatedAt: Date

    init(episodeID: String, position: Double, duration: Double, updatedAt: Date = .now) {
        self.episodeID = episodeID
        self.position = position
        self.duration = duration
        self.updatedAt = updatedAt
    }
}

@Model
final class ListEntry {
    @Attribute(.unique) var episodeID: String
    var addedAt: Date

    init(episodeID: String, addedAt: Date = .now) {
        self.episodeID = episodeID
        self.addedAt = addedAt
    }
}

// MARK: - Reconciled progress

/// Playback progress read back against the catalog.
///
/// The stream's own duration is only trusted when it agrees with the catalog to
/// within 5%. It has to work this way: a placeholder stream, a re-encode, a
/// trailer or a mid-roll of the wrong length would otherwise push `fraction`
/// straight past the completion threshold and silently retire an episode from
/// Continue Watching. The catalog is the authority; the asset is a hint.
struct Resume: Hashable {
    /// Seconds, clamped into the catalog's duration.
    let position: Double
    /// Seconds, always the catalog's figure.
    let duration: Double
    /// False when the asset's duration disagreed materially with the catalog's.
    let streamAgreesWithCatalog: Bool

    /// Anything past this counts as watched and drops out of Continue Watching.
    static let completionThreshold = 0.95
    /// Below this there is nothing worth resuming — treat it as unstarted.
    static let minimumResumeSeconds: Double = 30
    /// Never drop a viewer at the very end of a file.
    static let endGuardSeconds: Double = 10

    /// 0...1
    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    var isComplete: Bool { fraction > Self.completionThreshold }

    var isResumable: Bool { !isComplete && position >= Self.minimumResumeSeconds }

    /// Where playback should actually start, held clear of the end.
    var startPosition: Double {
        guard isResumable else { return 0 }
        return min(position, max(0, duration - Self.endGuardSeconds))
    }

    /// "20 min left"
    var remainingLabel: String {
        let left = max(duration - position, 0)
        let minutes = Int((left / 60).rounded(.up))
        return minutes <= 1 ? "1 min left" : "\(minutes) min left"
    }

    /// "17:52 of 38 min"
    var positionLabel: String {
        "\(Resume.timecode(position)) of \(Int(duration / 60)) min"
    }

    /// "17:52", or "1:07:03" once past the hour.
    static func timecode(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

extension Episode {
    /// Reconciles a stored position against this episode's catalog duration.
    /// Returns nil when there is no stored progress at all.
    func resume(from progress: WatchProgress?) -> Resume? {
        guard let progress else { return nil }
        let catalogDuration = Double(duration)
        guard catalogDuration > 0 else { return nil }

        let agrees = progress.duration > 0
            && abs(progress.duration - catalogDuration) / catalogDuration <= 0.05

        return Resume(
            position: min(max(progress.position, 0), catalogDuration),
            duration: catalogDuration,
            streamAgreesWithCatalog: agrees
        )
    }
}
