import AVFoundation
import Foundation
import os

/// The real-time audio source for one deck.
///
/// Holds the decoded track in memory and renders it with a movable playhead so the
/// deck can play, scrub, scratch and pitch-shift sample-accurately. Everything below
/// `render` runs on the audio thread: no allocation, no ObjC, no locks that block.
final class DeckSource: @unchecked Sendable {

    // Buffer state, guarded by `lock` (the render block only ever *tries* the lock).
    private var storage: AVAudioPCMBuffer?
    private var left: UnsafePointer<Float>?
    private var right: UnsafePointer<Float>?
    private var frameCount: Int = 0
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)

    /// Sample rate of the loaded material; the engine runs everything at this rate.
    let sampleRate: Double = 44_100

    // Audio-thread state. 64-bit aligned scalars, written from the main thread and
    // read once per render cycle — a frame of latency on a knob turn is inaudible.
    private var playhead: Double = 0
    var isPlaying: Bool = false
    var rate: Double = 1.0
    var isScratching: Bool = false
    var scratchRate: Double = 0

    /// Click-free start/stop: the output is multiplied by an envelope that ramps
    /// toward the transport state instead of jumping.
    private var envelope: Float = 0
    private static let envelopeStep: Float = 1.0 / 512.0

    init() {
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deallocate()
    }

    // MARK: - Control thread

    func load(buffer: AVAudioPCMBuffer) {
        os_unfair_lock_lock(lock)
        storage = buffer
        frameCount = Int(buffer.frameLength)
        let channels = buffer.floatChannelData!
        left = UnsafePointer(channels[0])
        right = UnsafePointer(channels[buffer.format.channelCount > 1 ? 1 : 0])
        playhead = 0
        isPlaying = false
        envelope = 0
        os_unfair_lock_unlock(lock)
    }

    func unload() {
        os_unfair_lock_lock(lock)
        isPlaying = false
        left = nil
        right = nil
        frameCount = 0
        storage = nil
        playhead = 0
        os_unfair_lock_unlock(lock)
    }

    /// Playhead position in seconds.
    var positionSeconds: Double {
        get { playhead / sampleRate }
        set { playhead = max(0, min(newValue * sampleRate, Double(frameCount))) }
    }

    var durationSeconds: Double {
        Double(frameCount) / sampleRate
    }

    var hasTrack: Bool { frameCount > 0 }

    /// True once the playhead has run past the end of the track.
    var reachedEnd: Bool { frameCount > 0 && Int(playhead) >= frameCount - 1 }

    // MARK: - Audio thread

    func render(frameCount frames: AVAudioFrameCount,
                audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        guard os_unfair_lock_trylock(lock) else {
            silence(ablPointer, frames)
            return noErr
        }
        defer { os_unfair_lock_unlock(lock) }

        guard let l = left, let r = right, self.frameCount > 1 else {
            silence(ablPointer, frames)
            return noErr
        }

        let outL = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
        let outR = ablPointer.count > 1 ? ablPointer[1].mData!.assumingMemoryBound(to: Float.self) : outL

        // While scratching the jog wheel drives the playhead directly, so the deck
        // stays audible (and reverses) even when the transport is stopped.
        let target: Float = (isPlaying || isScratching) ? 1 : 0
        let step = isScratching ? rate * scratchRate : (isPlaying ? rate : 0)
        let last = Double(self.frameCount - 1)

        for frame in 0..<Int(frames) {
            if envelope < target {
                envelope = min(target, envelope + Self.envelopeStep)
            } else if envelope > target {
                envelope = max(target, envelope - Self.envelopeStep)
            }

            if playhead < 0 { playhead = 0 }
            if playhead > last { playhead = last }

            let index = Int(playhead)
            let frac = Float(playhead - Double(index))
            let next = min(index + 1, self.frameCount - 1)

            outL[frame] = (l[index] + (l[next] - l[index]) * frac) * envelope
            outR[frame] = (r[index] + (r[next] - r[index]) * frac) * envelope

            playhead += step
            if playhead >= last {
                playhead = last
                if !isScratching { isPlaying = false }
            } else if playhead <= 0 {
                playhead = 0
            }
        }

        return noErr
    }

    private func silence(_ abl: UnsafeMutableAudioBufferListPointer, _ frames: AVAudioFrameCount) {
        for buffer in abl {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        _ = frames
    }
}
