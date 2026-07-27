import AVFoundation
import Combine
import Foundation
import QuartzCore

/// One deck: transport, pitch, EQ, filter and the waveform the UI draws.
@MainActor
final class Deck: ObservableObject {

    let id: DeckID
    let source = DeckSource()

    // Nodes owned by this deck, wired up by `DJEngine`.
    let sourceNode: AVAudioSourceNode
    let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    let filterNode = AVAudioUnitEQ(numberOfBands: 1)
    let mixerNode = AVAudioMixerNode()

    @Published private(set) var track: Track?
    @Published private(set) var isLoading = false
    @Published private(set) var waveform: [Float] = []
    @Published private(set) var lowEnergy: [Float] = []
    @Published private(set) var duration: Double = 0
    @Published private(set) var position: Double = 0
    @Published private(set) var isPlaying = false
    @Published var loadError: String?

    @Published var cuePoint: Double = 0

    /// Pitch fader, -1...1 across the current `pitchRange`.
    @Published var pitch: Double = 0 { didSet { applyRate() } }
    @Published var pitchRange: Double = 0.08 { didSet { applyRate() } }

    @Published var volume: Double = 0.85 { didSet { onGainChange?() } }
    @Published var low: Double = 0.5 { didSet { applyEQ() } }
    @Published var mid: Double = 0.5 { didSet { applyEQ() } }
    @Published var high: Double = 0.5 { didSet { applyEQ() } }
    @Published var filter: Double = 0 { didSet { applyFilter() } }

    /// Called when the deck's own volume changes so the engine can re-apply the crossfader.
    var onGainChange: (() -> Void)?

    private var scratchWasPlaying = false
    private var lastScratchUpdate: CFTimeInterval = 0

    var tempo: Double? {
        guard let bpm = track?.bpm else { return nil }
        return bpm * (1 + pitch * pitchRange)
    }

    var remaining: Double { max(0, duration - position) }

    var progress: Double {
        duration > 0 ? min(1, max(0, position / duration)) : 0
    }

    init(id: DeckID) {
        self.id = id
        let source = self.source
        sourceNode = AVAudioSourceNode(format: TrackLoader.workingFormat) { _, _, frameCount, audioBufferList in
            source.render(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        eqNode.globalGain = 0
        eqNode.bands[0].filterType = .lowShelf
        eqNode.bands[0].frequency = 120
        eqNode.bands[1].filterType = .parametric
        eqNode.bands[1].frequency = 1_000
        eqNode.bands[1].bandwidth = 1.2
        eqNode.bands[2].filterType = .highShelf
        eqNode.bands[2].frequency = 6_000
        for band in eqNode.bands {
            band.gain = 0
            band.bypass = false
        }

        filterNode.bands[0].filterType = .lowPass
        filterNode.bands[0].frequency = 20_000
        filterNode.bands[0].bypass = true

        applyEQ()
        applyFilter()
        applyRate()
    }

    // MARK: - Loading

    func load(_ track: Track) {
        isLoading = true
        let url = track.url
        Task.detached(priority: .userInitiated) {
            let result = Result { try TrackLoader.load(url: url) }
            await MainActor.run { self.finishLoad(track, result) }
        }
    }

    private func finishLoad(_ track: Track, _ result: Result<LoadedTrack, Error>) {
        isLoading = false
        switch result {
        case .success(let loaded):
            source.load(buffer: loaded.buffer)
            waveform = loaded.waveform
            lowEnergy = loaded.lowEnergy
            duration = loaded.duration
            position = 0
            cuePoint = 0
            isPlaying = false
            var resolved = track
            resolved.duration = loaded.duration
            resolved.bpm = track.bpm ?? loaded.bpm
            self.track = resolved
        case .failure(let error):
            loadError = error.localizedDescription
        }
    }

    func eject() {
        source.unload()
        track = nil
        waveform = []
        lowEnergy = []
        duration = 0
        position = 0
        isPlaying = false
    }

    // MARK: - Transport

    func togglePlay() {
        guard source.hasTrack else { return }
        if isPlaying {
            pause()
        } else {
            if source.reachedEnd { source.positionSeconds = cuePoint }
            source.isPlaying = true
            isPlaying = true
        }
    }

    func pause() {
        source.isPlaying = false
        isPlaying = false
    }

    /// Cue behaves like a real DJ mixer: tap while stopped to set the cue point,
    /// hold to preview from it, release to snap back.
    func cuePressed() {
        guard source.hasTrack else { return }
        if isPlaying {
            pause()
            source.positionSeconds = cuePoint
            position = cuePoint
        } else {
            cuePoint = source.positionSeconds
            source.isPlaying = true
            isPlaying = true
        }
    }

    func cueReleased() {
        guard source.hasTrack, isPlaying else { return }
        pause()
        source.positionSeconds = cuePoint
        position = cuePoint
    }

    func seek(toProgress value: Double) {
        guard duration > 0 else { return }
        let seconds = min(duration, max(0, value * duration))
        source.positionSeconds = seconds
        position = seconds
    }

    func nudge(seconds: Double) {
        guard duration > 0 else { return }
        seek(toProgress: (position + seconds) / duration)
    }

    // MARK: - Scratching

    func beginScratch() {
        guard source.hasTrack else { return }
        scratchWasPlaying = isPlaying
        source.scratchRate = 0
        source.isScratching = true
    }

    /// `rate` is a multiple of normal playback speed; negative runs the track backwards.
    func updateScratch(rate: Double) {
        source.scratchRate = max(-8, min(8, rate))
        lastScratchUpdate = CACurrentMediaTime()
    }

    func endScratch() {
        source.isScratching = false
        source.isPlaying = scratchWasPlaying
        isPlaying = scratchWasPlaying
    }

    // MARK: - Parameters

    func refreshPosition() {
        guard source.hasTrack else { return }
        position = source.positionSeconds
        if isPlaying && !source.isPlaying { isPlaying = false }

        // A finger resting on the platter sends no gesture updates, so without this
        // the record would keep spinning at whatever speed it was last flicked.
        if source.isScratching, CACurrentMediaTime() - lastScratchUpdate > 0.05 {
            source.scratchRate = 0
        }
    }

    /// Flattens EQ and filter back to neutral. Deliberately leaves the channel fader
    /// and pitch alone — snapping the volume up mid-set would be a nasty surprise.
    func resetTone() {
        low = 0.5
        mid = 0.5
        high = 0.5
        filter = 0
    }

    var isToneNeutral: Bool {
        abs(low - 0.5) < 0.01 && abs(mid - 0.5) < 0.01 && abs(high - 0.5) < 0.01 && abs(filter) < 0.03
    }

    private func applyRate() {
        source.rate = 1 + pitch * pitchRange
    }

    private func applyEQ() {
        eqNode.bands[0].gain = Self.eqGain(low)
        eqNode.bands[1].gain = Self.eqGain(mid)
        eqNode.bands[2].gain = Self.eqGain(high)
    }

    /// 0 kills the band, 0.5 is unity, 1 adds 6 dB — the usual DJ mixer taper.
    private static func eqGain(_ value: Double) -> Float {
        let clamped = min(1, max(0, value))
        if clamped >= 0.5 {
            return Float((clamped - 0.5) / 0.5 * 6)
        }
        return Float(-26 + (clamped / 0.5) * 26)
    }

    private func applyFilter() {
        let amount = min(1, max(-1, filter))
        let band = filterNode.bands[0]
        if abs(amount) < 0.03 {
            band.bypass = true
            return
        }
        band.bypass = false
        if amount < 0 {
            band.filterType = .lowPass
            band.frequency = Float(exp2(log2(20_000.0) + amount * (log2(20_000.0) - log2(220.0))))
        } else {
            band.filterType = .highPass
            band.frequency = Float(exp2(log2(30.0) + amount * (log2(6_000.0) - log2(30.0))))
        }
    }
}
