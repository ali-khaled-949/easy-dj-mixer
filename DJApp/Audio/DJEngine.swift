import AVFoundation
import Combine
import Foundation

/// Owns the AVAudioEngine graph and the two decks.
///
///     deck source ─▶ EQ ─▶ filter ─▶ deck mixer ─┐
///                                                ├─▶ main mixer ─▶ output
///     deck source ─▶ EQ ─▶ filter ─▶ deck mixer ─┘
@MainActor
final class DJEngine: ObservableObject {

    let engine = AVAudioEngine()
    let deckA = Deck(id: .a)
    let deckB = Deck(id: .b)

    /// -1 is deck A alone, +1 is deck B alone.
    @Published var crossfader: Double = 0 { didSet { applyGains() } }
    @Published var masterVolume: Double = 0.9 { didSet { applyGains() } }
    @Published private(set) var isRunning = false
    @Published var engineError: String?

    private var displayTimer: Timer?

    var decks: [Deck] { [deckA, deckB] }

    func deck(_ id: DeckID) -> Deck { id == .a ? deckA : deckB }

    init() {
        for deck in decks {
            deck.onGainChange = { [weak self] in self?.applyGains() }
        }
        buildGraph()
    }

    private func buildGraph() {
        let format = TrackLoader.workingFormat

        for deck in decks {
            engine.attach(deck.sourceNode)
            engine.attach(deck.eqNode)
            engine.attach(deck.filterNode)
            engine.attach(deck.mixerNode)

            engine.connect(deck.sourceNode, to: deck.eqNode, format: format)
            engine.connect(deck.eqNode, to: deck.filterNode, format: format)
            engine.connect(deck.filterNode, to: deck.mixerNode, format: format)
            engine.connect(deck.mixerNode, to: engine.mainMixerNode, format: format)
        }

        applyGains()
    }

    func start() {
        configureSession()
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            engineError = nil
            startDisplayTimer()
        } catch {
            isRunning = false
            engineError = error.localizedDescription
        }
    }

    func stop() {
        displayTimer?.invalidate()
        displayTimer = nil
        engine.stop()
        isRunning = false
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.playback` keeps audio alive when the ring switch is silenced, which is
            // the only sane behaviour for a DJ app.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(TrackLoader.workingFormat.sampleRate)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            engineError = error.localizedDescription
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.decks.forEach { $0.refreshPosition() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    /// Constant-power crossfade, so the perceived level stays flat through the middle.
    private func applyGains() {
        let position = (min(1, max(-1, crossfader)) + 1) / 2
        let gainA = cos(position * .pi / 2)
        let gainB = sin(position * .pi / 2)
        deckA.mixerNode.outputVolume = Float(gainA * deckA.volume)
        deckB.mixerNode.outputVolume = Float(gainB * deckB.volume)
        engine.mainMixerNode.outputVolume = Float(masterVolume)
    }
}
