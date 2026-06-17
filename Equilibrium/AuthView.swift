import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var isSignUp      = false
    @State private var email         = ""
    @State private var password      = ""
    @State private var isLoading     = false
    @State private var errorMessage: String?
    @State private var socialLoading: OAuthProvider?

    /// Non-nil when signup succeeded but needs email confirmation
    @State private var pendingEmail: String?

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

            if let pending = pendingEmail {
                confirmationView(email: pending)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity
                    ))
            } else {
                formView
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35), value: pendingEmail == nil)
        .animation(.spring(response: 0.3), value: isSignUp)
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: 36) {
                Spacer().frame(height: 70)

                VStack(spacing: 8) {
                    Text("equilibrium")
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.88))
                    Text("track your balance")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }

                HStack(spacing: 2) {
                    modeTab("Sign In",        selected: !isSignUp) { isSignUp = false }
                    modeTab("Create Account", selected:  isSignUp) { isSignUp = true  }
                }
                .padding(3)
                .background(.white.opacity(0.06))
                .clipShape(Capsule())
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    inputField(icon: "envelope", placeholder: "Email address",
                               text: $email, field: .email, isSecure: false)
                    inputField(icon: "lock", placeholder: "Password",
                               text: $password, field: .password, isSecure: true)

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

                divider
                socialButtons.padding(.horizontal, 24)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Social login

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            Text("or")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    private var socialButtons: some View {
        VStack(spacing: 10) {
            // Apple — uses the native button + Supabase id-token exchange
            SignInWithAppleButton(.signIn) { request in
                auth.prepareAppleRequest(request)
            } onCompletion: { result in
                Task {
                    do {
                        try await auth.handleAppleCompletion(result)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .cornerRadius(14)

            // Google
            oauthButton(for: .google,
                        background: .white,
                        foreground: Color(red: 0.13, green: 0.13, blue: 0.13)) {
                await signInWithOAuth(.google)
            }

            // Facebook
            oauthButton(for: .facebook,
                        background: Color(red: 0.23, green: 0.35, blue: 0.60),
                        foreground: .white) {
                await signInWithOAuth(.facebook)
            }
        }
    }

    @ViewBuilder
    private func oauthButton(
        for provider: OAuthProvider,
        background: Color,
        foreground: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(background).frame(height: 52)
                if socialLoading == provider {
                    ProgressView().tint(foreground)
                } else {
                    Text(provider.label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(foreground)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(socialLoading != nil || isLoading)
    }

    private func signInWithOAuth(_ provider: OAuthProvider) async {
        socialLoading = provider
        errorMessage = nil
        do {
            try await auth.signInWithOAuth(provider: provider)
        } catch {
            // ASWebAuthenticationSession cancellations are expected — don't show an error
            let nsErr = error as NSError
            if !(nsErr.domain == ASWebAuthenticationSessionErrorDomain
                 && nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue) {
                errorMessage = error.localizedDescription
            }
        }
        socialLoading = nil
    }

    // MARK: - Confirmation pending

    private func confirmationView(email: String) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 10) {
                Text("Check your email")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("We sent a confirmation link to")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                Text(email)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent)
            }

            Text("Open the link in the email to activate your account,\nthen come back and sign in.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button {
                    withAnimation {
                        pendingEmail = nil
                        isSignUp = false      // switch to sign-in tab
                        password = ""
                    }
                } label: {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Button {
                    withAnimation { pendingEmail = nil }
                } label: {
                    Text("Back")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Shared subviews

    private func modeTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : .white.opacity(0.4))
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(selected ? .white.opacity(0.12) : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func inputField(
        icon: String, placeholder: String,
        text: Binding<String>, field: Field, isSecure: Bool
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
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(accent.opacity(focused == field ? 0.5 : 0), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: focused == field)
    }

    private var ctaButton: some View {
        Button { Task { await submit() } } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(accent).frame(height: 52)
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

    // MARK: - Submit

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        focused = nil

        do {
            if isSignUp {
                let needsConfirmation = try await auth.signUp(email: trimmedEmail, password: password)
                if needsConfirmation {
                    pendingEmail = trimmedEmail
                }
                // If needsConfirmation == false, authStateChanges fires and RootView navigates automatically
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
    AuthView().environmentObject(AuthManager())
}
