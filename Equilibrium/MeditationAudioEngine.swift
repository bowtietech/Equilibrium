import AVFoundation
import SwiftUI

// MARK: - MeditationAudioEngine
//
// Signal chain:
//   sourceNode (stereo oscillator)
//     → EQ (low-pass, softens harsh partials)
//     → delay (subtle echo, ~380 ms)
//     → reverb (cathedral, big spatial wash)
//     → mainMixerNode
//
// Left channel:  136.1 Hz fundamental + harmonics
// Right channel: 144.1 Hz fundamental + harmonics  (8 Hz binaural beat → theta state)
//
// A slow 0.08 Hz amplitude LFO creates an organic "breathing" quality.
// The EQ → delay → reverb chain transforms the raw oscillator into a
// warm, spatial, singing-bowl-style ambient drone.

final class MeditationAudioEngine: ObservableObject {

    @Published private(set) var isMuted = false

    private let engine      = AVAudioEngine()
    private let eq          = AVAudioUnitEQ(numberOfBands: 2)
    private let delay       = AVAudioUnitDelay()
    private let reverb      = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode?

    // Audio-thread-only state (never read from main thread after start)
    private var phase: Double = 0
    private var lfoPhase: Double = 0

    // Oscillator parameters
    private let fL: Double  = 136.1   // left ear fundamental (OM / Earth frequency)
    private let fR: Double  = 144.1   // right ear fundamental (8 Hz binaural beat → theta)
    private let lfoHz: Double = 0.08  // breathing rate (~every 12 s)
    private let sampleRate: Double = 44100

    // MARK: - Setup & Lifecycle

    init() {
        configureEffects()
    }

    private func configureEffects() {
        // Low-pass EQ: soften partials above ~900 Hz
        let lp = eq.bands[0]
        lp.filterType  = .lowPass
        lp.frequency   = 900
        lp.bypass      = false

        // Gentle presence cut around 3 kHz (removes harshness)
        let cut = eq.bands[1]
        cut.filterType = .parametric
        cut.frequency  = 3000
        cut.gain       = -8
        cut.bandwidth  = 1.5
        cut.bypass     = false

        // Delay: subtle echo ~380 ms, 20% feedback, 25% wet
        delay.delayTime    = 0.38
        delay.feedback     = 20
        delay.wetDryMix    = 25

        // Reverb: cathedral preset, 65% wet for spacious wash
        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix   = 65
    }

    func start() {
        guard sourceNode == nil else { return }

        let rate   = sampleRate
        let fl     = fL
        let fr     = fR
        let lfoHz  = self.lfoHz
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!

        let src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, ablPtr in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            guard abl.count >= 2,
                  let ch0 = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let ch1 = abl[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }

            var p    = self.phase
            var lfoP = self.lfoPhase

            for i in 0..<Int(frameCount) {
                // Breathing envelope: 0.55 … 1.0
                let lfo    = Float(0.72 + 0.28 * sin(2 * .pi * lfoHz * lfoP))

                // Left: 136.1 Hz + overtones (singing-bowl partials)
                let left   = Float(
                    0.42 * sin(2 * .pi * fl       * p) +
                    0.18 * sin(2 * .pi * fl * 2   * p) +
                    0.09 * sin(2 * .pi * fl * 3   * p) +
                    0.05 * sin(2 * .pi * fl * 0.5 * p) +   // sub-octave warmth
                    0.03 * sin(2 * .pi * fl * 5   * p)     // distant bell partial
                ) * lfo * 0.24

                // Right: 144.1 Hz (binaural theta beat) + same partials
                let right  = Float(
                    0.42 * sin(2 * .pi * fr       * p) +
                    0.18 * sin(2 * .pi * fr * 2   * p) +
                    0.09 * sin(2 * .pi * fr * 3   * p) +
                    0.05 * sin(2 * .pi * fr * 0.5 * p) +
                    0.03 * sin(2 * .pi * fr * 5   * p)
                ) * lfo * 0.24

                ch0[i] = left
                ch1[i] = right

                p    += 1.0 / rate
                lfoP += 1.0 / rate
            }

            self.phase    = p
            self.lfoPhase = lfoP
            return noErr
        }

        sourceNode = src

        // Attach all nodes
        engine.attach(src)
        engine.attach(eq)
        engine.attach(delay)
        engine.attach(reverb)

        // Connect: src → EQ → delay → reverb → main mixer
        engine.connect(src,   to: eq,     format: format)
        engine.connect(eq,    to: delay,  format: format)
        engine.connect(delay, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

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
