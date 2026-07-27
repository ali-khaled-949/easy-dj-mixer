import AVFoundation
import Foundation

/// Synthesises a couple of royalty-free loops on first launch so both decks have
/// something to play before the user imports anything — and so the mixer can be
/// tested in the Simulator, which has no music library.
enum DemoTrackFactory {

    private static let sampleRate: Double = 44_100

    static func makeDemoTracksIfNeeded() -> [Track] {
        let folder = AppPaths.demos
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let specs: [(name: String, artist: String, bpm: Double, bars: Int, build: (Int, Double, Int) -> Float)] = [
            ("Neon Drive", "House Demo", 124, 16, houseSample),
            ("Midnight Cassette", "Downtempo Demo", 92, 16, downtempoSample)
        ]

        return specs.compactMap { spec in
            let url = folder.appendingPathComponent("\(spec.name).wav")
            let beatsPerBar = 4.0
            let duration = Double(spec.bars) * beatsPerBar * 60.0 / spec.bpm

            if !FileManager.default.fileExists(atPath: url.path) {
                guard render(to: url, duration: duration, bpm: spec.bpm, sample: spec.build) else { return nil }
            }
            return Track(title: spec.name, artist: spec.artist, url: url, duration: duration, bpm: spec.bpm)
        }
    }

    private static func render(to url: URL,
                               duration: Double,
                               bpm: Double,
                               sample: (Int, Double, Int) -> Float) -> Bool {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        guard let file = try? AVAudioFile(forWriting: url, settings: settings),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return false
        }

        let totalFrames = Int(sampleRate * duration)
        let samplesPerBeat = sampleRate * 60.0 / bpm
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        guard let channels = buffer.floatChannelData else { return false }

        for frame in 0..<totalFrames {
            let beatPosition = Double(frame) / samplesPerBeat
            let step = Int(beatPosition * 4) % 16
            var value = sample(frame, beatPosition, step)
            value = tanh(value * 1.4) * 0.85
            channels[0][frame] = value
            channels[1][frame] = value
        }

        do {
            try file.write(from: buffer)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Voices

    private static func envelope(_ position: Double, decay: Double) -> Float {
        position < 0 ? 0 : Float(exp(-position / decay))
    }

    /// Time since the most recent occurrence of `interval` beats, in seconds.
    private static func sinceBeat(_ beatPosition: Double, every interval: Double, offset: Double = 0, bpm: Double) -> Double {
        let shifted = beatPosition - offset
        guard shifted >= 0 else { return .greatestFiniteMagnitude }
        let phase = shifted.truncatingRemainder(dividingBy: interval)
        return phase * 60.0 / bpm
    }

    private static func noise() -> Float {
        Float.random(in: -1...1)
    }

    /// Explicitly typed so the synthesis expressions stay trivial for the type checker.
    private static func osc(_ frequency: Double, _ time: Double) -> Float {
        let phase: Double = 2.0 * Double.pi * frequency * time
        return Float(sin(phase))
    }

    private static func houseSample(frame: Int, beatPosition: Double, step: Int) -> Float {
        let bpm = 124.0
        let time = Double(frame) / sampleRate
        var out: Float = 0

        // Four-on-the-floor kick with a pitch drop.
        let kickTime = sinceBeat(beatPosition, every: 1, bpm: bpm)
        if kickTime < 0.4 {
            let pitch: Double = 45 + 85 * exp(-kickTime / 0.03)
            out += osc(pitch, kickTime) * envelope(kickTime, decay: 0.11) * 0.95
        }

        // Offbeat open hat.
        let hatTime = sinceBeat(beatPosition, every: 1, offset: 0.5, bpm: bpm)
        if hatTime < 0.12 {
            out += noise() * envelope(hatTime, decay: 0.035) * 0.16
        }

        // Rolling bass line.
        let bassNotes: [Double] = [55, 55, 82.41, 55, 65.41, 55, 73.42, 65.41]
        let bassNote = bassNotes[(step / 2) % bassNotes.count]
        let bassTime = sinceBeat(beatPosition, every: 0.5, bpm: bpm)
        if bassTime < 0.35 {
            let tone = sin(2 * .pi * bassNote * time) * 0.7 + sin(4 * .pi * bassNote * time) * 0.2
            out += Float(tone) * envelope(bassTime, decay: 0.09) * 0.5
        }

        // Chord stab on the offbeat, entering after the first four bars.
        if beatPosition > 16 {
            let stabTime = sinceBeat(beatPosition, every: 2, offset: 1.5, bpm: bpm)
            if stabTime < 0.5 {
                let chord: [Double] = [329.63, 392.00, 493.88]
                var voices = 0.0
                for note in chord {
                    voices += sin(2 * .pi * note * time) + 0.4 * sin(2 * .pi * note * 1.005 * time)
                }
                out += Float(voices / 6) * envelope(stabTime, decay: 0.16) * 0.35
            }
        }

        return out
    }

    private static func downtempoSample(frame: Int, beatPosition: Double, step: Int) -> Float {
        let bpm = 92.0
        let time = Double(frame) / sampleRate
        var out: Float = 0

        // Kick on 1 and the "and" of 3.
        for offset in [0.0, 2.5] {
            let kickTime = sinceBeat(beatPosition, every: 4, offset: offset, bpm: bpm)
            if kickTime < 0.5 {
                let pitch: Double = 42 + 70 * exp(-kickTime / 0.04)
                out += osc(pitch, kickTime) * envelope(kickTime, decay: 0.14) * 0.9
            }
        }

        // Backbeat snare.
        let snareTime = sinceBeat(beatPosition, every: 2, offset: 1, bpm: bpm)
        if snareTime < 0.25 {
            out += noise() * envelope(snareTime, decay: 0.07) * 0.35
            out += Float(sin(2 * .pi * 190 * snareTime)) * envelope(snareTime, decay: 0.05) * 0.25
        }

        // Sixteenth hats, quieter on the weak steps.
        let hatTime = sinceBeat(beatPosition, every: 0.25, bpm: bpm)
        if hatTime < 0.05 {
            out += noise() * envelope(hatTime, decay: 0.012) * (step % 2 == 0 ? 0.09 : 0.05)
        }

        // Sub bass following a slow progression.
        let notes: [Double] = [49.0, 49.0, 65.41, 58.27]
        let note = notes[(Int(beatPosition) / 4) % notes.count]
        out += Float(sin(2 * .pi * note * time)) * 0.32

        // Warm pad chord.
        let pad: [Double] = [196.00, 233.08, 293.66]
        var voices = 0.0
        for tone in pad {
            voices += sin(2 * .pi * tone * time) * 0.5 + sin(2 * .pi * tone * 0.997 * time) * 0.3
        }
        out += Float(voices / 8) * 0.3

        return out
    }
}
