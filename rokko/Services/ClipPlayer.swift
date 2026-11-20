//
//  ClipPlayer.swift
//  Plays one film / transformation clip in AVPlayer (no controls) and reports two things to the
//  coordinator: the clip time (for subtitles) and the clip's end. It never moves the lesson on
//  by itself; the coordinator decides what happens when a clip ends.
//

import AVFoundation
import Observation

@MainActor
@Observable
final class ClipPlayer {
    /// Drawn by `ClipVideoView`.
    @ObservationIgnored let player = AVPlayer()
    /// Seconds from the start of the current clip.
    private(set) var time: Double = 0
    /// A clip is loaded (playing or paused).
    private(set) var hasClip = false

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var onEnd: (() -> Void)?

    init(tickSeconds: Double) {
        player.actionAtItemEnd = .pause
        // The film has narration: play even with the silent switch on, like any video app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: tickSeconds, preferredTimescale: 600),
                                                      queue: .main) { [weak self] t in
            MainActor.assumeIsolated { self?.time = t.seconds.isFinite ? t.seconds : 0 }
        }
    }

    /// Starts `url` from the beginning. `onEnd` runs once, when the clip has played to its end.
    func play(_ url: URL, muted: Bool, onEnd: @escaping () -> Void) {
        clearEnd()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = muted
        time = 0
        hasClip = true
        self.onEnd = onEnd
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
                                                             object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let done = self.onEnd
                self.clearEnd()
                done?()
            }
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    func pause() { player.pause() }

    /// After the end: show the frame at `seconds` (the last bright one) and stay there.
    func hold(at seconds: Double) {
        player.pause()
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Carries on from where it paused (only while the clip has not ended).
    func resume() {
        guard hasClip, onEnd != nil else { return }
        player.play()
    }

    /// Clears the clip (step change, leaving the lesson).
    func stop() {
        clearEnd()
        player.pause()
        player.replaceCurrentItem(with: nil)
        time = 0
        hasClip = false
    }

    /// A player that goes away is always silent (never audio with no picture).
    isolated deinit {
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    private func clearEnd() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        onEnd = nil
    }
}
