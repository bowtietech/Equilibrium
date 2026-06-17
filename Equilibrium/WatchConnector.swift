import Foundation
import WatchConnectivity
import Combine

// MARK: - WatchConnector (iOS side)
//
// Monitors DataStore changes and pushes goal data to the paired Apple Watch
// using WCSession.updateApplicationContext (background, persistent) and
// WCSession.sendMessage (immediate when watch is reachable).

@MainActor
final class WatchConnector: NSObject, ObservableObject {

    static let shared = WatchConnector()

    private var store: DataStore?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Wire up to DataStore

    func connect(to store: DataStore) {
        guard self.store == nil else { return }
        self.store = store

        // Send immediately in case the watch is already active
        sendGoals(from: store)

        // Re-send whenever goals or life goals change
        store.$goals
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let s = self.store else { return }
                self.sendGoals(from: s)
            }
            .store(in: &cancellables)

        store.$lifeGoals
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let s = self.store else { return }
                self.sendGoals(from: s)
            }
            .store(in: &cancellables)
    }

    // MARK: - Send

    private func sendGoals(from store: DataStore) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }

        let encoder = JSONEncoder()
        guard let goalsData     = try? encoder.encode(store.goals),
              let lifeGoalsData = try? encoder.encode(store.lifeGoals)
        else { return }

        let payload: [String: Any] = [
            "goals":     goalsData,
            "lifeGoals": lifeGoalsData
        ]

        // updateApplicationContext persists and delivers even when watch is asleep
        try? WCSession.default.updateApplicationContext(payload)

        // Also send via sendMessage if the watch face is active right now
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        }
    }
}

// MARK: - WCSessionDelegate (iOS)

extension WatchConnector: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        guard state == .activated else { return }
        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return }
            self.sendGoals(from: store)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
