import Foundation
import AVFoundation
import Combine

@MainActor @Observable
class AudiobookPlayer: NSObject {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var isLoading: Bool = false
    var errorMessage: String?
    var book: Audiobook? = nil

    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var timeObserver: Timer?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        print("setting up audio session")
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            try audioSession.setActive(true)
            print("set up audio session")
        } catch {
            print("set up of audio session failed")
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func loadAudiobook(from book: Audiobook) {
        print("loading audiobook \(book.url.absoluteString)")
        isLoading = true
        errorMessage = nil
        stop()
        
        Task {
            do {
                let player = try await Task.detached {
                    print("creating audiobook player")
                    let audioPlayer = try AVAudioPlayer(contentsOf: book.url)
                    print("created audiobook player")
                    print("preparing audiobook \(book.url.absoluteString)")
                    audioPlayer.prepareToPlay()
                    print("prepared audiobook \(book.url.absoluteString)")
                    return audioPlayer
                }.value
                
                // Update UI properties on main thread
                await Task { @MainActor in
                    print("finish loading audiobook \(book.url.absoluteString)")
                    self.book = book
                    self.audioPlayer = player
                    self.audioPlayer?.delegate = self
                    self.duration = player.duration
                    self.isLoading = false
                    play()
                }.value
            } catch {
                await Task { @MainActor in
                    print("finish loading audiobook \(book.url.absoluteString) with error")
                    self.book = nil
                    self.errorMessage = "Failed to load audiobook: \(error.localizedDescription)"
                    self.isLoading = false
                }.value
            }
        }
    }
    
    func togglePlayback() {
        isPlaying ? pause() : play()
    }
    
    /// Start or resume playback
    func play() {
        guard let player = audioPlayer else {
            errorMessage = "No audiobook loaded"
            return
        }
        
        do {
            try audioSession.setActive(true)
            player.play()
            isPlaying = true
            startTimeObserver()
        } catch {
            errorMessage = "Failed to start playback: \(error.localizedDescription)"
        }
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimeObserver()
    }
    
    /// Stop playback and reset to beginning
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimeObserver()
    }
    
    /// Seek to a specific time in seconds
    func seek(to time: TimeInterval) {
        if let player = audioPlayer {
            let clampedTime = max(0, min(time, duration))
            player.currentTime = clampedTime
            currentTime = clampedTime
        }
    }
    
    /// Skip forward by the specified number of seconds
    func skipForward(seconds: TimeInterval = 30) {
        if let player = audioPlayer {
            let newTime = player.currentTime + seconds
            seek(to: newTime)
        }
    }
    
    /// Skip backward by the specified number of seconds
    func skipBackward(seconds: TimeInterval = 30) {
        if let player = audioPlayer {
            let newTime = player.currentTime - seconds
            seek(to: newTime)
        }
    }
    
    /// Set playback rate (0.5x to 2.0x)
    func setPlaybackRate(_ rate: Float) {
        if let player = audioPlayer {
            let clampedRate = max(0.5, min(2.0, rate))
            player.rate = clampedRate
            player.enableRate = true
            playbackRate = clampedRate
        }
    }

    private func startTimeObserver() {
        stopTimeObserver()
        timeObserver = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopTimeObserver() {
        timeObserver?.invalidate()
        timeObserver = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudiobookPlayer: AVAudioPlayerDelegate {
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            stopTimeObserver()
            
            if flag {
                // Playback completed successfully
                currentTime = 0
                player.currentTime = 0
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            isPlaying = false
            stopTimeObserver()
            errorMessage = "Playback error: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}
