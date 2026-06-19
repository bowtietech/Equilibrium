import SwiftUI

// MARK: - AIAssistantOverlay
//
// Floating mic button with two interaction modes:
//   Tap  — toggle listening on/off (same as before)
//   Hold — listen for the duration of the press; release to process

struct AIAssistantOverlay: View {
    @EnvironmentObject private var store: DataStore
    @StateObject private var speech    = SpeechManager()
    @StateObject private var assistant = AIGoalAssistant()

    @State private var phase: Phase    = .idle
    @State private var isHoldMode      = false   // true while finger is held down

    // Press tracking for tap-vs-hold discrimination
    @State private var pressStart: Date?
    @State private var holdActivateTask: Task<Void, Never>?

    private enum Phase { case idle, listening, thinking }
    private let holdThreshold: TimeInterval = 0.25   // seconds before hold mode activates

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    // Pulse rings while listening
                    if phase == .listening {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.accentColor.opacity(0.25 - Double(i) * 0.06), lineWidth: 1.5)
                                .frame(width: 56 + CGFloat(i) * 22,
                                       height: 56 + CGFloat(i) * 22)
                                .animation(
                                    .easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.3),
                                    value: phase == .listening
                                )
                        }
                    }

                    // Mic button — gesture-driven so we can distinguish tap from hold
                    ZStack {
                        Circle()
                            .fill(buttonColor)
                            .frame(width: 52, height: 52)
                            .shadow(color: buttonColor.opacity(0.45), radius: 12, x: 0, y: 4)
                            .scaleEffect(isHoldMode ? 1.12 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHoldMode)

                        if phase == .thinking {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: phase == .listening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in handlePressDown() }
                            .onEnded   { _ in handlePressUp()   }
                    )
                    .disabled(phase == .thinking)

                    // "Release to send" hint during hold
                    if isHoldMode {
                        Text("Release to send")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.55))
                            .offset(y: 42)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 110)
            }

            // Live transcript bubble
            if phase == .listening && !speech.liveTranscript.isEmpty {
                transcriptBubble
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Result / error toast
            if let msg = assistant.lastMessage {
                toastCard(text: msg, isError: false)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let err = assistant.lastError {
                toastCard(text: err, isError: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: assistant.lastMessage)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: assistant.lastError)
        .onChange(of: assistant.isProcessing) { _, processing in
            phase = processing ? .thinking : .idle
        }
        .onAppear {
            // Auto-process when SFSpeechRecognizer returns a final result
            // (only relevant in tap mode — hold mode processes on release)
            speech.onFinalTranscript = { [weak assistant] text in
                Task { @MainActor in
                    guard !self.isHoldMode else { return }
                    await assistant?.process(transcript: text, store: self.store)
                }
            }
        }
    }

    // MARK: - Press handling

    private func handlePressDown() {
        guard phase != .thinking else { return }
        guard pressStart == nil else { return }   // already tracking

        pressStart = Date()

        // Schedule hold activation after threshold
        holdActivateTask = Task {
            try? await Task.sleep(for: .seconds(holdThreshold))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .idle else { return }
                isHoldMode = true
                phase = .listening
                Task { await speech.startRecording() }
            }
        }
    }

    private func handlePressUp() {
        let start = pressStart
        pressStart = nil
        holdActivateTask?.cancel()
        holdActivateTask = nil

        if isHoldMode {
            // Hold release → stop and immediately process
            isHoldMode = false
            let transcript = speech.liveTranscript
            speech.stopRecording()
            guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else {
                phase = .idle
                return
            }
            Task { await assistant.process(transcript: transcript, store: store) }

        } else {
            // Quick tap → toggle mode (same behaviour as before)
            let elapsed = start.map { Date().timeIntervalSince($0) } ?? 0
            guard elapsed < 0.6 else { return }  // ignore stale releases
            handleTap()
        }
    }

    // MARK: - Tap toggle

    private func handleTap() {
        switch phase {
        case .idle:
            phase = .listening
            Task { await speech.startRecording() }

        case .listening:
            let transcript = speech.liveTranscript
            speech.stopRecording()
            guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else {
                phase = .idle
                return
            }
            Task { await assistant.process(transcript: transcript, store: store) }

        case .thinking:
            break
        }
    }

    // MARK: - Subviews

    private var transcriptBubble: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundStyle(.primary.opacity(0.5))
                .font(.system(size: 12))
            Text(speech.liveTranscript)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func toastCard(text: String, isError: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .orange : .green)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation {
                    assistant.lastMessage = nil
                    assistant.lastError   = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private var buttonColor: Color {
        switch phase {
        case .idle:      return Color.accentColor
        case .listening: return .red
        case .thinking:  return Color.accentColor.opacity(0.7)
        }
    }
}
