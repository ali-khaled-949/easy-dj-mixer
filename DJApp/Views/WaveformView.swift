import SwiftUI
import UIKit

/// Scrolling waveform with a fixed centre playhead, drawn in Canvas so a few
/// thousand bars stay cheap at 30 fps.
struct WaveformView: View {
    let peaks: [Float]
    let lowEnergy: [Float]
    let progress: Double
    let tint: Color
    let duration: Double
    /// Seconds of audio visible across the full width, so the zoom level stays
    /// constant whether the track is two minutes or ten.
    var secondsVisible: Double = 9
    var onScrub: ((Double) -> Void)?

    @State private var scrubStart: Double?

    /// The visible span expressed as a fraction of the whole track.
    private var window: Double {
        duration > 0 ? min(1, secondsVisible / duration) : 0.1
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !peaks.isEmpty else { return }

                let barWidth: CGFloat = 2
                let spacing: CGFloat = 1
                let stride = barWidth + spacing
                let barCount = max(1, Int(size.width / stride))
                let midY = size.height / 2

                // Which waveform bin sits under the centre line right now.
                let centerBin = progress * Double(peaks.count - 1)
                let binsPerBar = max(0.05, Double(peaks.count) * window / Double(barCount))
                let base = tint.rgb

                for bar in 0..<barCount {
                    let offsetFromCenter = Double(bar) - Double(barCount) / 2
                    let binIndex = Int((centerBin + offsetFromCenter * binsPerBar).rounded())
                    guard binIndex >= 0, binIndex < peaks.count else { continue }

                    let amplitude = CGFloat(peaks[binIndex])
                    let height = max(1.5, amplitude * size.height * 0.94)
                    let x = CGFloat(bar) * stride

                    // Bass-heavy bins lean toward the deck colour, highs stay pale.
                    let low = Double(binIndex < lowEnergy.count ? lowEnergy[binIndex] : 0)
                    let weight = min(1, low / max(0.05, Double(amplitude)))
                    let pale = 1 - weight
                    let color = Color(red: base.r + (1 - base.r) * pale,
                                      green: base.g + (1 - base.g) * pale,
                                      blue: base.b + (1 - base.b) * pale)

                    let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1),
                                 with: .color(binIndex <= Int(centerBin) ? color : color.opacity(0.42)))
                }

                // Playhead.
                var playhead = Path()
                playhead.move(to: CGPoint(x: size.width / 2, y: 0))
                playhead.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                context.stroke(playhead, with: .color(Theme.accent), lineWidth: 1.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { gesture in
                        guard let onScrub else { return }
                        let start = scrubStart ?? progress
                        if scrubStart == nil { scrubStart = start }
                        // Dragging left moves the track forward, like pushing a record.
                        let delta = -Double(gesture.translation.width) / geometry.size.width * window
                        onScrub(min(1, max(0, start + delta)))
                    }
                    .onEnded { _ in scrubStart = nil }
            )
        }
    }
}

/// Whole-track overview strip with a position marker.
struct WaveformOverview: View {
    let peaks: [Float]
    let progress: Double
    let tint: Color
    var onSeek: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !peaks.isEmpty else { return }
                let barCount = max(1, Int(size.width))
                let step = Double(peaks.count) / Double(barCount)
                let midY = size.height / 2

                for bar in 0..<barCount {
                    let index = min(peaks.count - 1, Int(Double(bar) * step))
                    let height = max(1, CGFloat(peaks[index]) * size.height)
                    let rect = CGRect(x: CGFloat(bar), y: midY - height / 2, width: 1, height: height)
                    let played = Double(bar) / Double(barCount) <= progress
                    context.fill(Path(rect), with: .color(played ? tint : Color.white.opacity(0.18)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onSeek?(min(1, max(0, gesture.location.x / geometry.size.width)))
                    }
            )
        }
    }
}

extension Color {
    /// Components pulled out once per frame so the draw loop can lerp without
    /// round-tripping through UIColor for every bar.
    var rgb: (r: Double, g: Double, b: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
}
