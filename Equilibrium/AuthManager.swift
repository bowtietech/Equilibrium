import SwiftUI
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true

    var isAuthenticated: Bool { session != nil }
    var userId: UUID?         { session?.user.id }
    var userEmail: String?    { session?.user.email }

    init() {
        Task { await start() }
    }

    // MARK: - Lifecycle

    private func start() async {
        // Restore persisted session (Supabase stores it in the keychain automatically)
        session = try? await supabase.auth.session
        isLoading = false

        // Keep in sync with any future auth state changes
        for await (_, newSession) in supabase.auth.authStateChanges {
            session = newSession
        }
    }

    // MARK: - Auth actions

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    /// Returns `true` when the account was created but still needs email confirmation.
    /// Returns `false` when the user is signed in immediately (confirmation disabled).
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

    // MARK: - Deep link handling (email confirmation / OAuth callbacks)

    func handle(url: URL) async {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // PKCE flow: ?code=XXX
        if let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value {
            try? await supabase.auth.exchangeCodeForSession(authCode: code)
            return
        }

        // Implicit flow: #access_token=XXX&refresh_token=YYY
        if let fragment = comps?.fragment {
            let params = fragment
                .split(separator: "&")
                .reduce(into: [String: String]()) { dict, pair in
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    if kv.count == 2 {
                        dict[String(kv[0])] = String(kv[1])
                            .removingPercentEncoding ?? String(kv[1])
                    }
                }
            if let at = params["access_token"], let rt = params["refresh_token"] {
                try? await supabase.auth.setSession(accessToken: at, refreshToken: rt)
            }
        }
    }
}
