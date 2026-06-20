import AVFoundation
import SwiftUI

// MARK: - Solfeggio frequency catalogue

struct SolfeggioFrequency: Identifiable, Equatable {
    let id: String
    let hz: Double
    let name: String
    /// One-line context shown in the picker card subtitle.
    let tagline: String
    /// Two-sentence description shown in picker cards.
    let description: String
    let icon: String

    static let all: [SolfeggioFrequency] = [
        .init(id: "432",
              hz: 432,
              name: "Universal Harmony",
              tagline: "432 Hz · Natural Tuning",
              description: "Often called the 'natural tuning' frequency, it gently slows the heart rate and brings an effortless sense of calm.",
              icon: "waveform.path"),
        .init(id: "396",
              hz: 396,
              name: "Emotional Release",
              tagline: "396 Hz · Root Chakra",
              description: "Helps dissolve deeply buried guilt, subconscious fear, and heavy negative thoughts — clearing the way for inner stillness.",
              icon: "drop.fill"),
        .init(id: "528",
              hz: 528,
              name: "Love Frequency",
              tagline: "528 Hz · Miracle Tone",
              description: "Research links this tone to lowering cortisol and biological stress markers. Widely regarded as restorative and uplifting.",
              icon: "sparkles"),
        .init(id: "639",
              hz: 639,
              name: "Interpersonal Harmony",
              tagline: "639 Hz · Heart Chakra",
              description: "Encourages clear communication, empathy, and the healing of strained relationships — inside and out.",
              icon: "person.2.fill"),
        .init(id: "963",
              hz: 963,
              name: "Higher Consciousness",
              tagline: "963 Hz · Crown Chakra",
              description: "A pure, transcendent frequency associated with the pineal gland. Cultivates a quiet sense of oneness and spiritual clarity.",
              icon: "rays"),
    ]

    static var `default`: SolfeggioFrequency { all[0] }
}

// MARK: - Audio engine
//
// Signal chain:
//   sourceNode (stereo binaural oscillator)
//     → EQ  (high-shelf -8 dB @ 6 kHz, presence cut -6 dB @ 4 kHz)
//     → delay (380 ms echo, 20% feedback, 25% wet)
//     → reverb (cathedral preset, 65% wet)
//     → mainMixerNode
//
// Left channel:  selectedHz (Solfeggio fundamental + singing-bowl partials)
// Right channel: selectedHz + 8 Hz  (creates an 8 Hz theta-state binaural beat)
//
// A slow 0.08 Hz amplitude LFO produces an organic "breathing" envelope.
// Frequency can be changed live — the render loop snapshots hz values once
// per buffer so transitions are smooth (no clicks).

final class MeditationAudioEngine: ObservableObject {

    @Published private(set) var isMuted = false
    @Published private(set) var selectedFrequency: SolfeggioFrequency = .default

    private let engine  = AVAudioEngine()
    private let eq      = AVAudioUnitEQ(numberOfBands: 2)
    private let delay   = AVAudioUnitDelay()
    private let reverb  = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode?

    // Written from main thread, read once per audio buffer — acceptable on arm64.
    private var renderHzL: Double = SolfeggioFrequency.default.hz
    private var renderHzR: Double = SolfeggioFrequency.default.hz + 8

    // Audio-thread-only accumulators (never read from main thread after start).
    private var phase:    Double = 0
    private var lfoPhase: Double = 0

    private let lfoHz:      Double = 0.08
    private let sampleRate: Double = 44100

    // MARK: - Lifecycle

    init() { configureEffects() }

    private func configureEffects() {
        // High shelf: -8 dB above 6 kHz — tames brightness without cutting any
        // Solfeggio fundamental (396–963 Hz) or its important lower harmonics.
        let shelf        = eq.bands[0]
        shelf.filterType = .highShelf
        shelf.frequency  = 6000
        shelf.gain       = -8
        shelf.bypass     = false

        // Presence cut: -6 dB at 4 kHz — removes boxiness / listening fatigue.
        let cut          = eq.bands[1]
        cut.filterType   = .parametric
        cut.frequency    = 4000
        cut.gain         = -6
        cut.bandwidth    = 1.0
        cut.bypass       = false

        delay.delayTime  = 0.38
        delay.feedback   = 20
        delay.wetDryMix  = 25

        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = 65
    }

    // MARK: - Public API

    func start(frequency: SolfeggioFrequency = .default) {
        guard sourceNode == nil else { return }
        applyFrequency(frequency)

        let rate  = sampleRate
        let lfoHz = self.lfoHz
        let fmt   = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!

        let src = AVAudioSourceNode(format: fmt) { [weak self] _, _, frameCount, ablPtr in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            guard abl.count >= 2,
                  let ch0 = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let ch1 = abl[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }

            var p    = self.phase
            var lfoP = self.lfoPhase
            // Snapshot frequencies once per buffer — smooth glide on change.
            let fl   = self.renderHzL
            let fr   = self.renderHzR

            for i in 0..<Int(frameCount) {
                let lfo = Float(0.72 + 0.28 * sin(2 * .pi * lfoHz * lfoP))

                let left = Float(
                    0.42 * sin(2 * .pi * fl       * p) +
                    0.18 * sin(2 * .pi * fl * 2   * p) +
                    0.09 * sin(2 * .pi * fl * 3   * p) +
                    0.05 * sin(2 * .pi * fl * 0.5 * p) +
                    0.03 * sin(2 * .pi * fl * 5   * p)
                ) * lfo * 0.24

                let right = Float(
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
        engine.attach(src)
        engine.attach(eq)
        engine.attach(delay)
        engine.attach(reverb)
        engine.connect(src,    to: eq,                  format: fmt)
        engine.connect(eq,     to: delay,               format: fmt)
        engine.connect(delay,  to: reverb,              format: fmt)
        engine.connect(reverb, to: engine.mainMixerNode, format: fmt)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                            options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("[MeditationAudio] start failed: \(error)")
        }
    }

    /// Change the playing frequency live. The render loop snapshots Hz values
    /// once per buffer so the transition is a brief, imperceptible pitch glide.
    func setFrequency(_ freq: SolfeggioFrequency) {
        applyFrequency(freq)
    }

    func stop() {
        engine.stop()
        sourceNode = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggleMute() {
        isMuted.toggle()
        engine.mainMixerNode.outputVolume = isMuted ? 0 : 1
    }

    // MARK: - Private

    private func applyFrequency(_ freq: SolfeggioFrequency) {
        selectedFrequency = freq
        renderHzL = freq.hz
        renderHzR = freq.hz + 8   // 8 Hz binaural delta → theta brain-wave entrainment
    }
}
