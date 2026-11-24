import SwiftUI

/// Artist page modelled on the right-hand screen of the reference: huge name,
/// "POPULAR" list in red, and a record bleeding off the bottom edge.
struct ArtistView: View {
    let artist: String

    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let tracks = library.tracks(by: artist)
        let albumCount = Set(tracks.map(\.album).filter { !$0.isEmpty }).count
        let isThisArtistPlaying = player.isPlaying && player.current?.artist == artist
        let summary = summaryText(songs: tracks.count, albums: albumCount)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    Spacer()
                    Text("S/A").font(.mono(13, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)

                Text(artist.uppercased())
                    .font(.display(96))
                    .tracking(-3)
                    .lineLimit(3)
                    .minimumScaleFactor(0.35)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                MonoLabel(summary, size: 10, weight: .semibold)
                .padding(.horizontal, 20)
                .padding(.top, 6)

                HStack(spacing: 10) {
                    Text("POPULAR")
                        .font(.mono(12, weight: .semibold))
                        .foregroundStyle(Theme.red)
                    Spacer()
                    Button {
                        player.playShuffled(tracks)
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 1))
                    }
                    .accessibilityLabel("Shuffle artist")
                    PlayButton(isPlaying: isThisArtistPlaying, size: 36) {
                        if player.current?.artist == artist {
                            player.togglePlayPause()
                        } else {
                            player.play(tracks, startAt: 0)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 6)

                LazyVStack(spacing: 0) {
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
                    }
                }

                // Record bleeding off the bottom-left, with a red arc like the reference.
                ZStack {
                    Circle()
                        .trim(from: 0.55, to: 0.95)
                        .stroke(Theme.red, lineWidth: 1.5)
                        .frame(width: 400, height: 400)
                    VinylView(track: tracks.first, isSpinning: isThisArtistPlaying)
                        .frame(width: 360, height: 360)
                }
                .offset(x: -70)
                .padding(.top, 48)
                .padding(.bottom, -140)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: tracks.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    private func summaryText(songs: Int, albums: Int) -> String {
        var text = "\(songs) " + (songs == 1 ? "song" : "songs")
        if albums > 0 {
            text += " · \(albums) " + (albums == 1 ? "album" : "albums")
        }
        return text
    }
}
