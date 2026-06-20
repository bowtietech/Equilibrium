import SwiftUI

// MARK: - MeditationSessionView
//
// Full-screen immersive meditation session.
// • Large ॐ button counts mala-bead presses (mind-refocus events)
// • Timer counts up; haptic + visual cue fires when the time goal is reached
// • Ambient OM-frequency drone plays in the background (mutable)

struct MeditationSessionView: View {

    let timeGoalMinutes: Int
    /// Called when the user ends the session — receives (durationSeconds, malaCount)
    let onComplete: (Int, Int) -> Void

    @StateObject private var audio = MeditationAudioEngine()
    @State private var malaCount        = 0
    @State private var startTime        = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var goalReached      = false
    @State private var goalHapticFired  = false
    @State private var showEndConfirm   = false
    @State private var beadPulse        = false   // drives button press animation

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .onAppear  { audio.start() }
        .onDisappear { audio.stop() }
        .alert("End session?", isPresented: $showEndConfirm) {
            Button("End & Save", role: .destructive) {
                onComplete(Int(elapsed), malaCount)
            }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("Your session will be saved to history.")
        }
    }

    // MARK: - Subviews

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.16)
                .ignoresSafeArea()
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
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
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
                // Outer ambient glow
                Circle()
                    .fill(Color(red: 0.85, green: 0.62, blue: 0.12).opacity(beadPulse ? 0.28 : 0.12))
                    .frame(width: 230, height: 230)
                    .blur(radius: 28)

                // Button body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.92, green: 0.72, blue: 0.22).opacity(beadPulse ? 0.35 : 0.18),
                                Color(red: 0.12, green: 0.06, blue: 0.28)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                Color(red: 0.90, green: 0.76, blue: 0.32).opacity(beadPulse ? 0.80 : 0.42),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: 196, height: 196)
                    .scaleEffect(beadPulse ? 1.06 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.55), value: beadPulse)

                // OM symbol + count
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
        HStack {
            // Mute / unmute
            Button {
                audio.toggleMute()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(audio.isMuted ? 0.30 : 0.60))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 36)

            Spacer()

            // End session
            Button {
                showEndConfirm = true
            } label: {
                Text("End Session")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 36)
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
