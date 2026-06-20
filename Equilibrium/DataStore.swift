import Combine
import Foundation
import Supabase

// MARK: - Cloud row shape

private struct UserDataRow: Codable {
    let userId: UUID
    var goals: [Goal]
    var lifeGoals: [LifeGoal]

    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case goals
        case lifeGoals = "life_goals"
    }
}

// MARK: - Meditation history entry

struct MeditationEntry: Identifiable, Codable {
    var id           = UUID()
    var date: Date   = Date()
    var durationSecs: Int   // total seconds of the session
    var malaCount:    Int   // number of times the bead button was pressed
}

// MARK: - DataStore

final class DataStore: ObservableObject {

    @Published var goals: [Goal]
    @Published var lifeGoals: [LifeGoal]
    @Published var meditationHistory: [MeditationEntry]
    @Published var needsOnboarding: Bool

    private var userId: UUID?
    private var cancellables = Set<AnyCancellable>()

    private static let goalsKey            = "eq_goals_v1"
    private static let lifeGoalsKey        = "eq_life_goals_v1"
    private static let onboardedKey        = "eq_onboarded_v1"
    private static let meditationKey       = "eq_meditation_v1"

    init() {
        let stored  = Self.loadLocal(key: Self.goalsKey,       fallback: [Goal]())
        let storedL = Self.loadLocal(key: Self.lifeGoalsKey,   fallback: [LifeGoal]())
        let storedM = Self.loadLocal(key: Self.meditationKey,  fallback: [MeditationEntry]())
        meditationHistory = storedM
        goals     = stored
        lifeGoals = storedL

        let hasFlag = UserDefaults.standard.bool(forKey: Self.onboardedKey)
        if !hasFlag && !stored.isEmpty {
            // Existing user who predates onboarding — skip it automatically
            UserDefaults.standard.set(true, forKey: Self.onboardedKey)
            needsOnboarding = false
        } else {
            needsOnboarding = !hasFlag
        }

        rebalanceColors()       // fix any pre-existing color conflicts on first launch
        setupColorRebalance()   // watch for future active-set changes
        setupAutoSave()
    }

    // MARK: - Onboarding

    /// Called when the user finishes the onboarding flow.
    func completeOnboarding(goals newGoals: [Goal], lifeGoals newLifeGoals: [LifeGoal] = []) {
        goals     = newGoals
        lifeGoals = newLifeGoals
        rebalanceColors()   // assign clean palette before saving
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
        needsOnboarding = false
        saveNow()
    }

    /// Clears all user goals and re-triggers onboarding.
    func resetGoals() {
        goals     = []
        lifeGoals = []
        UserDefaults.standard.removeObject(forKey: Self.onboardedKey)
        UserDefaults.standard.removeObject(forKey: Self.goalsKey)
        UserDefaults.standard.removeObject(forKey: Self.lifeGoalsKey)
        needsOnboarding = true
        if let userId { Task { try? await supabase.from("user_data").delete().eq("user_id", value: userId).execute() } }
    }

    // MARK: - User binding (called when auth session changes)

    func setUser(_ id: UUID?) {
        userId = id
        guard let id else { return }
        Task { await pullFromCloud(userId: id) }
    }

    // MARK: - Cloud sync

    private func pullFromCloud(userId: UUID) async {
        do {
            let row: UserDataRow = try await supabase
                .from("user_data")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value

            await MainActor.run {
                if !row.goals.isEmpty     { self.goals     = row.goals }
                if !row.lifeGoals.isEmpty { self.lifeGoals = row.lifeGoals }
                self.rebalanceColors()
            }
        } catch {
            // No cloud row yet (new user) — local/demo data is used
        }
    }

    private func pushToCloud() {
        guard let userId else { return }
        let row = UserDataRow(userId: userId, goals: goals, lifeGoals: lifeGoals)
        Task {
            try? await supabase
                .from("user_data")
                .upsert(row)
                .execute()
        }
    }

    // MARK: - Color rebalancing
    //
    // Assigns palette colors round-robin to active goals in array order so
    // no two active goals ever share a color until all 12 palette entries
    // are used. Daily and life goal wheels are rebalanced independently
    // (they are never shown at the same time).
    // Triggered automatically via Combine when the active goal IDs change.

    func rebalanceColors() {
        let palette = GoalColor.palette

        var slot = 0
        for i in goals.indices where goals[i].isActive {
            let want = palette[slot % palette.count]
            if goals[i].colorData != want { goals[i].colorData = want }
            slot += 1
        }

        slot = 0
        for i in lifeGoals.indices where lifeGoals[i].isActive {
            let want = palette[slot % palette.count]
            if lifeGoals[i].colorData != want { lifeGoals[i].colorData = want }
            slot += 1
        }
    }

    private func setupColorRebalance() {
        // Only fire when the *set* of active IDs changes (not on color changes),
        // preventing the rebalance from triggering itself in a loop.
        $goals
            .map { $0.filter(\.isActive).map(\.id) }
            .removeDuplicates()
            .dropFirst()   // skip the load-time emission; rebalanceColors() is called from init
            .sink { [weak self] _ in self?.rebalanceColors() }
            .store(in: &cancellables)

        $lifeGoals
            .map { $0.filter(\.isActive).map(\.id) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.rebalanceColors() }
            .store(in: &cancellables)
    }

    // MARK: - Auto-save (local + cloud)

    private func setupAutoSave() {
        $goals
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] goals in
                Self.saveLocal(goals, key: Self.goalsKey)
                self?.pushToCloud()
            }
            .store(in: &cancellables)

        $lifeGoals
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] lifeGoals in
                Self.saveLocal(lifeGoals, key: Self.lifeGoalsKey)
                self?.pushToCloud()
            }
            .store(in: &cancellables)
    }

    // MARK: - Local persistence helpers

    private static func loadLocal<T: Decodable>(key: String, fallback: T) -> T {
        guard
            let data  = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode(T.self, from: data)
        else { return fallback }
        return value
    }

    private static func saveLocal<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Utilities

    func saveNow() {
        Self.saveLocal(goals,            key: Self.goalsKey)
        Self.saveLocal(lifeGoals,        key: Self.lifeGoalsKey)
        Self.saveLocal(meditationHistory, key: Self.meditationKey)
        pushToCloud()
    }

    /// Saves a completed meditation session and updates linked life goals.
    func saveMeditationSession(_ entry: MeditationEntry, for goal: Goal) {
        meditationHistory.append(entry)
        Self.saveLocal(meditationHistory, key: Self.meditationKey)

        let minutes = Double(entry.durationSecs) / 60.0

        // Update cumulative meditation-time life goal if linked
        if let tid = goal.meditationTimeGoalID,
           let idx = lifeGoals.firstIndex(where: { $0.id == tid }),
           case .metric(var data) = lifeGoals[idx].kind {
            data.currentValue += minutes
            let today = Calendar.current.startOfDay(for: Date())
            let lastDay = data.history.last.map { Calendar.current.startOfDay(for: $0.date) }
            if lastDay != today {
                data.history.append(MetricEntry(date: Date(), value: data.currentValue))
            }
            lifeGoals[idx].kind = .metric(data)
        }

        // Update mala-count life goal if linked (tracks average per session, lower = better)
        if let mid = goal.meditationMalaGoalID,
           let idx = lifeGoals.firstIndex(where: { $0.id == mid }),
           case .metric(var data) = lifeGoals[idx].kind {
            let allCounts = meditationHistory.map { Double($0.malaCount) }
            data.currentValue = allCounts.isEmpty ? 0 : allCounts.reduce(0,+) / Double(allCounts.count)
            let today = Calendar.current.startOfDay(for: Date())
            let lastDay = data.history.last.map { Calendar.current.startOfDay(for: $0.date) }
            if lastDay != today {
                data.history.append(MetricEntry(date: Date(), value: data.currentValue))
            }
            lifeGoals[idx].kind = .metric(data)
        }

        saveNow()
    }

    func resetToDefaults() {
        goals     = []
        lifeGoals = []
    }
}
