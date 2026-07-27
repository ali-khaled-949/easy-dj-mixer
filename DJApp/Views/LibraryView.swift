import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    /// Which deck the browser was opened for; the primary load button targets it.
    let targetDeck: DeckID
    var onLoad: (Track, DeckID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var search = ""

    private var filtered: [Track] {
        guard !search.isEmpty else { return library.tracks }
        return library.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.artist.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if library.tracks.isEmpty {
                    ContentUnavailableView("No tracks yet",
                                           systemImage: "music.note",
                                           description: Text("Import audio files from Files, iCloud Drive or anywhere else on your device."))
                }

                ForEach(filtered) { track in
                    row(track)
                }
                .onDelete { offsets in
                    offsets.map { filtered[$0] }.forEach(library.remove)
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Search library")
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    library.importFiles(urls)
                case .failure(let error):
                    library.importError = error.localizedDescription
                }
            }
            .alert("Import failed",
                   isPresented: Binding(get: { library.importError != nil },
                                        set: { if !$0 { library.importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.importError ?? "")
            }
        }
    }

    private func row(_ track: Track) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.panelHigh)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "waveform").foregroundStyle(Theme.dim))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(track.artist)
                    Text("·")
                    Text(formatTime(track.duration))
                    if track.bpm != nil {
                        Text("·")
                        Text("\(track.displayBPM) BPM")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            ForEach(DeckID.allCases) { deck in
                Button {
                    onLoad(track, deck)
                    if deck == targetDeck { dismiss() }
                } label: {
                    Text(deck.label)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.color(for: deck))
                        .frame(width: 34, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.color(for: deck).opacity(deck == targetDeck ? 0.9 : 0.4),
                                        lineWidth: deck == targetDeck ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}
