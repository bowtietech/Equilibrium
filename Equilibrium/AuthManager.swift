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

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}
