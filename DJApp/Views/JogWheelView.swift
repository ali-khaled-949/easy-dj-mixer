import SwiftUI

/// Turntable platter. Dragging round the rim scratches: the angular velocity of the
/// finger becomes the playback rate, so pushing forward speeds up and pulling back
/// plays in reverse, exactly like a record.
struct JogWheelView: View {
    @ObservedObject var deck: Deck
    let tint: Color

    @State private var lastAngle: Double?
    @State private var lastTimestamp: Date?
    @State private var isTouching = false

    /// Visual rotation, advanced from the playhead so the platter tracks the audio.
    private var platterAngle: Angle {
        // 33 1/3 rpm at normal speed, scaled by pitch.
        .degrees(deck.position * 200 * (1 + deck.pitch * deck.pitchRange))
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color(white: 0.20), Color(white: 0.07)],
                                       center: .center, startRadius: side * 0.05, endRadius: side * 0.5)
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))

                // Progress ring around the rim.
                Circle()
                    .trim(from: 0, to: deck.progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)

                // Platter surface with grooves.
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(colors: [Color(white: 0.14), Color(white: 0.22),
                                                     Color(white: 0.14), Color(white: 0.22),
                                                     Color(white: 0.14)],
                                            center: .center)
                        )
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .padding(CGFloat(ring + 1) * side * 0.09)
                    }

                    // Marker stripe — the visual reference for the platter's rotation.
                    Capsule()
                        .fill(tint)
                        .frame(width: 3, height: side * 0.30)
                        .offset(y: -side * 0.19)

                    // Label.
                    Circle()
                        .fill(tint.opacity(0.85))
                        .frame(width: side * 0.24, height: side * 0.24)
                        .overlay(
                            Text(deck.id.label)
                                .font(.system(size: side * 0.11, weight: .black, design: .rounded))
                                .foregroundStyle(.black.opacity(0.75))
                        )
                    Circle()
                        .fill(Color.black)
                        .frame(width: side * 0.035, height: side * 0.035)
                }
                .padding(10)
                .rotationEffect(platterAngle)

                if isTouching {
                    Circle()
                        .stroke(Theme.accent.opacity(0.7), lineWidth: 2)
                        .padding(2)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        handleDrag(location: gesture.location, center: center)
                    }
                    .onEnded { _ in endDrag() }
            )
        }
    }

    private func handleDrag(location: CGPoint, center: CGPoint) {
        let angle = atan2(Double(location.y - center.y), Double(location.x - center.x))
        let now = Date()

        guard isTouching, let previous = lastAngle, let previousTime = lastTimestamp else {
            isTouching = true
            lastAngle = angle
            lastTimestamp = now
            deck.beginScratch()
            return
        }

        var delta = angle - previous
        // Unwrap across the ±π seam.
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        // If touches coalesce during a very fast spin the jump can exceed half a turn,
        // and unwrapping then reports the wrong direction. Drop those samples rather
        // than momentarily throwing the record into reverse.
        guard abs(delta) < .pi * 0.75 else {
            lastAngle = angle
            lastTimestamp = now
            return
        }

        let elapsed = max(1.0 / 240.0, now.timeIntervalSince(previousTime))
        // A full turn of the platter equals one revolution at 33⅓ rpm (1.8 s).
        let revolutionsPerSecond = (delta / (2 * .pi)) / elapsed
        deck.updateScratch(rate: revolutionsPerSecond * 1.8)

        lastAngle = angle
        lastTimestamp = now
    }

    private func endDrag() {
        guard isTouching else { return }
        isTouching = false
        lastAngle = nil
        lastTimestamp = nil
        deck.endScratch()
    }
}
