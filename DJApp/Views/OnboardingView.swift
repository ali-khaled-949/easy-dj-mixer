import SwiftUI

/// First-launch guide. Shown once, skippable, and reachable again from the "?" button
/// in the mixer — several of the gestures here (scratching, tap-to-reset) are not
/// discoverable on their own.
struct OnboardingView: View {

    var onDismiss: () -> Void

    private struct Tip: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
        let tint: Color
    }

    private let tips: [Tip] = [
        Tip(symbol: "plus.circle.fill", title: "Load a track",
            detail: "Tap + on a deck, then A or B next to a song.",
            tint: Theme.deckA),
        Tip(symbol: "play.fill", title: "Play and cue",
            detail: "CUE sets your start point. Hold it to preview, let go to snap back.",
            tint: Theme.play),
        Tip(symbol: "hand.point.up.left.fill", title: "Scratch the platter",
            detail: "Spin it with your finger. Pull backwards to play in reverse.",
            tint: Theme.deckB),
        Tip(symbol: "dial.medium.fill", title: "EQ and filter",
            detail: "Drag a knob up or down. Tap ↺ beside A or B to flatten it again.",
            tint: Theme.accent),
        Tip(symbol: "arrow.left.and.right", title: "Crossfade",
            detail: "Slide the centre fader to blend from deck A into deck B.",
            tint: Theme.deckA),
        Tip(symbol: "arrow.up.and.down", title: "Match the tempo",
            detail: "Move PITCH until both BPM readouts agree. Tap ±8 to widen it.",
            tint: Theme.deckB)
    ]

    var body: some View {
        ZStack {
            Theme.background.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text("Welcome to Easy DJ Mixer")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Six things worth knowing before you start")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.dim)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                          spacing: 10) {
                    ForEach(tips) { tip in
                        row(tip)
                    }
                }

                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.dim)
                            .frame(width: 96, height: 38)
                            .panelBackground(cornerRadius: 9)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Start Mixing")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 168, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    private func row(_ tip: Tip) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: tip.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tip.tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(tip.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelBackground(cornerRadius: 9)
    }
}
