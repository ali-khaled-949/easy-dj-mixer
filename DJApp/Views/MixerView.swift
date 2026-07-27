import SwiftUI

/// The centre channel strip: per-deck filter and EQ, channel faders, crossfader.
/// Laid out tightly — an iPhone in landscape only gives us ~400pt of height for
/// the whole console.
struct MixerView: View {
    @ObservedObject var engine: DJEngine
    var onHelp: () -> Void
    var onAccount: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                ChannelStrip(deck: engine.deckA)
                Divider().overlay(Theme.stroke)
                ChannelStrip(deck: engine.deckB)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 2) {
                Crossfader(value: $engine.crossfader)
                    .frame(height: 28)
                HStack {
                    Text("A").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.deckA)
                    Spacer()
                    Text("CROSSFADER")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.dim)

                    Button(action: onHelp) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.dim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("How to use")

                    Button(action: onAccount) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.dim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Account and sign out")

                    Spacer()
                    Text("B").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.deckB)
                }
            }
        }
        .padding(8)
        .panelBackground()
    }
}

private struct ChannelStrip: View {
    @ObservedObject var deck: Deck

    private var tint: Color { Theme.color(for: deck.id) }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Text(deck.id.label)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(tint)

                // Lights up only once something is off-neutral, so it reads as
                // "there is something to undo" rather than as decoration.
                Button {
                    withAnimation(.snappy) { deck.resetTone() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(deck.isToneNeutral ? Theme.dim.opacity(0.5) : Theme.accent)
                        .frame(width: 18, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(deck.isToneNeutral ? Color.clear : Theme.accent.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                .disabled(deck.isToneNeutral)
                .accessibilityLabel("Reset deck \(deck.id.label) EQ and filter")
            }

            HStack(spacing: 3) {
                Knob(title: "HI", value: $deck.high, center: 0.5, tint: tint, size: 29)
                Knob(title: "MID", value: $deck.mid, center: 0.5, tint: tint, size: 29)
                Knob(title: "LOW", value: $deck.low, center: 0.5, tint: tint, size: 29)
            }

            Knob(title: "FILTER", value: $deck.filter, range: -1...1, center: 0, tint: Theme.accent, size: 32)

            VerticalFader(value: $deck.volume, tint: tint)
                .frame(width: 40)
                .frame(maxHeight: .infinity)
                .frame(minHeight: 54)
        }
    }
}
