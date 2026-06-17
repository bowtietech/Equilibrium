import SwiftUI

@main
struct EquilibriumApp: App {
    @StateObject private var store  = DataStore()
    @StateObject private var auth   = AuthManager()
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(auth)
                .environmentObject(health)
        }
    }
}

// MARK: - RootView

struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var auth: AuthManager

    @AppStorage("app_theme") private var themeRaw: String = AppTheme.system.rawValue
    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        Group {
            if auth.isLoading {
                splashView
            } else if auth.isAuthenticated {
                if store.needsOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .animation(.easeInOut(duration: 0.35), value: store.needsOnboarding)
        // When the user signs in (or session is restored), pull their cloud data
        .onChange(of: auth.session?.user.id) { _, userId in
            store.setUser(userId)
        }
        // Handle email confirmation / OAuth deep links (equilibrium://auth-callback)
        .onOpenURL { url in
            Task { await auth.handle(url: url) }
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
    }
}
