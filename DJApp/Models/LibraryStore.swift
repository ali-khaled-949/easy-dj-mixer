import AVFoundation
import Foundation

/// The user's track list. Imported files are copied into Documents so they survive
/// the security-scoped URL going away, and the list is persisted as JSON.
/// Filesystem locations, kept off the main actor so the audio and analysis code can
/// reach them from background work.
enum AppPaths {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var demos: URL { documents.appendingPathComponent("Demos", isDirectory: true) }
    static var imports: URL { documents.appendingPathComponent("Imports", isDirectory: true) }
    static var libraryIndex: URL { documents.appendingPathComponent("library.json") }
}

@MainActor
final class LibraryStore: ObservableObject {

    @Published private(set) var tracks: [Track] = []
    @Published var importError: String?

    private var indexURL: URL { AppPaths.libraryIndex }

    init() {
        load()
    }

    func load() {
        var loaded: [Track] = []
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) {
            // Drop anything the user deleted from Files behind our back.
            loaded = decoded.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        }

        let demos = DemoTrackFactory.makeDemoTracksIfNeeded()
        for demo in demos where !loaded.contains(where: { $0.url.lastPathComponent == demo.url.lastPathComponent }) {
            loaded.append(demo)
        }

        tracks = loaded
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// Copies picked files into the app's Imports folder and adds them to the library.
    func importFiles(_ urls: [URL]) {
        try? FileManager.default.createDirectory(at: AppPaths.imports, withIntermediateDirectories: true)
        var failures: [String] = []

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let destination = uniqueDestination(for: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                failures.append(url.lastPathComponent)
                continue
            }

            let metadata = readMetadata(destination)
            guard metadata.duration > 0 else {
                try? FileManager.default.removeItem(at: destination)
                failures.append(url.lastPathComponent)
                continue
            }

            tracks.append(Track(title: metadata.title,
                                artist: metadata.artist,
                                url: destination,
                                duration: metadata.duration))
        }

        save()
        importError = failures.isEmpty ? nil : "Couldn't import \(failures.joined(separator: ", "))"
    }

    func remove(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        if track.url.path.hasPrefix(AppPaths.imports.path) {
            try? FileManager.default.removeItem(at: track.url)
        }
        save()
    }

    /// Wipes every track and the index. Used by account deletion, which has to remove
    /// the user's data outright rather than just forgetting who they are.
    func deleteAllLocalData() {
        for folder in [AppPaths.imports, AppPaths.demos] {
            try? FileManager.default.removeItem(at: folder)
        }
        try? FileManager.default.removeItem(at: indexURL)
        tracks = []
    }

    /// Called after a deck finishes analysis so a detected BPM sticks around.
    func updateBPM(_ bpm: Double?, for track: Track) {
        guard let bpm, let index = tracks.firstIndex(where: { $0.id == track.id }), tracks[index].bpm == nil else { return }
        tracks[index].bpm = bpm
        save()
    }

    private func uniqueDestination(for filename: String) -> URL {
        var candidate = AppPaths.imports.appendingPathComponent(filename)
        var counter = 1
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = AppPaths.imports.appendingPathComponent("\(name) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

    private func readMetadata(_ url: URL) -> (title: String, artist: String, duration: Double) {
        let fallbackTitle = (url.lastPathComponent as NSString).deletingPathExtension
        var duration: Double = 0
        if let file = try? AVAudioFile(forReading: url) {
            duration = Double(file.length) / file.processingFormat.sampleRate
        }

        var title = fallbackTitle
        var artist = "Unknown Artist"
        let asset = AVURLAsset(url: url)
        for item in asset.commonMetadata {
            switch item.commonKey {
            case .commonKeyTitle:
                if let value = item.stringValue, !value.isEmpty { title = value }
            case .commonKeyArtist:
                if let value = item.stringValue, !value.isEmpty { artist = value }
            default:
                break
            }
        }

        return (title, artist, duration)
    }
}
