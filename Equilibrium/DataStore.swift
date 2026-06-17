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

// MARK: - DataStore

final class DataStore: ObservableObject {

    @Published var goals: [Goal]
    @Published var lifeGoals: [LifeGoal]
    @Published var needsOnboarding: Bool

    private var userId: UUID?
    private var cancellables = Set<AnyCancellable>()

    private static let goalsKey        = "eq_goals_v1"
    private static let lifeGoalsKey    = "eq_life_goals_v1"
    private static let onboardedKey    = "eq_onboarded_v1"

    init() {
        let stored  = Self.loadLocal(key: Self.goalsKey,     fallback: [Goal]())
        let storedL = Self.loadLocal(key: Self.lifeGoalsKey, fallback: [LifeGoal]())
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

        setupAutoSave()
    }

    // MARK: - Onboarding

    /// Called when the user finishes the onboarding flow.
    func completeOnboarding(goals newGoals: [Goal]) {
        goals = newGoals
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
        Self.saveLocal(goals,     key: Self.goalsKey)
        Self.saveLocal(lifeGoals, key: Self.lifeGoalsKey)
        pushToCloud()
    }

    func resetToDefaults() {
        goals     = []
        lifeGoals = []
    }
}
