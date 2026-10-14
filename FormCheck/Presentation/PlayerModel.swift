import AVFoundation
import Observation

@MainActor
@Observable
final class PlayerModel {
    let player: AVPlayer
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var videoSize = CGSize(width: 9, height: 16)
    private(set) var loadError: String?

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var isSeeking = false
    @ObservationIgnored private var pendingSeekTime: Double?
    @ObservationIgnored private var loopRange: ClosedRange<Double>?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 60), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let range = self.loopRange, time.seconds >= range.upperBound {
                    self.seek(to: range.lowerBound)
                    self.player.play()
                    self.isPlaying = true
                    return
                }
                self.currentTime = time.seconds
                let playing = self.player.timeControlStatus != .paused
                if playing != self.isPlaying { self.isPlaying = playing }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let range = self.loopRange {
                    self.seek(to: range.lowerBound)
                    self.player.play()
                    self.isPlaying = true
                } else {
                    self.isPlaying = false
                }
            }
        }

        Task { await loadMetadata(url) }
    }

    func playLoop(_ range: ClosedRange<Double>) {
        loopRange = range
        seek(to: range.lowerBound)
        player.play()
        isPlaying = true
    }

    func clearLoop() {
        loopRange = nil
    }

    func teardown() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlay() {
        if player.timeControlStatus == .paused {
            if duration > 0, currentTime >= duration - 0.05 { seek(to: 0) }
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }

    func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), duration > 0 ? duration : seconds)
        currentTime = clamped

        guard !isSeeking else {
            pendingSeekTime = clamped
            return
        }
        performSeek(to: clamped)
    }

    private func performSeek(to seconds: Double) {
        isSeeking = true
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSeeking = false
                if let next = self.pendingSeekTime {
                    self.pendingSeekTime = nil
                    self.performSeek(to: next)
                }
            }
        }
    }

    func step(by frames: Int) {
        player.pause()
        isPlaying = false
        player.currentItem?.step(byCount: frames)
        currentTime = player.currentTime().seconds
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentTime = self.player.currentTime().seconds
        }
    }

    private func loadMetadata(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            duration = try await asset.load(.duration).seconds
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
                let r = CGRect(origin: .zero, size: size).applying(transform)
                videoSize = CGSize(width: abs(r.width), height: abs(r.height))
            }
        } catch {
            loadError = "Couldn't load the video: \(error.localizedDescription)"
        }
    }
}
