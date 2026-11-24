import SwiftUI

/// A black record with grooves and the cover art as its centre label. Spins while playing
/// and stops exactly where it is when paused.
struct VinylView: View {
    var track: Track?
    var isSpinning: Bool

    @State private var baseAngle: Double = 0
    @State private var spinStart: Date?

    /// Degrees per second (~33 rpm would be 200; slower looks calmer on screen).
    private let speed: Double = 72

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: nil, paused: !isSpinning)) { context in
                disc.rotationEffect(.degrees(angle(at: context.date)))
            }
            // Light reflection stays fixed while the disc turns underneath it.
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.clear, .white.opacity(0.10), .clear, .clear, .white.opacity(0.07), .clear],
                        center: .center
                    )
                )
                .allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: isSpinning, initial: true) { _, spinning in
            if spinning {
                spinStart = Date()
            } else {
                if let spinStart { baseAngle += Date().timeIntervalSince(spinStart) * speed }
                spinStart = nil
            }
        }
    }

    private func angle(at date: Date) -> Double {
        let running = spinStart.map { date.timeIntervalSince($0) } ?? 0
        return (baseAngle + running * speed).truncatingRemainder(dividingBy: 360)
    }

    private var disc: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Color(white: 0.06))
                ForEach(0..<16, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(i % 4 == 0 ? 0.08 : 0.035), lineWidth: 0.8)
                        .padding(d * (0.03 + CGFloat(i) * 0.019))
                }
                ArtworkView(track: track)
                    .frame(width: d * 0.36, height: d * 0.36)
                    .clipShape(Circle())
                Circle()
                    .fill(Theme.paper)
                    .frame(width: d * 0.03, height: d * 0.03)
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
