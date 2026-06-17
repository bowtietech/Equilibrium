import SwiftUI

// MARK: - AIAssistantOverlay
//
// Floating mic button + listening/thinking feedback overlaid on ContentView.
// Tap once to start listening; tap again (or speech ends) to process.

struct AIAssistantOverlay: View {
    @EnvironmentObject private var store:     DataStore
    @StateObject private var speech           = SpeechManager()
    @StateObject private var assistant        = AIGoalAssistant()

    @State private var phase: Phase = .idle

    private enum Phase { case idle, listening, thinking }

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
                                .scaleEffect(phase == .listening ? 1 : 0.6)
                                .animation(
                                    .easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.3),
                                    value: phase == .listening
                                )
                        }
                    }

                    // Mic button
                    Button {
                        handleTap()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(buttonColor)
                                .frame(width: 52, height: 52)
                                .shadow(color: buttonColor.opacity(0.45), radius: 12, x: 0, y: 4)

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
                    }
                    .disabled(phase == .thinking)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 110)    // sit above the balance score card
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
            speech.onFinalTranscript = { [weak assistant] text in
                Task { @MainActor in
                    await assistant?.process(transcript: text, store: self.store)
                }
            }
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
}
