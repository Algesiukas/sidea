import AVFoundation
import MediaPlayer
import Observation
import UIKit

/// Playback, queue, shuffle/repeat, background audio, lock-screen & Control Center controls.
@MainActor
@Observable
final class PlayerEngine: NSObject, AVAudioPlayerDelegate {
    enum RepeatMode {
        case off, all, one

        var next: RepeatMode {
            switch self {
            case .off: .all
            case .all: .one
            case .one: .off
            }
        }
    }

    private(set) var queue: [Track] = []
    private(set) var index: Int?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var shuffle = false
    private(set) var repeatMode: RepeatMode = .off

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var originalQueue: [Track] = []
    @ObservationIgnored private var resumeAfterInterruption = false

    var current: Track? {
        guard let index, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    var upNext: Track? {
        guard let index, !queue.isEmpty else { return nil }
        if repeatMode == .one { return current }
        if index + 1 < queue.count { return queue[index + 1] }
        return repeatMode == .all ? queue.first : nil
    }

    var progress: Double {
        duration > 0 ? min(max(currentTime / duration, 0), 1) : 0
    }

    override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        observeSessionNotifications()
    }

    // MARK: - Public controls

    /// Start playing `tracks`, beginning with the one at `startIndex`.
    func play(_ tracks: [Track], startAt startIndex: Int) {
        guard tracks.indices.contains(startIndex) else { return }
        originalQueue = tracks
        if shuffle {
            var rest = tracks
            let first = rest.remove(at: startIndex)
            rest.shuffle()
            queue = [first] + rest
            index = 0
        } else {
            queue = tracks
            index = startIndex
        }
        load(autoplay: true)
    }

    func playShuffled(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        shuffle = true
        play(tracks, startAt: Int.random(in: tracks.indices))
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard current != nil else { return }
        if player == nil {
            load(autoplay: true)
        } else {
            start()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        syncTime()
        updateNowPlaying()
    }

    func next() {
        guard let index, !queue.isEmpty else { return }
        self.index = index + 1 < queue.count ? index + 1 : 0
        load(autoplay: true)
    }

    func previous() {
        guard let index, !queue.isEmpty else { return }
        if (player?.currentTime ?? 0) > 3 {
            seek(to: 0)
            return
        }
        self.index = index > 0 ? index - 1 : queue.count - 1
        load(autoplay: true)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, 0), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlaying()
    }

    func toggleShuffle() {
        shuffle.toggle()
        guard let playing = current else { return }
        if shuffle {
            var rest = originalQueue.filter { $0.id != playing.id }
            rest.shuffle()
            queue = [playing] + rest
            index = 0
        } else {
            queue = originalQueue
            index = originalQueue.firstIndex { $0.id == playing.id } ?? 0
        }
    }

    func cycleRepeat() {
        repeatMode = repeatMode.next
    }

    /// Call before a file is deleted so playback never points at a missing file.
    func remove(trackID: String) {
        originalQueue.removeAll { $0.id == trackID }
        guard let removed = queue.firstIndex(where: { $0.id == trackID }) else { return }
        let wasCurrent = removed == index
        queue.remove(at: removed)

        if let index, removed < index { self.index = index - 1 }

        if wasCurrent {
            player?.stop()
            player = nil
            stopTimer()
            isPlaying = false
            if queue.isEmpty {
                index = nil
                duration = 0
                currentTime = 0
            } else {
                index = min(removed, queue.count - 1)
                load(autoplay: false)
            }
            updateNowPlaying()
        }
    }

    // MARK: - Loading & playback

    private func load(autoplay: Bool) {
        guard let track = current else { return }
        player?.stop()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: track.url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            if autoplay {
                start()
            } else {
                isPlaying = false
                stopTimer()
                updateNowPlaying()
            }
        } catch {
            player = nil
            isPlaying = false
            stopTimer()
            duration = 0
            currentTime = 0
            updateNowPlaying()
        }
    }

    private func start() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = player?.isPlaying ?? false
        if isPlaying { startTimer() }
        updateNowPlaying()
    }

    private func trackFinished() {
        guard let index else { return }
        switch repeatMode {
        case .one:
            player?.currentTime = 0
            start()
        case .all, .off:
            if index + 1 < queue.count {
                self.index = index + 1
                load(autoplay: true)
            } else if repeatMode == .all {
                self.index = 0
                load(autoplay: true)
            } else {
                // End of queue: rewind and stop.
                isPlaying = false
                stopTimer()
                player?.currentTime = 0
                currentTime = 0
                updateNowPlaying()
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finished = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == finished else { return }
            self.trackFinished()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let failed = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == failed else { return }
            self.trackFinished()
        }
    }

    // MARK: - Progress timer

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.syncTime()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func syncTime() {
        if let player { currentTime = player.currentTime }
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
    }

    private func observeSessionNotifications() {
        let center = NotificationCenter.default

        _ = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleInterruption(type: type, options: options)
            }
        }

        _ = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated {
                // Headphones unplugged / Bluetooth disconnected → pause like Apple Music does.
                if let reason, AVAudioSession.RouteChangeReason(rawValue: reason) == .oldDeviceUnavailable {
                    self?.pause()
                }
            }
        }
    }

    private func handleInterruption(type rawType: UInt?, options rawOptions: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
            if isPlaying {
                isPlaying = false
                stopTimer()
                updateNowPlaying()
            }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions ?? 0)
            if resumeAfterInterruption, options.contains(.shouldResume) {
                start()
            }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    // MARK: - Lock screen / Control Center

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            MainActor.assumeIsolated { self.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            MainActor.assumeIsolated { self.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            MainActor.assumeIsolated { self.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            MainActor.assumeIsolated { self.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            MainActor.assumeIsolated { self.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            MainActor.assumeIsolated { self.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlaying() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let track = current else {
            infoCenter.nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        if let image = ArtworkCache.image(for: track) {
            info[MPMediaItemPropertyArtwork] = Self.makeArtwork(image)
        }
        infoCenter.nowPlayingInfo = info
    }

    /// Built outside the main actor: iOS calls the artwork handler on a background queue.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
