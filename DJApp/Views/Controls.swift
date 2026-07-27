import SwiftUI

/// A rotary knob driven by vertical drag — the same gesture every plugin UI uses,
/// because circular dragging on a small touch target is miserable.
struct Knob: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var center: Double? = nil
    var tint: Color = Theme.accent
    var size: CGFloat = 44

    @State private var dragStart: Double?

    private var normalized: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var angle: Angle {
        .degrees(-135 + normalized * 270)
    }

    private var arcStart: Double {
        guard let center else { return 0 }
        return (center - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 3)
                    .padding(2)

                Circle()
                    .trim(from: min(arcStart, normalized) * 0.75 + 0.125,
                          to: max(arcStart, normalized) * 0.75 + 0.125)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .padding(2)

                Circle()
                    .fill(
                        LinearGradient(colors: [Theme.panelHigh, Theme.panel],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                    .padding(7)

                Capsule()
                    .fill(tint)
                    .frame(width: 2.5, height: size * 0.22)
                    .offset(y: -size * 0.19)
                    .rotationEffect(angle)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            // minimumDistance must stay above zero: a zero-distance drag claims the
            // touch on touch-down and the double-tap reset never gets recognised.
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { gesture in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = start }
                        let span = range.upperBound - range.lowerBound
                        let delta = Double(-gesture.translation.height) / 140 * span
                        value = min(range.upperBound, max(range.lowerBound, start + delta))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { value = center ?? (range.lowerBound + range.upperBound) / 2 }
            }

            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Theme.dim)
        }
        .frame(width: size)
    }
}

/// Vertical channel fader.
struct VerticalFader: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var tint: Color = Theme.accent
    /// Draws the scale from the middle out, for pitch faders.
    var bipolar: Bool = false

    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let knobHeight: CGFloat = 26
            let travel = height - knobHeight

            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 5)
                    .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                    .frame(maxWidth: .infinity)

                if bipolar {
                    // Fill spans from the centre detent to the cap.
                    Rectangle()
                        .fill(tint.opacity(0.8))
                        .frame(width: 5, height: abs(normalized - 0.5) * travel)
                        .offset(y: knobHeight / 2 + min(0.5, 1 - normalized) * travel)
                        .frame(maxWidth: .infinity, alignment: .top)
                } else {
                    Capsule()
                        .fill(tint.opacity(0.8))
                        .frame(width: 5, height: normalized * travel)
                        .offset(y: knobHeight / 2 + (1 - normalized) * travel)
                        .frame(maxWidth: .infinity, alignment: .top)
                }

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(white: 0.32), Color(white: 0.14)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(
                        Rectangle().fill(tint).frame(height: 2).padding(.horizontal, 4)
                    )
                    .frame(width: 30, height: knobHeight)
                    .offset(y: (1 - normalized) * travel)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { gesture in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = start }
                        let span = range.upperBound - range.lowerBound
                        let delta = Double(-gesture.translation.height) / max(1, travel) * span
                        value = min(range.upperBound, max(range.lowerBound, start + delta))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) {
                    value = bipolar ? (range.lowerBound + range.upperBound) / 2 : range.upperBound
                }
            }
        }
    }
}

/// Horizontal crossfader.
struct Crossfader: View {
    @Binding var value: Double

    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knobWidth: CGFloat = 34
            let travel = width - knobWidth
            let normalized = (value + 1) / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(height: 6)
                    .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                    .frame(maxHeight: .infinity)

                HStack {
                    Rectangle().fill(Theme.deckA.opacity(0.65)).frame(width: 2, height: 12)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: 2, height: 12)
                    Spacer()
                    Rectangle().fill(Theme.deckB.opacity(0.65)).frame(width: 2, height: 12)
                }

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(white: 0.34), Color(white: 0.15)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(
                        Rectangle().fill(Theme.accent).frame(width: 2).padding(.vertical, 5)
                    )
                    .frame(width: knobWidth, height: 30)
                    .offset(x: normalized * travel)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { gesture in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = start }
                        let delta = Double(gesture.translation.width) / max(1, travel) * 2
                        value = min(1, max(-1, start + delta))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { value = 0 }
            }
        }
    }
}

/// Momentary button that reports press and release separately, for CUE.
struct HoldButton<Label: View>: View {
    var onPress: () -> Void
    var onRelease: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var isPressed = false

    var body: some View {
        label()
            .opacity(isPressed ? 0.65 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPress()
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
    }
}
