import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var player

    @State private var path: [String] = []
    @State private var showImporter = false
    @State private var showNowPlaying = false
    @AppStorage("librarySort") private var sort: LibrarySort = .title

    var body: some View {
        NavigationStack(path: $path) {
            List {
                header.plainRow()

                if library.tracks.isEmpty {
                    emptyState.plainRow()
                } else {
                    albumsCarousel.plainRow()
                    songsSection
                    artistsSection
                }

                Color.clear.frame(height: 24).plainRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .refreshable { await library.reload() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { artist in
                ArtistView(artist: artist)
            }
        }
        .safeAreaInset(edge: .bottom) {
            MiniPlayer { showNowPlaying = true }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: player.current == nil)
        .overlay {
            if library.isImporting {
                ProgressView("Importing…")
                    .font(.mono(11))
                    .padding(20)
                    .modifier(GlassCard(cornerRadius: 16))
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await library.importFiles(urls) }
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(player)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.paper)
        }
        .alert(
            "Import problem",
            isPresented: Binding(
                get: { library.lastError != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { library.clearError() }
        } message: {
            Text(library.lastError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("S/A")
                    .font(.mono(13, weight: .semibold))
                Spacer()
                Menu {
                    Button("Import songs", systemImage: "plus") { showImporter = true }
                    Picker(selection: $sort) {
                        ForEach(LibrarySort.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Label("Sort by", systemImage: "arrow.up.arrow.down")
                    }
                    if !library.tracks.isEmpty {
                        Button("Shuffle all", systemImage: "shuffle") {
                            player.playShuffled(library.tracks)
                        }
                    }
                    Button("Refresh library", systemImage: "arrow.clockwise") {
                        Task { await library.reload() }
                    }
                } label: {
                    MenuGlyph()
                }
                .accessibilityLabel("Menu")
            }

            Text("SIDE A")
                .font(.display(170))
                .tracking(-6)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            HStack {
                MonoLabel("Music player", weight: .semibold)
                Spacer()
                MonoLabel(String(Calendar.current.component(.year, from: .now)), weight: .semibold)
            }
            .padding(.bottom, 24)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 20)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NO RECORDS\nYET.")
                .font(.display(72))
                .tracking(-2)
                .foregroundStyle(Theme.ink)
            Text("Import MP3, M4A, WAV, AIFF or FLAC files from the Files app — or drop them into Files › On My iPhone › Side A, then pull down to refresh.")
                .font(.mono(11))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button { showImporter = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("IMPORT SONGS")
                }
                .font(.mono(13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Theme.red, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Albums

    private var albumsCarousel: some View {
        let albums = library.albums
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 8) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { offset, album in
                    Button {
                        player.play(album.tracks, startAt: 0)
                    } label: {
                        AlbumCard(
                            number: offset + 1,
                            album: album,
                            isSpinning: player.isPlaying && album.tracks.contains { $0.id == player.current?.id }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.bottom, 28)
    }

    // MARK: - Songs

    @ViewBuilder
    private var songsSection: some View {
        let tracks = library.sorted(by: sort)

        HStack {
            Text(sort == .recent ? "RECENT" : "ALL SONGS")
                .font(.mono(12, weight: .semibold))
                .foregroundStyle(Theme.red)
            Spacer()
            MonoLabel("\(tracks.count) tracks", color: Theme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .plainRow()

        ForEach(Array(tracks.enumerated()), id: \.element.id) { offset, track in
            Button {
                player.play(tracks, startAt: offset)
            } label: {
                TrackRow(
                    number: offset + 1,
                    track: track,
                    isCurrent: player.current?.id == track.id,
                    isPlaying: player.isPlaying
                )
            }
            .buttonStyle(.plain)
            .plainRow()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { delete(track) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button("Play", systemImage: "play.fill") { player.play(tracks, startAt: offset) }
                Button("Go to artist", systemImage: "person") { path.append(track.artist) }
                Divider()
                Button("Delete from library", systemImage: "trash", role: .destructive) { delete(track) }
            }
        }
    }

    // MARK: - Artists

    @ViewBuilder
    private var artistsSection: some View {
        HStack {
            Text("ARTISTS")
                .font(.mono(12, weight: .semibold))
                .foregroundStyle(Theme.red)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 4)
        .plainRow()

        ForEach(library.artists) { artist in
            Button {
                path.append(artist.name)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(artist.name.uppercased())
                        .font(.display(40))
                        .tracking(-1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 12)
                    MonoLabel("\(artist.count)", color: Theme.muted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.horizontal, 20)
                }
            }
            .buttonStyle(.plain)
            .plainRow()
        }
    }

    private func delete(_ track: Track) {
        player.remove(trackID: track.id)
        library.delete(track)
    }
}
