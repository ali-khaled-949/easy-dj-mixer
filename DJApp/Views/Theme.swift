import SwiftUI

enum Theme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let panel = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let panelHigh = Color(red: 0.16, green: 0.16, blue: 0.19)
    static let stroke = Color.white.opacity(0.08)
    static let text = Color.white
    static let dim = Color.white.opacity(0.45)

    static let accent = Color(red: 1.0, green: 0.66, blue: 0.11)
    static let deckA = Color(red: 0.15, green: 0.78, blue: 0.98)
    static let deckB = Color(red: 1.0, green: 0.42, blue: 0.36)
    static let play = Color(red: 0.24, green: 0.86, blue: 0.42)

    static func color(for deck: DeckID) -> Color {
        deck == .a ? deckA : deckB
    }
}

extension View {
    func panelBackground(cornerRadius: CGFloat = 10) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

/// Monospaced digits keep readouts from jittering as they count.
struct ReadoutText: View {
    let value: String
    var size: CGFloat = 12
    var color: Color = Theme.text

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}
