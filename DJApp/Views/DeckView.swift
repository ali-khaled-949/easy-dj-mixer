import SwiftUI

struct DeckView: View {
    @ObservedObject var deck: Deck
    var onBrowse: () -> Void

    private var tint: Color { Theme.color(for: deck.id) }

    var body: some View {
        VStack(spacing: 8) {
            header

            JogWheelView(deck: deck, tint: tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            transport
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBrowse) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.panelHigh)
                    .overlay(
                        Image(systemName: deck.track == nil ? "plus" : "music.note.list")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    )
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(deck.track?.title ?? "No track loaded")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(deck.track == nil ? Theme.dim : Theme.text)
                    .lineLimit(1)
                Text(deck.track?.artist ?? "Tap to browse")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 1) {
                ReadoutText(value: formatTime(deck.remaining, negative: deck.duration > 0),
                            size: 13, color: tint)
                ReadoutText(value: tempoLabel, size: 9, color: Theme.dim)
            }
        }
        .padding(6)
        .panelBackground()
        .overlay(alignment: .topTrailing) {
            if deck.isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .padding(6)
            }
        }
    }

    private var tempoLabel: String {
        guard let tempo = deck.tempo else { return "--.- BPM" }
        return String(format: "%.1f BPM", tempo)
    }

    private var transport: some View {
        HStack(spacing: 8) {
            HoldButton {
                deck.cuePressed()
            } onRelease: {
                deck.cueReleased()
            } label: {
                transportLabel("CUE", color: Theme.accent, filled: false)
            }

            Button {
                deck.togglePlay()
            } label: {
                transportLabel(deck.isPlaying ? "pause.fill" : "play.fill",
                               color: Theme.play,
                               filled: deck.isPlaying,
                               isSymbol: true)
            }
            .buttonStyle(.plain)
        }
        .disabled(deck.track == nil)
        .opacity(deck.track == nil ? 0.4 : 1)
    }

    private func transportLabel(_ text: String, color: Color, filled: Bool, isSymbol: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(filled ? color.opacity(0.22) : Theme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(filled ? 0.9 : 0.5), lineWidth: 1.5)
            )
            .overlay(
                Group {
                    if isSymbol {
                        Image(systemName: text).font(.system(size: 17, weight: .bold))
                    } else {
                        Text(text).font(.system(size: 12, weight: .heavy)).tracking(1)
                    }
                }
                .foregroundStyle(color)
            )
            .frame(height: 38)
    }
}

/// Pitch fader plus its readout, mounted on the outer edge of each deck.
struct PitchColumn: View {
    @ObservedObject var deck: Deck
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("PITCH")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)

            VerticalFader(value: $deck.pitch, range: -1...1, tint: tint, bipolar: true)
                .frame(width: 40)

            ReadoutText(value: String(format: "%+.1f%%", deck.pitch * deck.pitchRange * 100),
                        size: 10, color: tint)

            Button {
                let ranges: [Double] = [0.08, 0.16, 0.5]
                let next = (ranges.firstIndex(of: deck.pitchRange).map { $0 + 1 } ?? 0) % ranges.count
                deck.pitchRange = ranges[next]
            } label: {
                Text("±\(Int(deck.pitchRange * 100))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 38, height: 20)
                    .panelBackground(cornerRadius: 5)
            }
            .buttonStyle(.plain)
        }
    }
}
