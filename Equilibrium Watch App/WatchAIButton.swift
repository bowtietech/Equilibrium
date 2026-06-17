import SwiftUI
import WatchConnectivity

// MARK: - WatchAIButton
//
// Mic button for the watch. Opens a system text input sheet where the user
// can dictate a command using watchOS's built-in dictation, then relays the
// transcript to the paired iPhone for AI processing via WCSession.

struct WatchAIButton: View {
    @EnvironmentObject private var watchStore: WatchDataStore

    @State private var showingInput = false
    @State private var inputText    = ""
    @State private var statusText: String? = nil
    @State private var isSending    = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Mic button — bottom-left corner
            VStack {
                Spacer()
                HStack {
                    Button {
                        inputText    = ""
                        showingInput = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.primary.opacity(isSending ? 0.25 : 0.40))
                                .frame(width: 34, height: 34)

                            if isSending {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .padding(.bottom, 6)
                    Spacer()
                }
            }

            // Status (sent / error)
            if let text = statusText {
                VStack {
                    Spacer()
                    Text(text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appSurface.opacity(0.9),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 44)
                        .frame(maxWidth: .infinity)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: statusText)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSending)
        // Dictation sheet — system keyboard with mic button appears automatically on watch
        .sheet(isPresented: $showingInput) {
            DictationInputView(text: $inputText) { confirmed in
                showingInput = false
                if confirmed, !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Task { await send(inputText) }
                }
            }
        }
    }

    // MARK: - Send to phone

    private func send(_ transcript: String) async {
        isSending = true
        let ok = watchStore.sendTranscript(transcript)
        isSending = false
        withAnimation {
            statusText = ok ? "Sent to iPhone…" : "iPhone not reachable"
        }
        try? await Task.sleep(for: .seconds(3))
        withAnimation { statusText = nil }
    }
}

// MARK: - Dictation input sheet

private struct DictationInputView: View {
    @Binding var text: String
    var onDone: (Bool) -> Void

    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("What would you like to do?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // watchOS shows a mic button in the keyboard by default
                TextField("Speak or type…", text: $text, axis: .vertical)
                    .focused($focused)
                    .lineLimit(4)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button("Cancel") { onDone(false) }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                    Button("Send") { onDone(true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .padding()
            .onAppear { focused = true }
        }
    }
}
