import SwiftUI

struct AudiobooksView: View {
    @State var manager: AudiobooksManager = AudiobooksManager()
    @State var player: AudiobookPlayer = AudiobookPlayer()
    @State private var showingBookDetail = false

    var body: some View {
        NavigationStack {
            List {
                if manager.isLoading {
                    loadingAudiobooks
                } else if let error = manager.errorMessage {
                    loadingError(error, manager.loadBookFiles)
                } else if manager.audiobooks.isEmpty {
                    noAudioBooks(manager.loadBookFiles)
                } else {
                    ForEach(manager.audiobooks) { bookFile in
                        BookFileRow(bookFile: bookFile) {
                            player.loadAudiobook(from: bookFile)
                        }
                    }
                }
            }
            .task {
                manager.loadBookFiles()
            }
            .refreshable {
                manager.loadBookFiles()
            }
            .navigationTitle("Audiobooks")
            .safeAreaInset(edge: .bottom) {
                if (player.isLoading || player.isPlaying || player.book != nil) {
                    MiniPlayerView(player: player) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingBookDetail = true
                        }
                    }
                }
            }.sheet(isPresented: $showingBookDetail) {
                BookDetailView(player: player, onClose: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingBookDetail = false
                    }
                })
            }
        }
    }

    private func findCurrentlyPlayingBook() -> Audiobook? {
        if let currentBookURL = player.book?.url {
            return manager.audiobooks.first { book in
                book.url == currentBookURL
            }
        } else {
            return nil
        }
    }
    
    private var loadingAudiobooks : some View {
        HStack() {
            ProgressView()
            Text("Loading audiobooks...")
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func loadingError(_ error: String , _ reload: @MainActor @escaping () -> ()) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Failed to load audiobooks")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Drag or click to retry") {
                reload()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
    

    @ViewBuilder
    private func noAudioBooks(_ reload: @MainActor @escaping () -> ()) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No audiobook found")
                .font(.headline)
            Text("Add audiobook files to your iPhone and refresh")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Drag or click to refresh") {
                reload()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
}

struct BookFileRow: View {
    let bookFile: Audiobook
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            bookArtwork
            VStack(alignment: .leading, spacing: 4) {
                Text(bookFile.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(bookFile.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(formatDuration(bookFile.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let size = bookFile.sizeString {
                        Text(size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let lastPlayed = bookFile.lastPlayedDate {
                        Text(lastPlayed, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            onTap()
        }
    }
    
    private var bookArtwork: some View {
        Group {
            if let artwork = bookFile.artwork,
               let artworkImage = artwork.image(at: CGSize(width: 200, height: 200)) {
                Image(uiImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .background(Color.secondary.opacity(0.1))
        .overlay {
            Rectangle().stroke(Color.secondary.opacity(0.1), lineWidth: 2)
        }
        .cornerRadius(8)
        .clipped()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%dh %02dmin", hours, minutes)
        } else {
            return String(format: "%dmin", minutes)
        }
    }
    
}

struct MiniPlayerView: View {
    var player: AudiobookPlayer
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if player.isLoading {
                loadingAudiobook
            } else {
                bookArtwork
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.duration > 0 ? "\(player.book!.title) - \(player.book!.author)" : player.book!.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Text(player.duration > 0 ? formatTimeLeft(player.duration - player.currentTime, true) : player.book!.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { player.skipBackward(seconds: 30) }) {
                        Image(systemName: "gobackward.30")
                            .font(.title3)
                    }
                    .disabled(!player.isPlaying && player.duration == 0)

                    Button(action: player.togglePlayback) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)

                    }
                    .disabled(player.isLoading)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(width: 350, height: 70)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 45))
        .onTapGesture {
            onTap()
        }
    }

    private var loadingAudiobook: some View {
        HStack() {
            ProgressView()
            Text("Loading audiobook...")
        }
        .foregroundColor(.secondary)
    }

    private var bookArtwork: some View {
        Group {
            if let artwork = player.book?.artwork,
               let artworkImage = artwork.image(at: CGSize(width: 200, height: 200)) {
                Image(uiImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 50, height: 50)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .clipped()
    }
}

struct BookDetailView: View {
    var player: AudiobookPlayer
    let onClose: (() -> Void)
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader {
                let size = $0.size
                let spacing = size.height * 0.05
                VStack(spacing: spacing) {
                    Capsule()
                        .fill(.gray)
                        .frame(width: 40, height: 5)
                    if player.isLoading {
                        loadingAudiobook
                    } else if let errorMessage = player.errorMessage {
                        loadingError(errorMessage)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            bookArtwork
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.book!.title)
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                Text(player.book!.author)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(spacing: spacing) {
                            if player.duration > 0 {
                                VStack(spacing: 8) {
                                    ProgressView(value: player.currentTime, total: player.duration)
                                        .progressViewStyle(LinearProgressViewStyle())

                                    HStack {
                                        Text(formatTime(player.currentTime))
                                        Spacer()
                                        Text(formatTimeLeft(player.duration - player.currentTime))
                                        Spacer()
                                        Text(formatTime(player.duration))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }

                            // Playback Controls
                            HStack(spacing: size.width * 0.15) {
                                Button(action: { player.skipBackward(seconds: 30) }) {
                                    Image(systemName: "gobackward.30")
                                        .font(size.height < 300 ? .title3 : .title)
                                }
                                .disabled(!player.isPlaying && player.duration == 0)

                                Button(action: player.togglePlayback) {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(size.height < 300 ? .largeTitle : .system(size: 50))

                                }
                                .disabled(player.isLoading)

                                Button(action: { player.skipForward(seconds: 30) }) {
                                    Image(systemName: "goforward.30")
                                        .font(size.height < 300 ? .title3 : .title)
                                }
                                .disabled(!player.isPlaying && player.duration == 0)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var bookArtwork: some View {
        GeometryReader {
            let size = $0.size
            if let artwork = player.book!.artwork,
               let artworkImage = artwork.image(at: CGSize(width: 200, height: 200)) {
                Image(uiImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 200))
                    .foregroundColor(.secondary)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(8)
                    .clipped()
            }
        }
    }
    
    
    private var loadingAudiobook : some View {
        HStack() {
            ProgressView()
            Text("Loading audiobook...")
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func loadingError(_ error: String ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Failed to load audiobook")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func formatTime(_ time: TimeInterval) -> String {
    let hours = Int(time) / 3600
    let minutes = Int(time) % 3600 / 60
    let seconds = Int(time) % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private func formatTimeLeft(_ time: TimeInterval, _ short: Bool = false) -> String {
    let hours = Int(time) / 3600
    let minutes = Int(time) % 3600 / 60

    if hours > 0 {
        if short {
            return String(format: "%dh%dmin left", hours, minutes)
        } else {
            return String(format: "%d hours, %d minutes left", hours, minutes)
        }
    } else {
        if short {
            return String(format: "%dmin left", minutes)
        } else {
            return String(format: "%d minutes left", minutes)
        }
    }
}


#Preview {
    let view = AudiobooksView()
    // Set up mock data
    view.manager.audiobooks = [
        Audiobook(
            title: "1984",
            author: "Georges Orwell",
            url: URL(fileURLWithPath: "/Users/archangel/Library/Mobile Documents/com~apple~CloudDocs/Books/1984-reencode.m4b")
        ),
        Audiobook(
            title: "1991",
            author: "Franck Thillez",
            url: URL(fileURLWithPath: "/Users/archangel/Library/Mobile Documents/com~apple~CloudDocs/Books/1991-reencode.m4b")
        )
    ]
    view.manager.isLoading = false
    view.manager.errorMessage = nil
    view.player.book = view.manager.audiobooks.first

    return view
}
