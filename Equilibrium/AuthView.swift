import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var isSignUp      = false
    @State private var email         = ""
    @State private var password      = ""
    @State private var isLoading     = false
    @State private var errorMessage: String?

    @FocusState private var focused: Field?
    private enum Field { case email, password }

    private let accent = Color(red: 0.58, green: 0.40, blue: 0.96)

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.16), .clear],
                center: .top, startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {
                    Spacer().frame(height: 70)

                    // App identity
                    VStack(spacing: 8) {
                        Text("equilibrium")
                            .font(.system(size: 30, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.88))
                        Text("track your balance")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    // Sign in / Create account toggle
                    HStack(spacing: 2) {
                        modeTab("Sign In",        selected: !isSignUp) { isSignUp = false }
                        modeTab("Create Account", selected:  isSignUp) { isSignUp = true  }
                    }
                    .padding(3)
                    .background(.white.opacity(0.06))
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)

                    // Form fields + CTA
                    VStack(spacing: 12) {
                        inputField(
                            icon: "envelope",
                            placeholder: "Email address",
                            text: $email,
                            field: .email,
                            isSecure: false
                        )
                        inputField(
                            icon: "lock",
                            placeholder: "Password",
                            text: $password,
                            field: .password,
                            isSecure: true
                        )

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.red.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        ctaButton
                    }
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.3), value: errorMessage)

                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.3), value: isSignUp)
    }

    // MARK: - Subviews

    private func modeTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : .white.opacity(0.4))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(selected ? .white.opacity(0.12) : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isSecure: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.32))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .focused($focused, equals: field)
                    .submitLabel(.done)
                    .onSubmit { Task { await submit() } }
            } else {
                TextField(placeholder, text: text)
                    .focused($focused, equals: field)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(accent.opacity(focused == field ? 0.5 : 0), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: focused == field)
    }

    private var ctaButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accent)
                    .frame(height: 52)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
        .opacity(isLoading || email.isEmpty || password.isEmpty ? 0.55 : 1)
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    // MARK: - Action

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        focused = nil

        do {
            if isSignUp {
                try await auth.signUp(email: trimmedEmail, password: password)
            } else {
                try await auth.signIn(email: trimmedEmail, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
