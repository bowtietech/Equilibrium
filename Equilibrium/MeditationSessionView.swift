import SwiftUI

// MARK: - MeditationSessionView
//
// Full-screen immersive meditation session.
// • Frequency selector at bottom — pick any Solfeggio tone before or during session
// • Large ॐ button counts mala-bead presses (mind-refocus events)
// • Timer counts up; haptic + visual cue fires when the time goal is reached
// • Ambient binaural drone plays in the background (mutable)

struct MeditationSessionView: View {

    let timeGoalMinutes: Int
    let initialFrequency: SolfeggioFrequency
    /// Called when the user ends the session — receives (durationSeconds, malaCount).
    let onComplete: (Int, Int) -> Void

    @StateObject private var audio = MeditationAudioEngine()
    @State private var malaCount       = 0
    @State private var startTime       = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var goalReached     = false
    @State private var goalHapticFired = false
    @State private var showEndConfirm  = false
    @State private var showFreqPicker  = false
    @State private var beadPulse       = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(timeGoalMinutes: Int,
         frequency: SolfeggioFrequency = .default,
         onComplete: @escaping (Int, Int) -> Void) {
        self.timeGoalMinutes  = timeGoalMinutes
        self.initialFrequency = frequency
        self.onComplete       = onComplete
    }

    // MARK: Body

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                timerBlock
                    .padding(.top, 64)

                Spacer()

                omButton

                instructionText
                    .padding(.top, 24)
                    .padding(.horizontal, 44)

                Spacer()

                bottomBar
                    .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onReceive(ticker) { _ in
            elapsed = Date().timeIntervalSince(startTime)
            if !goalHapticFired && elapsed >= Double(timeGoalMinutes * 60) {
                goalReached     = true
                goalHapticFired = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .onAppear  { audio.start(frequency: initialFrequency) }
        .onDisappear { audio.stop() }
        .alert("End session?", isPresented: $showEndConfirm) {
            Button("End & Save", role: .destructive) { onComplete(Int(elapsed), malaCount) }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("Your session will be saved to history.")
        }
        .sheet(isPresented: $showFreqPicker) {
            FrequencyPickerSheet(selected: audio.selectedFrequency) { freq in
                withAnimation(.easeInOut(duration: 0.3)) { audio.setFrequency(freq) }
                showFreqPicker = false
            }
            .presentationDetents([.fraction(0.72)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Subviews

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.16).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.55, green: 0.30, blue: 0.75).opacity(0.22), .clear],
                center: .center, startRadius: 60, endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var timerBlock: some View {
        VStack(spacing: 6) {
            Text(formattedTime(elapsed))
                .font(.system(size: 62, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()

            if goalReached {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill").font(.system(size: 12))
                    Text("Goal reached · \(timeGoalMinutes) min")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.88, blue: 0.4))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                Text("Goal  \(timeGoalMinutes) min")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.white.opacity(0.30))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: goalReached)
    }

    private var omButton: some View {
        Button {
            malaCount += 1
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { beadPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { beadPulse = false }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.85, green: 0.62, blue: 0.12).opacity(beadPulse ? 0.28 : 0.12))
                    .frame(width: 230, height: 230)
                    .blur(radius: 28)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.92, green: 0.72, blue: 0.22).opacity(beadPulse ? 0.35 : 0.18),
                                Color(red: 0.12, green: 0.06, blue: 0.28),
                            ],
                            center: .center, startRadius: 10, endRadius: 100
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.90, green: 0.76, blue: 0.32)
                                        .opacity(beadPulse ? 0.80 : 0.42), lineWidth: 1.5)
                    )
                    .frame(width: 196, height: 196)
                    .scaleEffect(beadPulse ? 1.06 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.55), value: beadPulse)

                VStack(spacing: 6) {
                    Text("ॐ")
                        .font(.system(size: 82))
                        .foregroundStyle(
                            Color(red: 1.0, green: 0.94, blue: 0.65)
                                .opacity(beadPulse ? 1.0 : 0.88)
                        )
                        .scaleEffect(beadPulse ? 1.08 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: beadPulse)

                    Text("\(malaCount)")
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: malaCount)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var instructionText: some View {
        Text("Each time your mind wanders, say ॐ and press the button to count your mala beads")
            .font(.system(size: 13, weight: .light))
            .foregroundStyle(.white.opacity(0.38))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            // Mute / unmute
            Button {
                audio.toggleMute()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(audio.isMuted ? 0.30 : 0.60))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 28)

            Spacer()

            // Frequency indicator pill — tap to change
            Button { showFreqPicker = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: audio.selectedFrequency.icon)
                        .font(.system(size: 11))
                    Text(audio.selectedFrequency.tagline)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.60))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.25), value: audio.selectedFrequency.id)

            Spacer()

            // End session
            Button { showEndConfirm = true } label: {
                Text("End")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 28)
        }
    }

    // MARK: - Helpers

    private func formattedTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - In-session frequency picker sheet

private struct FrequencyPickerSheet: View {
    let selected: SolfeggioFrequency
    let onSelect: (SolfeggioFrequency) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Frequency")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.40))
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(SolfeggioFrequency.all) { freq in
                        SessionFreqRow(freq: freq,
                                       isSelected: freq.id == selected.id,
                                       onTap: { onSelect(freq) })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.18))
    }
}

private struct SessionFreqRow: View {
    let freq: SolfeggioFrequency
    let isSelected: Bool
    let onTap: () -> Void

    // Fixed accent colour for the session sheet (goal colour not available here)
    private let accent = Color(red: 0.70, green: 0.50, blue: 0.90)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: freq.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(isSelected ? accent : .white.opacity(0.45))
                    .frame(width: 36, height: 36)
                    .background(
                        (isSelected ? accent.opacity(0.15) : Color.white.opacity(0.05)),
                        in: Circle()
                    )

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(freq.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSelected ? accent : .white.opacity(0.85))
                        Text("·")
                            .foregroundStyle(.white.opacity(0.25))
                        Text("\(Int(freq.hz)) Hz")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    Text(freq.tagline.components(separatedBy: " · ").last ?? freq.tagline)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accent.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? accent.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
