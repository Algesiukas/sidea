import SwiftUI

/// Editorial / Swiss-poster palette: warm paper, black ink, one red accent.
enum Theme {
    static let paper = Color(red: 0.957, green: 0.949, blue: 0.933)
    static let ink = Color(red: 0.055, green: 0.055, blue: 0.055)
    static let red = Color(red: 0.898, green: 0.196, blue: 0.176)
    static let muted = Color(red: 0.54, green: 0.54, blue: 0.52)
    static let hairline = Color.black.opacity(0.12)
}

extension Font {
    /// Huge condensed grotesque used for titles ("SIDE A", artist names, track titles).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular).width(.condensed)
    }

    /// Small monospaced labels ("MUSIC PLAYER", track rows, times).
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct MonoLabel: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = Theme.ink
    var weight: Font.Weight = .medium

    init(_ text: String, size: CGFloat = 10, color: Color = Theme.ink, weight: Font.Weight = .medium) {
        self.text = text
        self.size = size
        self.color = color
        self.weight = weight
    }

    var body: some View {
        Text(text.uppercased())
            .font(.mono(size, weight: weight))
            .tracking(0.5)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Removes default List chrome so rows sit flush on the paper background.
struct PlainRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.paper)
    }
}

extension View {
    func plainRow() -> some View { modifier(PlainRow()) }
}

/// Liquid Glass on iOS 26, frosted material on older systems.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .clipShape(shape)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        }
    }
}

func formatTime(_ time: TimeInterval) -> String {
    guard time.isFinite, time >= 0 else { return "0:00" }
    let seconds = Int(time.rounded(.down))
    if seconds >= 3600 {
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

func twoDigits(_ n: Int) -> String { String(format: "%02d", n) }
