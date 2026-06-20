import AVFoundation
import SwiftUI

// MARK: - MeditationAudioEngine
//
// Generates a continuous OM/drone tone using AVAudioSourceNode with a
// phase-accumulator oscillator.  The class is intentionally NOT isolated to
// @MainActor so the render closure can run safely on the audio I/O thread.
// `phase` is only ever read/written by the audio thread after start().
// Muting uses the engine's main mixer volume, which is thread-safe.

final class MeditationAudioEngine: ObservableObject {

    @Published private(set) var isMuted = false

    private let engine      = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    // Audio-thread-only state
    private var phase: Double = 0
    private let sampleRate: Double = 44100

    // OM / Schumann / Earth-year frequency (Hz)
    private let f0: Double = 136.1

    // MARK: Lifecycle

    func start() {
        guard sourceNode == nil else { return }
        let rate   = sampleRate
        let f      = f0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!

        let src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, ablPtr in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            guard abl.count >= 2,
                  let ch0 = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let ch1 = abl[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }

            var p = self.phase
            for i in 0..<Int(frameCount) {
                // Fundamental + overtones for a warm, organ-like drone
                let s = Float(
                    0.38 * sin(2 * .pi * f       * p) +
                    0.20 * sin(2 * .pi * f * 2   * p) +
                    0.10 * sin(2 * .pi * f * 3   * p) +
                    0.06 * sin(2 * .pi * f * 0.5 * p) +  // sub-octave
                    0.04 * sin(2 * .pi * f * 4   * p)
                ) * 0.22
                ch0[i] = s
                ch1[i] = s
                p += 1.0 / rate
            }
            self.phase = p
            return noErr
        }

        sourceNode = src
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                             mode: .default,
                                                             options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("[MeditationAudio] start failed: \(error)")
        }
    }

    func stop() {
        engine.stop()
        sourceNode = nil
        try? AVAudioSession.sharedInstance().setActive(false,
                                                        options: .notifyOthersOnDeactivation)
    }

    func toggleMute() {
        isMuted.toggle()
        engine.mainMixerNode.outputVolume = isMuted ? 0 : 1
    }
}
