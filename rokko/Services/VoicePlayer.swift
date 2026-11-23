//
//  VoicePlayer.swift
//  Plays the recorded voice lines (Resources/Audio/Voice/<key>.m4a, docs/VOICE.md) one after another,
//  with a short gap, and tells the caller which line is playing so its caption can show with it.
//  One player for the whole app: a new line always replaces the one before. Nothing plays when the
//  Guardian has turned sound off; captions still show.
//

import AVFoundation

@MainActor
final class VoicePlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = VoicePlayer()

    /// Guardian setting (Sound off): play nothing, captions only.
    var muted = false

    private var player: AVAudioPlayer?
    private var queue: [URL] = []
    private var index = 0
    private var gap: Double = 0
    private var onLine: ((Int) -> Void)?
    private var onDone: (() -> Void)?
    private var gapTask: Task<Void, Never>?
    private var generation = 0
    private var isPaused = false
    /// The gap ended while paused: the next line starts on resume.
    private var lineWaiting = false

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    /// The bundled file for a voice key, if it has been recorded.
    static func url(for key: String) -> URL? {
        Bundle.main.url(forResource: key, withExtension: "m4a")
    }

    /// Plays `keys` in order with `gapSeconds` between them. `onLine(i)` runs as line i starts;
    /// `onDone` after the last one (or at once when muted / no files). Returns false when no file
    /// exists for any key (the caller then falls back to timed captions).
    @discardableResult
    func play(_ keys: [String], gapSeconds: Double,
              onLine: ((Int) -> Void)? = nil, onDone: (() -> Void)? = nil) -> Bool {
        stop()
        let urls = keys.map(Self.url(for:))
        guard urls.contains(where: { $0 != nil }) else { return false }
        generation += 1
        queue = urls.map { $0 ?? URL(fileURLWithPath: "/dev/null") }
        index = 0
        gap = gapSeconds
        self.onLine = onLine
        self.onDone = onDone
        if muted {
            // Sound off: captions still follow the lines, each held for its length.
            playSilently(generation)
            return true
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        startLine()
        return true
    }

    func pause() {
        isPaused = true
        player?.pause()
    }

    func resume() {
        isPaused = false
        if lineWaiting {
            lineWaiting = false
            startLine()
        } else {
            player?.play()
        }
    }

    func stop() {
        generation += 1
        gapTask?.cancel()
        gapTask = nil
        player?.stop()
        player = nil
        queue = []
        lineWaiting = false
        onLine = nil
        onDone = nil
    }

    // MARK: -

    private func startLine() {
        guard index < queue.count else { finish(); return }
        onLine?(index)
        let p = try? AVAudioPlayer(contentsOf: queue[index])
        guard let p else { next(); return }   // a missing file just skips its sound
        p.delegate = self
        player = p
        p.play()
    }

    private func next() {
        index += 1
        guard index < queue.count else { finish(); return }
        let g = generation
        gapTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.gap ?? 0))
            guard let self, !Task.isCancelled, g == self.generation else { return }
            if self.isPaused { self.lineWaiting = true } else { self.startLine() }
        }
    }

    private func finish() {
        player = nil
        let done = onDone
        onLine = nil
        onDone = nil
        done?()
    }

    private func playSilently(_ g: Int) {
        gapTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for i in self.queue.indices {
                guard g == self.generation else { return }
                self.onLine?(i)
                let length = (try? AVAudioPlayer(contentsOf: self.queue[i]))?.duration ?? 0
                try? await Task.sleep(for: .seconds(length + self.gap))
            }
            guard g == self.generation else { return }
            self.finish()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        MainActor.assumeIsolated {
            guard player === self.player else { return }
            self.next()
        }
    }
}
