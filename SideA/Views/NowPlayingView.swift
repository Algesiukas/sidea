import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            record
                .padding(.top, 12)
            titleBlock
                .padding(.top, 20)
            ScrubBar()
                .padding(.top, 18)
            controls
                .padding(.top, 14)
            footer
                .padding(.top, 22)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background(Theme.paper.ignoresSafeArea())
        .onChange(of: player.current == nil) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")

            Spacer()

            VStack(spacing: 2) {
                MonoLabel("Now playing", size: 10, weight: .semibold)
                if let index = player.index {
                    MonoLabel("\(twoDigits(index + 1)) / \(twoDigits(player.queue.count))", size: 9, color: Theme.muted)
                }
            }

            Spacer()

            AirPlayButton()
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(Theme.ink)
        .padding(.top, 8)
    }

    /// Cover with the record sliding out from behind it (further out while playing).
    private var record: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.78, geo.size.height)
            ZStack(alignment: .leading) {
                VinylView(track: player.current, isSpinning: player.isPlaying)
                    .frame(width: side * 0.95, height: side * 0.95)
                    .offset(x: player.isPlaying ? side * 0.27 : side * 0.12)
                ArtworkView(track: player.current)
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 12)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: player.isPlaying)
        }
        .frame(maxHeight: .infinity)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((player.current?.title ?? "Nothing playing").uppercased())
                .font(.display(54))
                .tracking(-1.5)
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
            HStack(spacing: 10) {
                MonoLabel(player.current?.artist ?? "—", size: 11, weight: .semibold)
                if let album = player.current?.album, !album.isEmpty {
                    MonoLabel(album, size: 11, color: Theme.muted)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: player.current?.id)
    }

    private var controls: some View {
        HStack {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(player.shuffle ? Theme.red : Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(player.shuffle ? "Shuffle on" : "Shuffle off")

            Spacer()

            Button { player.previous() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Previous")

            Spacer()

            PlayButton(isPlaying: player.isPlaying) { player.togglePlayPause() }

            Spacer()

            Button { player.next() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Next")

            Spacer()

            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(player.repeatMode == .off ? Theme.ink : Theme.red)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel("Repeat")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .sensoryFeedback(.selection, trigger: player.current?.id)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            MonoLabel("Up next", size: 10, color: Theme.red, weight: .semibold)
            MonoLabel(player.upNext?.title ?? "End of queue", size: 10, color: Theme.muted)
            Spacer()
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}
