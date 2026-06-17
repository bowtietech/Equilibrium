import SwiftUI
import WatchConnectivity
import Combine

// MARK: - WatchDataStore
//
// Receives synced goal data from the companion iPhone via WatchConnectivity
// `updateApplicationContext`. Falls back to demo goals until the first sync arrives.

@MainActor
final class WatchDataStore: NSObject, ObservableObject {

    @Published var goals:      [Goal]      = []
    @Published var lifeGoals:  [LifeGoal]  = []
    @Published var lastSync:   Date?

    private let goalsKey     = "watch_synced_goals"
    private let lifeKey      = "watch_synced_lifeGoals"
    private let syncDateKey  = "watch_synced_date"

    override init() {
        super.init()
        loadPersisted()
        setupSession()
    }

    // MARK: - WCSession setup

    private func setupSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Persistence (so watch survives restarts without needing an immediate phone sync)

    private func loadPersisted() {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        } else {
            goals = Goal.demos
        }
        if let data = ud.data(forKey: lifeKey),
           let decoded = try? JSONDecoder().decode([LifeGoal].self, from: data) {
            lifeGoals = decoded
        } else {
            lifeGoals = LifeGoal.demos
        }
        if let date = ud.object(forKey: syncDateKey) as? Date {
            lastSync = date
        }
    }

    // MARK: - Send transcript to phone for AI processing

    /// Sends the voice transcript to the paired iPhone for AI processing.
    /// Returns true if the message was sent, false if the phone is not reachable.
    @discardableResult
    func sendTranscript(_ text: String) -> Bool {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return false }
        WCSession.default.sendMessage(["ai_transcript": text], replyHandler: nil)
        return true
    }

    private func applyContext(_ context: [String: Any]) {
        let decoder = JSONDecoder()
        if let data = context["goals"] as? Data,
           let decoded = try? decoder.decode([Goal].self, from: data) {
            goals = decoded
            UserDefaults.standard.set(data, forKey: goalsKey)
        }
        if let data = context["lifeGoals"] as? Data,
           let decoded = try? decoder.decode([LifeGoal].self, from: data) {
            lifeGoals = decoded
            UserDefaults.standard.set(data, forKey: lifeKey)
        }
        lastSync = Date()
        UserDefaults.standard.set(lastSync, forKey: syncDateKey)
    }
}

// MARK: - WCSessionDelegate

extension WatchDataStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        // Pull the last known application context on activation (handles the case
        // where the phone already sent an update before the watch woke up).
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty {
            Task { @MainActor in self.applyContext(ctx) }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.applyContext(applicationContext) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.applyContext(message) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.applyContext(userInfo) }
    }
}
