import AVFoundation
import Foundation
import Observation

/// Owns the music files. Songs live in the app's Documents folder, which is also
/// visible in the Files app (On My iPhone › Side A), so files can be added from either side.
@MainActor
@Observable
final class LibraryStore {
    private(set) var tracks: [Track] = []
    private(set) var isLoading = false
    private(set) var isImporting = false
    private(set) var lastError: String?

    let musicDirectory: URL

    nonisolated static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "aifc", "caf", "flac", "mp4", "m4b"
    ]

    init() {
        musicDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        Task { await reload() }
    }

    // MARK: - Derived collections

    func sorted(by sort: LibrarySort) -> [Track] {
        switch sort {
        case .title:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return tracks.sorted {
                let a = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                if a != .orderedSame { return a == .orderedAscending }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .recent:
            return tracks.sorted { $0.addedAt > $1.addedAt }
        }
    }

    var albums: [AlbumGroup] {
        var order: [String] = []
        var groups: [String: [Track]] = [:]
        for track in tracks.sorted(by: { $0.addedAt > $1.addedAt }) {
            let key = track.album.isEmpty ? "artist:\(track.artist)" : "album:\(track.album)|\(track.artist)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(track)
        }
        return order.compactMap { key in
            guard let list = groups[key], let first = list.first else { return nil }
            return AlbumGroup(
                id: key,
                title: first.album.isEmpty ? first.artist : first.album,
                artist: first.artist,
                tracks: list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )
        }
    }

    var artists: [ArtistSummary] {
        let counts = Dictionary(grouping: tracks, by: \.artist).mapValues(\.count)
        return counts
            .map { ArtistSummary(name: $0.key, count: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func tracks(by artist: String) -> [Track] {
        tracks
            .filter { $0.artist == artist }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Loading

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let files = Self.audioFiles(in: musicDirectory)
        let existing = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var result: [Track] = []
        result.reserveCapacity(files.count)
        for file in files {
            if let known = existing[file.url.lastPathComponent], known.addedAt == file.added {
                result.append(known)
            } else {
                result.append(await Self.makeTrack(url: file.url, addedAt: file.added))
            }
        }
        tracks = result
    }

    nonisolated private static func audioFiles(in directory: URL) -> [(url: URL, added: Date)] {
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { url in
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile != false else { return nil }
            return (url: url, added: values?.creationDate ?? .distantPast)
        }
    }

    /// Reads title / artist / album / artwork tags from the file.
    nonisolated private static func makeTrack(url: URL, addedAt: Date) async -> Track {
        let asset = AVURLAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = ""
        var artwork: Data?
        var duration: TimeInterval = 0

        if let time = try? await asset.load(.duration), time.seconds.isFinite {
            duration = time.seconds
        }

        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { title = value }
                case .commonKeyArtist:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { artist = value }
                case .commonKeyAlbumName:
                    if let value = try? await item.load(.stringValue), !value.isEmpty { album = value }
                case .commonKeyArtwork:
                    if artwork == nil, let value = try? await item.load(.dataValue) { artwork = value }
                default:
                    break
                }
            }
        }

        return Track(
            id: url.lastPathComponent,
            url: url,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkData: artwork,
            addedAt: addedAt
        )
    }

    // MARK: - Import / delete

    func importFiles(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }
        lastError = nil

        let fm = FileManager.default
        for source in urls {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }

            let destination = uniqueDestination(for: source.lastPathComponent)
            do {
                try fm.copyItem(at: source, to: destination)
            } catch {
                lastError = "Couldn't import \(source.lastPathComponent)"
            }
        }
        await reload()
    }

    func delete(_ track: Track) {
        try? FileManager.default.removeItem(at: track.url)
        tracks.removeAll { $0.id == track.id }
    }

    func clearError() { lastError = nil }

    private func uniqueDestination(for fileName: String) -> URL {
        let fm = FileManager.default
        var candidate = musicDirectory.appendingPathComponent(fileName)
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = musicDirectory.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}
