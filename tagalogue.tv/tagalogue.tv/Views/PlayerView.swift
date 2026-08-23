//
//  PlayerView.swift
//  tagalogue.tv
//
//  04 · Player
//
//  AVPlayerViewController rather than SwiftUI's VideoPlayer: on tvOS it is what
//  supplies the full transport bar, scrubbing, chapter navigation and the
//  subtitle/audio menus. Its chrome is system-drawn, so the Archivo-and-red
//  transport in the design doc is not reachable from here — matching it exactly
//  would mean hand-building transport, scrubbing and media selection on top of
//  AVPlayer, which is a much larger piece of work.
//
//  Chapters are handed to the system via AVNavigationMarkersGroup, which gives
//  the native chapter strip and swipe-to-skip.
//
//  What *is* ours is everything around the transport: when to seek, what to
//  record, and what a failed stream looks like.
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct PlayerView: UIViewControllerRepresentable {
    let episode: Episode
    var startAt: Double = 0
    /// Already-blurred ambient wash, shown behind the picture. Passed in
    /// rather than built here because it is generated asynchronously.
    var backdrop: UIImage?
    /// Called as playback progresses so resume positions can be persisted.
    var onProgress: (Double, Double) -> Void
    /// Playback reached the end.
    var onFinished: () -> Void
    /// The stream could not be played.
    var onFailure: (PlaybackFailure) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            episode: episode,
            // A trimmed episode starts at its in point, and a resume position
            // is measured from there, not from the head of the file.
            requestedStart: episode.startOffset + startAt,
            catalogDuration: Double(episode.duration),
            onProgress: onProgress,
            onFinished: onFinished,
            onFailure: onFailure
        )
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // tvOS will not raise the volume for a session that never declared
        // itself playback.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let asset = AVURLAsset(url: episode.playbackURL)
        let item = AVPlayerItem(asset: asset)

        if !episode.chapters.isEmpty {
            item.navigationMarkerGroups = [makeChapterGroup(for: item)]
        }

        let player = AVPlayer(playerItem: item)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .clear

        // Both extra layers live inside AVKit's own hierarchy rather than in a
        // SwiftUI ZStack around it: the player takes over the screen on tvOS,
        // so anything stacked outside it simply never appears.
        context.coordinator.installAmbient(in: controller)
        context.coordinator.installChannelBug(in: controller)

        context.coordinator.attach(to: player, item: item)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        // Re-asserted every update: setting gravity once before the view
        // loads does not stick, and a 9:16 clip was being cropped to fill.
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .clear
        context.coordinator.show(backdrop: backdrop)
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        // Flush before tearing down. The periodic observer only fires every 5s,
        // so without this a resume point is up to five seconds stale — and
        // leaving inside the first five seconds recorded nothing at all.
        coordinator.flush()
        coordinator.detach()
        UpNext.clear()
        controller.player?.pause()
        controller.player = nil
    }

    /// Chapter markers, each carrying its title so the system strip can label it.
    private func makeChapterGroup(for item: AVPlayerItem) -> AVNavigationMarkersGroup {
        let markers: [AVTimedMetadataGroup] = episode.chapters.enumerated().map { index, chapter in
            let end = index + 1 < episode.chapters.count
                ? Double(episode.chapters[index + 1].start)
                : Double(episode.duration)

            let title = AVMutableMetadataItem()
            title.identifier = .commonIdentifierTitle
            title.value = chapter.title as NSString
            title.extendedLanguageTag = "und"

            let range = CMTimeRange(
                start: CMTime(seconds: Double(chapter.start), preferredTimescale: 600),
                end:   CMTime(seconds: end, preferredTimescale: 600)
            )
            return AVTimedMetadataGroup(items: [title], timeRange: range)
        }
        return AVNavigationMarkersGroup(title: "Chapters", timedNavigationMarkers: markers)
    }

    final class Coordinator {
        private let episode: Episode
        private let requestedStart: Double
        private let catalogDuration: Double
        private let onProgress: (Double, Double) -> Void
        private let onFinished: () -> Void
        private let onFailure: (PlaybackFailure) -> Void

        private var timeObserver: Any?
        private var statusObservation: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?
        private var stalledObserver: NSObjectProtocol?
        private weak var player: AVPlayer?
        private var hasStarted = false
        private var hasFinished = false
        private weak var backdropView: UIImageView?

        init(
            episode: Episode,
            requestedStart: Double,
            catalogDuration: Double,
            onProgress: @escaping (Double, Double) -> Void,
            onFinished: @escaping () -> Void,
            onFailure: @escaping (PlaybackFailure) -> Void
        ) {
            self.episode = episode
            self.requestedStart = requestedStart
            self.catalogDuration = catalogDuration
            self.onProgress = onProgress
            self.onFinished = onFinished
            self.onFailure = onFailure
        }

        /// The blurred wash behind a picture that does not fill the frame.
        ///
        /// A 9:16 clip on a 16:9 screen otherwise sits between two black voids
        /// using about a quarter of the display. This is the treatment YouTube
        /// and Apple Music use: the picture's own colour thrown far out of
        /// focus, carrying the rest of the screen. It goes in at index 0 of the
        /// player's own view, which is the only place that is reliably behind
        /// the video layer.
        func installAmbient(in controller: AVPlayerViewController) {
            let view = UIImageView()
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.frame = controller.view.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.alpha = 0
            controller.view.insertSubview(view, at: 0)
            backdropView = view
        }

        /// The channel bug, as a broadcaster sets it: small, inside the safe
        /// area, never in the way. `contentOverlayView` puts it above the
        /// picture but beneath the transport, so it never fights the controls.
        /// Screen 04 of the design package puts the mark top-left at 104pt;
        /// this sits top-right, as asked.
        func installChannelBug(in controller: AVPlayerViewController) {
            guard let overlay = controller.contentOverlayView,
                  let mark = UIImage(named: "mark-dark") else { return }

            let bug = UIImageView(image: mark)
            bug.contentMode = .scaleAspectFit
            bug.alpha = 0.92
            bug.layer.shadowColor = UIColor.black.cgColor
            bug.layer.shadowOpacity = 0.55
            bug.layer.shadowRadius = 10
            bug.layer.shadowOffset = CGSize(width: 0, height: 2)
            bug.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(bug)

            NSLayoutConstraint.activate([
                bug.topAnchor.constraint(equalTo: overlay.topAnchor,
                                         constant: Theme.Metrics.safeV),
                bug.trailingAnchor.constraint(equalTo: overlay.trailingAnchor,
                                              constant: -Theme.Metrics.safeH),
                // Screen 04 draws the mark at 104pt; 92 leaves the artwork's
                // own padding and still reads from ten feet.
                bug.heightAnchor.constraint(equalToConstant: 92)
            ])
        }

        func show(backdrop: UIImage?) {
            guard let backdropView, let backdrop, backdropView.image !== backdrop else { return }
            backdropView.image = backdrop
            UIView.animate(withDuration: 0.45) { backdropView.alpha = 1 }
        }

        func attach(to player: AVPlayer, item: AVPlayerItem) {
            self.player = player

            // Seek only once the item can tell us how long it is. Seeking
            // straight after init "succeeds" against an unknown duration and
            // silently clamps: a resume point past the end of the asset lands
            // on the last frame, and the next tick writes that back as
            // progress, retiring the episode from Continue Watching for good.
            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch item.status {
                    case .readyToPlay: self.start(player: player, item: item)
                    case .failed:      self.fail(item.error)
                    default:           break
                    }
                }
            }

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.finish() }
            }

            stalledObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                Task { @MainActor [weak self] in self?.fail(error) }
            }
        }

        private func start(player: AVPlayer, item: AVPlayerItem) {
            guard !hasStarted else { return }
            let assetDuration = item.duration.seconds
            guard assetDuration.isFinite, assetDuration > 0 else {
                // Live or unknown length — just play from the top.
                hasStarted = true
                player.play()
                return
            }
            hasStarted = true

            // Never drop the viewer on the credits, and never past the end.
            // Never past the out point, and never past the end of the file.
            let outPoint = episode.endOffset ?? assetDuration
            let ceiling = max(episode.startOffset, min(outPoint, assetDuration) - Resume.endGuardSeconds)
            let target = min(max(requestedStart, episode.startOffset), ceiling)

            if target > 1 {
                player.seek(
                    to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600)
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.beginObservingTime(player)
                        player.play()
                    }
                }
            } else {
                beginObservingTime(player)
                player.play()
            }
        }

        private func beginObservingTime(_ player: AVPlayer) {
            guard timeObserver == nil else { return }
            // Every 5s is plenty for a resume position and stays cheap.
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] _ in
                // addPeriodicTimeObserver was given the main queue, so this is
                // already the main actor — just tell the compiler so.
                MainActor.assumeIsolated { [weak self] in self?.report() }
            }
        }

        /// Writes the current position out. Safe to call at any time.
        func flush() { report() }

        private func report() {
            guard hasStarted, !hasFinished,
                  let player, let item = player.currentItem
            else { return }

            let absolute = player.currentTime().seconds
            guard absolute.isFinite, absolute > 0 else { return }

            // A trimmed episode ends where the editor said, not where the file
            // does. Reaching the out point is the end as far as the app is
            // concerned — Continue Watching, "watched", all of it.
            if let outPoint = episode.endOffset, absolute >= outPoint {
                player.pause()
                finish()
                return
            }

            // Everything downstream thinks in terms of the clip the viewer was
            // shown, so positions are measured from the in point.
            let position = max(0, absolute - episode.startOffset)
            let duration = item.duration.seconds
            let assetLength = duration.isFinite && duration > 0 ? duration : catalogDuration
            let resolved = (episode.endOffset ?? assetLength) - episode.startOffset

            // Feeds the Siri Remote's info panel today, and is one of the two
            // app-side prerequisites for Up Next. See Services/UpNext.swift.
            UpNext.report(
                episode: episode,
                position: position,
                duration: resolved,
                rate: Double(player.rate)
            )
            onProgress(position, resolved)
        }

        private func finish() {
            guard !hasFinished else { return }
            hasFinished = true
            onFinished()
        }

        private func fail(_ error: Error?) {
            guard !hasFinished else { return }
            hasFinished = true
            onFailure(PlaybackFailure(error))
        }

        func detach() {
            if let timeObserver { player?.removeTimeObserver(timeObserver) }
            timeObserver = nil
            statusObservation?.invalidate()
            statusObservation = nil
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let stalledObserver { NotificationCenter.default.removeObserver(stalledObserver) }
            endObserver = nil
            stalledObserver = nil
        }

        deinit {
            statusObservation?.invalidate()
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let stalledObserver { NotificationCenter.default.removeObserver(stalledObserver) }
        }
    }
}

/// Full-screen player presentation, with the ink ground behind it.
struct PlayerScreen: View {
    let episode: Episode
    var startAt: Double
    var onProgress: (Double, Double) -> Void
    var onFinished: () -> Void
    var onExit: () -> Void

    @State private var failure: PlaybackFailure?
    /// Bumping this rebuilds the representable, which is how "Try again"
    /// gets a fresh AVPlayer rather than a re-run of the failed one.
    @State private var attempt = 0

    @State private var backdrop: UIImage?

    var body: some View {
        ZStack {
            Theme.ink

            if let failure {
                PlaybackErrorCard(
                    episode: episode,
                    failure: failure,
                    onRetry: {
                        self.failure = nil
                        attempt += 1
                    },
                    onExit: onExit
                )
            } else {
                PlayerView(
                    episode: episode,
                    startAt: startAt,
                    backdrop: backdrop,
                    onProgress: onProgress,
                    onFinished: onFinished,
                    onFailure: { failure = $0 }
                )
                .id(attempt)
            }
        }
        .ignoresSafeArea()
        .task(id: episode.id) {
            backdrop = await AmbientBackdrop.image(for: episode)
        }
    }
}

/// The ambient wash behind the picture — a frame of the video itself, thrown
/// far out of focus.
///
/// Taken from the asset rather than the artwork so the colour matches what is
/// actually on screen. Generated small (it is blurred past recognition anyway),
/// blurred once with Core Image rather than per-frame by the view, and darkened
/// so the picture still reads as the brightest thing on the display.
enum AmbientBackdrop {
    static func image(for episode: Episode) async -> UIImage? {
        guard let frame = await sourceFrame(for: episode) else { return nil }
        return blurred(frame)
    }

    private static func sourceFrame(for episode: Episode) async -> CGImage? {
        // A stream that will not yield a frame still deserves a backdrop.
        await MediaProbe.posterFrame(of: episode.playbackURL)
            ?? episode.artworkResource.flatMap(BundledArtwork.image(named:))?.cgImage
    }

    private static func blurred(_ frame: CGImage) -> UIImage? {
        let input = CIImage(cgImage: frame)

        // Clamp first, or the blur samples transparent black past the edges
        // and the wash comes out with dark borders.
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return UIImage(cgImage: frame) }
        blur.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        blur.setValue(42, forKey: kCIInputRadiusKey)

        guard let softened = blur.outputImage?.cropped(to: input.extent) else {
            return UIImage(cgImage: frame)
        }

        // Pull the brightness and saturation down: the wash is scenery, the
        // picture is the subject.
        let graded = softened.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: -0.18,
            kCIInputSaturationKey: 0.75,
            kCIInputContrastKey: 0.92
        ])

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let out = context.createCGImage(graded, from: input.extent) else {
            return UIImage(cgImage: frame)
        }
        return UIImage(cgImage: out)
    }
}

/// The one part of the player that is ours to draw, so it is drawn to the
/// system: ink ground, accent label, square corners, flush left.
private struct PlaybackErrorCard: View {
    let episode: Episode
    let failure: PlaybackFailure
    var onRetry: () -> Void
    var onExit: () -> Void

    private enum Action: Hashable { case retry, back }
    @FocusState private var action: Action?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Playback failed")
                .archivo(.bold, 25, tracking: 0.16)
                .textCase(.uppercase)
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 18)

            Text(episode.title)
                .archivo(.black, 57, tracking: -0.02)
                .foregroundStyle(Theme.paper)
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(.bottom, 16)

            Text(failure.headline)
                .archivo(.regular, 29)
                .lineSpacing(6)
                .foregroundStyle(Theme.paper(0.7))
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.bottom, failure.detail == nil ? 34 : 14)

            // The underlying error, kept small: useless to a viewer, but the
            // first thing anyone will ask for when they report the problem.
            if let detail = failure.detail {
                Text(detail)
                    .archivo(.regular, 23)
                    .foregroundStyle(Theme.paper(0.4))
                    .frame(maxWidth: 900, alignment: .leading)
                    .padding(.bottom, 34)
            }

            HStack(spacing: 16) {
                Button("Try again", action: onRetry)
                    .buttonStyle(PrimaryActionStyle())
                    .focused($action, equals: .retry)
                Button("Back", action: onExit)
                    .buttonStyle(SecondaryActionStyle())
                    .focused($action, equals: .back)
            }
        }
        .padding(.horizontal, Theme.Metrics.safeH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.ink)
        .defaultFocus($action, .retry)
    }
}


/// A playback failure in words a viewer can act on.
///
/// AVFoundation's own message is a domain and a negative integer
/// ("CoreMediaErrorDomain error -16044"), which tells a viewer nothing and
/// tells support only slightly more. The headline says what happened and what
/// to do; the raw description is kept underneath for bug reports.
struct PlaybackFailure: Equatable {
    let headline: String
    let detail: String?

    init(_ error: Error?) {
        let ns = error as NSError?
        switch (ns?.domain, ns?.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost),
             (NSURLErrorDomain, NSURLErrorCannotConnectToHost):
            headline = "This Apple TV can’t reach the internet. Check the connection and try again."
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            headline = "The connection timed out before the episode could start."
        case (NSURLErrorDomain, NSURLErrorFileDoesNotExist),
             (NSURLErrorDomain, NSURLErrorBadURL),
             (NSURLErrorDomain, NSURLErrorUnsupportedURL):
            headline = "This episode isn’t available right now. It may have moved."
        default:
            headline = "This episode couldn’t be played."
        }
        detail = error?.localizedDescription
    }
}
