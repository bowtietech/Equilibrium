import SwiftUI

@main
struct EquilibriumApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var auth  = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(auth)
        }
    }
}

// MARK: - RootView

struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Group {
            if auth.isLoading {
                splashView
            } else if auth.isAuthenticated {
                ContentView()
            } else {
                AuthView()
            }
        }
        // When the user signs in (or session is restored), pull their cloud data
        .onChange(of: auth.session?.user.id) { _, userId in
            store.setUser(userId)
        }
    }

    private var splashView: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("equilibrium")
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                ProgressView()
                    .tint(.white.opacity(0.25))
            }
        }
        .preferredColorScheme(.dark)
    }
}
