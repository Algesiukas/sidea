import AVKit
import SwiftUI

struct TrackRow: View {
    let number: Int
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(twoDigits(number))
                .font(.mono(11))
                .foregroundStyle(isCurrent ? Theme.red : Theme.muted)
                .frame(width: 22, alignment: .leading)

            ArtworkView(track: track)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title.uppercased())
                    .font(.mono(12, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.red : Theme.ink)
                    .lineLimit(1)
                Text(track.subtitle.uppercased())
                    .font(.mono(10))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }

            Text(formatTime(track.duration))
                .font(.mono(11))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct AlbumCard: View {
    let number: Int
    let album: AlbumGroup
    let isSpinning: Bool

    private let side: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(twoDigits(number))

            ZStack(alignment: .leading) {
                VinylView(track: album.tracks.first, isSpinning: isSpinning)
                    .frame(width: side * 0.94, height: side * 0.94)
                    .offset(x: isSpinning ? side * 0.30 : side * 0.20)
                ArtworkView(track: album.tracks.first)
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
            }
            .frame(width: side * 1.28, alignment: .leading)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isSpinning)

            VStack(alignment: .leading, spacing: 2) {
                MonoLabel(album.title, size: 11, weight: .semibold)
                MonoLabel(album.artist, size: 10, color: Theme.muted)
            }
            .frame(width: side, alignment: .leading)
        }
    }
}

/// Thin line scrubber with a red knob that grows while dragging.
struct ScrubBar: View {
    @Environment(PlayerEngine.self) private var player
    @State private var dragValue: TimeInterval?

    var body: some View {
        let duration = max(player.duration, 0.01)
        let value = dragValue ?? player.currentTime
        let fraction = CGFloat(min(max(value / duration, 0), 1))
        let knob: CGFloat = dragValue == nil ? 10 : 18

        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.hairline).frame(height: 2)
                    Rectangle().fill(Theme.red).frame(width: width * fraction, height: 2)
                    Circle()
                        .fill(Theme.red)
                        .frame(width: knob, height: knob)
                        .offset(x: width * fraction - knob / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let x = min(max(gesture.location.x / max(width, 1), 0), 1)
                            dragValue = Double(x) * duration
                        }
                        .onEnded { _ in
                            if let dragValue { player.seek(to: dragValue) }
                            dragValue = nil
                        }
                )
            }
            .frame(height: 24)

            HStack {
                MonoLabel(formatTime(value), size: 10)
                Spacer()
                MonoLabel("-" + formatTime(max(player.duration - value, 0)), size: 10, color: Theme.muted)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dragValue == nil)
    }
}

/// System AirPlay / Bluetooth output picker.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor(Theme.ink)
        view.activeTintColor = UIColor(Theme.red)
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Hamburger icon from the reference design.
struct MenuGlyph: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Rectangle().frame(width: 22, height: 2)
            Rectangle().frame(width: 22, height: 2)
            Rectangle().frame(width: 14, height: 2)
        }
        .foregroundStyle(Theme.ink)
        .frame(width: 44, height: 44, alignment: .trailing)
        .contentShape(Rectangle())
    }
}

struct PlayButton: View {
    let isPlaying: Bool
    var size: CGFloat = 76
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.red)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: isPlaying ? 0 : size * 0.03)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}
