import Accelerate
import AVFoundation
import Foundation

/// Everything a deck needs after an offline analysis pass.
struct LoadedTrack {
    let buffer: AVAudioPCMBuffer
    /// Peak envelope, one value per waveform bin, normalised to 0...1.
    let waveform: [Float]
    /// Per-bin low-frequency energy, used to tint the waveform like a real DJ app.
    let lowEnergy: [Float]
    let duration: Double
    let bpm: Double?
}

enum TrackLoaderError: LocalizedError {
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let name): return "Couldn't decode \(name). Try MP3, M4A, WAV or AIFF."
        }
    }
}

enum TrackLoader {

    static let waveformBins = 2_400
    static let workingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: 44_100,
                                             channels: 2,
                                             interleaved: false)!

    /// Decodes `url` fully into memory at the engine's working format and analyses it.
    /// Call off the main thread — a five minute track takes a moment.
    static func load(url: URL) throws -> LoadedTrack {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let file = try? AVAudioFile(forReading: url) else {
            throw TrackLoaderError.unreadable(url.lastPathComponent)
        }

        let sourceFormat = file.processingFormat
        let ratio = workingFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(file.length) * ratio) + 4_096

        guard capacity > 0,
              let output = AVAudioPCMBuffer(pcmFormat: workingFormat, frameCapacity: capacity) else {
            throw TrackLoaderError.unreadable(url.lastPathComponent)
        }

        if sourceFormat == workingFormat {
            try file.read(into: output)
        } else {
            guard let converter = AVAudioConverter(from: sourceFormat, to: workingFormat) else {
                throw TrackLoaderError.unreadable(url.lastPathComponent)
            }
            guard let scratch = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 16_384) else {
                throw TrackLoaderError.unreadable(url.lastPathComponent)
            }

            var finished = false
            var written: AVAudioFrameCount = 0

            while !finished && written < capacity {
                guard let chunk = AVAudioPCMBuffer(pcmFormat: workingFormat,
                                                   frameCapacity: min(16_384, capacity - written)) else { break }
                var error: NSError?
                let status = converter.convert(to: chunk, error: &error) { _, inputStatus in
                    do {
                        scratch.frameLength = 0
                        try file.read(into: scratch)
                    } catch {
                        inputStatus.pointee = .endOfStream
                        return nil
                    }
                    if scratch.frameLength == 0 {
                        inputStatus.pointee = .endOfStream
                        return nil
                    }
                    inputStatus.pointee = .haveData
                    return scratch
                }

                if let error { throw error }
                if chunk.frameLength == 0 || status == .endOfStream { finished = true }
                append(chunk, to: output, at: written)
                written += chunk.frameLength
                if status == .endOfStream { finished = true }
            }
            output.frameLength = written
        }

        guard output.frameLength > 0 else {
            throw TrackLoaderError.unreadable(url.lastPathComponent)
        }

        let analysis = analyse(output)
        return LoadedTrack(buffer: output,
                           waveform: analysis.peaks,
                           lowEnergy: analysis.lows,
                           duration: Double(output.frameLength) / workingFormat.sampleRate,
                           bpm: analysis.bpm)
    }

    private static func append(_ chunk: AVAudioPCMBuffer, to output: AVAudioPCMBuffer, at offset: AVAudioFrameCount) {
        guard chunk.frameLength > 0,
              let src = chunk.floatChannelData,
              let dst = output.floatChannelData else { return }
        let frames = Int(min(chunk.frameLength, output.frameCapacity - offset))
        guard frames > 0 else { return }
        for channel in 0..<Int(output.format.channelCount) {
            memcpy(dst[channel] + Int(offset), src[channel], frames * MemoryLayout<Float>.size)
        }
    }

    // MARK: - Analysis

    private struct Analysis {
        let peaks: [Float]
        let lows: [Float]
        let bpm: Double?
    }

    private static func analyse(_ buffer: AVAudioPCMBuffer) -> Analysis {
        let frames = Int(buffer.frameLength)
        guard frames > 0, let channels = buffer.floatChannelData else {
            return Analysis(peaks: [], lows: [], bpm: nil)
        }

        let left = channels[0]
        let right = buffer.format.channelCount > 1 ? channels[1] : channels[0]

        // Mono mixdown once; both the waveform and the beat tracker read from it.
        var mono = [Float](repeating: 0, count: frames)
        vDSP_vadd(left, 1, right, 1, &mono, 1, vDSP_Length(frames))
        var half: Float = 0.5
        vDSP_vsmul(mono, 1, &half, &mono, 1, vDSP_Length(frames))

        let binCount = min(waveformBins, max(1, frames / 64))
        let binSize = max(1, frames / binCount)

        var peaks = [Float](repeating: 0, count: binCount)
        var lows = [Float](repeating: 0, count: binCount)

        // One-pole low pass (~150 Hz) to separate the kick energy for waveform colour.
        var lowState: Float = 0
        let lowCoefficient: Float = 0.021

        mono.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            for bin in 0..<binCount {
                let start = bin * binSize
                let length = min(binSize, frames - start)
                guard length > 0 else { break }

                var peak: Float = 0
                vDSP_maxmgv(base + start, 1, &peak, vDSP_Length(length))
                peaks[bin] = peak

                var lowPeak: Float = 0
                for index in start..<(start + length) {
                    lowState += lowCoefficient * (base[index] - lowState)
                    lowPeak = max(lowPeak, abs(lowState))
                }
                lows[bin] = lowPeak
            }
        }

        var maxPeak: Float = 0
        vDSP_maxv(peaks, 1, &maxPeak, vDSP_Length(binCount))
        if maxPeak > 0 {
            var scale = 1 / maxPeak
            vDSP_vsmul(peaks, 1, &scale, &peaks, 1, vDSP_Length(binCount))
            vDSP_vsmul(lows, 1, &scale, &lows, 1, vDSP_Length(binCount))
        }
        for index in 0..<binCount { lows[index] = min(1, lows[index]) }

        return Analysis(peaks: peaks, lows: lows, bpm: estimateBPM(mono: mono, sampleRate: workingFormat.sampleRate))
    }

    /// Tempo estimate from the autocorrelation of an onset-strength envelope.
    /// Good enough to label a track; not a beat grid.
    private static func estimateBPM(mono: [Float], sampleRate: Double) -> Double? {
        let hop = 512
        let frames = mono.count
        guard frames > hop * 64 else { return nil }

        let envelopeRate = sampleRate / Double(hop)
        var envelope = [Float]()
        envelope.reserveCapacity(frames / hop)

        mono.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            var index = 0
            while index + hop <= frames {
                var energy: Float = 0
                vDSP_measqv(base + index, 1, &energy, vDSP_Length(hop))
                envelope.append(sqrt(energy))
                index += hop
            }
        }

        guard envelope.count > 128 else { return nil }

        // Half-wave rectified difference keeps only rising energy — the onsets.
        var onsets = [Float](repeating: 0, count: envelope.count)
        for index in 1..<envelope.count {
            onsets[index] = max(0, envelope[index] - envelope[index - 1])
        }

        var mean: Float = 0
        vDSP_meanv(onsets, 1, &mean, vDSP_Length(onsets.count))
        var negativeMean = -mean
        vDSP_vsadd(onsets, 1, &negativeMean, &onsets, 1, vDSP_Length(onsets.count))

        let minLag = Int(envelopeRate * 60.0 / 200.0)   // 200 BPM
        let maxLag = Int(envelopeRate * 60.0 / 60.0)    // 60 BPM
        guard maxLag < onsets.count / 2, minLag < maxLag else { return nil }

        var bestLag = minLag
        var bestScore = -Float.greatestFiniteMagnitude

        onsets.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            for lag in minLag...maxLag {
                let length = onsets.count - lag
                var score: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &score, vDSP_Length(length))
                score /= Float(length)
                if score > bestScore {
                    bestScore = score
                    bestLag = lag
                }
            }
        }

        var bpm = 60.0 * envelopeRate / Double(bestLag)
        while bpm < 85 { bpm *= 2 }
        while bpm > 175 { bpm /= 2 }
        return (bpm * 10).rounded() / 10
    }
}
