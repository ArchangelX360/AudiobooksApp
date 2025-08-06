import Foundation
import Combine
import Observation
import MediaPlayer
import AVFoundation

struct Audiobook: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var author: String
    var duration: TimeInterval
    var size : Int?
    var artwork: MPMediaItemArtwork?
    var lastPlayedDate: Date?
    var url: URL
    
    init( // only use in Preview mocks
        title: String,
        author: String,
        url: URL
    ) {
        self.title = title
        self.author = author
        self.duration = TimeInterval()
        self.size = 1234
        self.artwork = Optional.none
        self.lastPlayedDate = Date()
        self.url = url
    }
    
    init(mediaItem: MPMediaItem) {
        title = mediaItem.title ?? "no title"
        author = mediaItem.artist ?? mediaItem.albumArtist ?? "Unknown Author"
        duration = mediaItem.playbackDuration
        url = mediaItem.assetURL!
        artwork = mediaItem.artwork
        lastPlayedDate = mediaItem.lastPlayedDate
        do {
            size = try mediaItem.assetURL?.resourceValues(forKeys: [.fileSizeKey]).fileSize
        } catch {
            size = Optional.none
        }
    }
    
    var sizeString: String? {
        if let s = size {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(s))
        } else {
            return Optional.none
        }
    }
}

@MainActor @Observable
class AudiobooksManager {
    var audiobooks: [Audiobook] = []
    var isLoading: Bool = true
    var errorMessage: String?

    func loadBookFiles() {
        isLoading = true
        errorMessage = nil 
        
        Task {
            do {
                let files = try await getAudiobooksFromMusicLibrary()
                await MainActor.run {
                    self.audiobooks = files
                    self.errorMessage = nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.audiobooks = []
                    self.errorMessage = "Failed to load books: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getAudiobooksFromMusicLibrary() async throws -> [Audiobook] {
        var bookFiles: [Audiobook] = []
        
        print("🎵 Querying audiobooks from the Music Library...")
        // Check if media library access is authorized
        guard MPMediaLibrary.authorizationStatus() == .authorized else {
            print("🎵 Music library access not authorized")
            // Request authorization for future use
            MPMediaLibrary.requestAuthorization { status in
                print("🎵 Music library authorization status: \(status.rawValue)")
            }
            return []
        }
                    
        // Query for audiobooks specifically
        let audiobookQuery = MPMediaQuery.audiobooks()
        if let audiobookItems = audiobookQuery.items {
            print("🎵 Found \(audiobookItems.count) audiobooks in Music Library")
            
            for item in audiobookItems {
                let bookFile = Audiobook(mediaItem: item)
                bookFiles.append(bookFile)
                // print("🎵 Added audiobook from Music Library: \(bookFile.displayName)")
            }
        }
        
        // Sort alphabetically for consistent ordering
        return bookFiles.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
