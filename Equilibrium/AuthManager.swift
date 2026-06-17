import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit

// MARK: - AuthManager

@MainActor
final class AuthManager: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true

    var isAuthenticated: Bool { session != nil }
    var userId: UUID?         { session?.user.id }
    var userEmail: String?    { session?.user.email }

    // Nonce used for the current Sign in with Apple request
    private var pendingNonce: (raw: String, hashed: String)?

    init() {
        Task { await start() }
    }

    // MARK: - Lifecycle

    private func start() async {
        session = try? await supabase.auth.session
        isLoading = false
        for await (_, newSession) in supabase.auth.authStateChanges {
            session = newSession
        }
    }

    // MARK: - Email / password

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    /// Returns `true` when email confirmation is still required.
    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            redirectTo: URL(string: "equilibrium://auth-callback")
        )
        return response.session == nil
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Sign in with Apple

    /// Call this from the `SignInWithAppleButton` request handler to set up the nonce.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = makeNonce()
        pendingNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce.hashed
    }

    /// Call this from the `SignInWithAppleButton` completion handler.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData   = credential.identityToken,
                let idToken     = String(data: tokenData, encoding: .utf8),
                let nonce       = pendingNonce
            else { return }

            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce.raw)
            )
            pendingNonce = nil
        }
    }

    // MARK: - OAuth (Google / Facebook)
    // supabase-swift v2 handles ASWebAuthenticationSession internally and returns the Session.

    func signInWithOAuth(provider: OAuthProvider) async throws {
        try await supabase.auth.signInWithOAuth(
            provider: provider.supabaseProvider,
            redirectTo: URL(string: "equilibrium://auth-callback")!
        )
    }

    // MARK: - Deep link handler (email confirmation / OAuth callbacks)

    func handle(url: URL) async {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // PKCE: ?code=XXX
        if let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value {
            try? await supabase.auth.exchangeCodeForSession(authCode: code)
            return
        }

        // Implicit: #access_token=XXX&refresh_token=YYY
        if let fragment = comps?.fragment {
            let params = fragment
                .split(separator: "&")
                .reduce(into: [String: String]()) { d, pair in
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    if kv.count == 2 { d[String(kv[0])] = String(kv[1]) }
                }
            if let at = params["access_token"], let rt = params["refresh_token"] {
                try? await supabase.auth.setSession(accessToken: at, refreshToken: rt)
            }
        }
    }

    // MARK: - Nonce helpers

    private func makeNonce() -> (raw: String, hashed: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let raw = bytes.map { String(format: "%02x", $0) }.joined()
        let hashed = SHA256.hash(data: Data(raw.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return (raw, hashed)
    }
}

// MARK: - OAuthProvider

enum OAuthProvider {
    case google, facebook

    var supabaseProvider: Provider {
        switch self {
        case .google:   return .google
        case .facebook: return .facebook
        }
    }

    var label: String {
        switch self {
        case .google:   return "Continue with Google"
        case .facebook: return "Continue with Facebook"
        }
    }
}
