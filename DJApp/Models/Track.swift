import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var artist: String
    var url: URL
    var duration: Double
    var bpm: Double?

    init(id: UUID = UUID(), title: String, artist: String, url: URL, duration: Double = 0, bpm: Double? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.url = url
        self.duration = duration
        self.bpm = bpm
    }

    var displayBPM: String {
        guard let bpm else { return "--.-" }
        return String(format: "%.1f", bpm)
    }
}

enum DeckID: String, CaseIterable, Identifiable {
    case a, b
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

func formatTime(_ seconds: Double, negative: Bool = false) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let total = Int(seconds.rounded())
    return String(format: "%@%02d:%02d", negative ? "-" : "", total / 60, total % 60)
}
