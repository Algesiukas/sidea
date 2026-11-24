import SwiftUI

/// Bottom bar shown on every screen while something is loaded. Tap to open the full player.
struct MiniPlayer: View {
    @Environment(PlayerEngine.self) private var player
    let onOpen: () -> Void

    var body: some View {
        if let track = player.current {
            VStack(spacing: 0) {
                MiniProgressLine()

                HStack(spacing: 12) {
                    ArtworkView(track: track, cornerRadius: 4)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        MonoLabel(track.title, size: 11, weight: .semibold)
                        MonoLabel(track.artist, size: 10, color: Theme.muted)
                    }

                    Spacer(minLength: 8)

                    Button { player.previous() } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 15))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous")

                    PlayButton(isPlaying: player.isPlaying, size: 40) { player.togglePlayPause() }

                    Button { player.next() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 15))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next")
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .modifier(GlassCard())
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Separate view so only this line redraws on each time tick.
private struct MiniProgressLine: View {
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Theme.red)
                .frame(width: geo.size.width * player.progress, height: 2)
        }
        .frame(height: 2)
    }
}
