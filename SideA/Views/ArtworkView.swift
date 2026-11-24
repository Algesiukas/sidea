import SwiftUI
import UIKit

/// Decoded cover images, so lists don't re-decode JPEG data on every redraw.
@MainActor
enum ArtworkCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for track: Track) -> UIImage? {
        guard let data = track.artworkData else { return nil }
        let key = "\(track.id)-\(track.addedAt.timeIntervalSince1970)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Square cover art. Tracks without embedded art get a generated typographic cover.
struct ArtworkView: View {
    let track: Track?
    var cornerRadius: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Theme.ink)
            .overlay {
                if let track, let image = ArtworkCache.image(for: track) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    GeneratedCover(seed: track?.title ?? "", letter: initial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var initial: String {
        guard let first = track?.title.trimmingCharacters(in: .whitespaces).first else { return "A" }
        return String(first).uppercased()
    }
}

private struct GeneratedCover: View {
    let seed: String
    let letter: String

    private static let palettes: [(Color, Color)] = [
        (Theme.red, Theme.ink),
        (Theme.ink, Theme.red),
        (Color(red: 0.86, green: 0.84, blue: 0.80), Theme.ink),
        (Color(red: 0.16, green: 0.20, blue: 0.36), Color(red: 0.95, green: 0.55, blue: 0.40)),
        (Color(red: 0.93, green: 0.60, blue: 0.22), Theme.ink),
        (Color(red: 0.20, green: 0.35, blue: 0.30), Theme.paper)
    ]

    var body: some View {
        let colors = Self.palettes[stableHash % Self.palettes.count]
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                colors.0
                Circle()
                    .fill(colors.1.opacity(0.9))
                    .frame(width: geo.size.width * 0.9)
                    .offset(x: geo.size.width * 0.35, y: -geo.size.height * 0.25)
                Text(letter)
                    .font(.display(geo.size.height * 0.62))
                    .foregroundStyle(colors.0 == Theme.ink ? Theme.paper : Theme.ink)
                    .padding(.leading, geo.size.width * 0.08)
                    .offset(y: geo.size.height * 0.08)
            }
        }
    }

    /// Deterministic across launches (unlike `hashValue`).
    private var stableHash: Int {
        var hash: UInt32 = 5381
        for byte in seed.utf8 { hash = (hash &* 33) &+ UInt32(byte) }
        return Int(hash % 997)
    }
}
