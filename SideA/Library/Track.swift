import Foundation

struct Track: Identifiable, Hashable {
    /// File name inside the app's Documents folder (unique there).
    let id: String
    let url: URL
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artworkData: Data?
    var addedAt: Date

    var subtitle: String { album.isEmpty ? artist : album }
}

struct AlbumGroup: Identifiable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]
}

struct ArtistSummary: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case title, artist, recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .recent: "Recently added"
        }
    }
}
