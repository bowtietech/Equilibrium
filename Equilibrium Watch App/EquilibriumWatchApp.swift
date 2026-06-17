import SwiftUI

@main
struct EquilibriumWatchApp: App {
    @StateObject private var watchStore = WatchDataStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(watchStore)
        }
    }
}
