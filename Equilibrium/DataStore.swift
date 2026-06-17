import Combine
import Foundation

// MARK: - DataStore
// Single source of truth for all mutable goal data.
// Loads from UserDefaults on first launch (seeding with demo data),
// then auto-saves via a Combine debounce whenever either array changes.

final class DataStore: ObservableObject {

    @Published var goals: [Goal]
    @Published var lifeGoals: [LifeGoal]

    private var cancellables = Set<AnyCancellable>()

    private static let goalsKey     = "eq_goals_v1"
    private static let lifeGoalsKey = "eq_life_goals_v1"

    init() {
        goals     = Self.load(key: Self.goalsKey,     fallback: Goal.demos)
        lifeGoals = Self.load(key: Self.lifeGoalsKey, fallback: LifeGoal.demos)
        setupAutoSave()
    }

    // MARK: - Auto-save

    private func setupAutoSave() {
        $goals
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { Self.persist($0, key: Self.goalsKey) }
            .store(in: &cancellables)

        $lifeGoals
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { Self.persist($0, key: Self.lifeGoalsKey) }
            .store(in: &cancellables)
    }

    // MARK: - UserDefaults helpers

    private static func load<T: Decodable>(key: String, fallback: T) -> T {
        guard
            let data  = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode(T.self, from: data)
        else { return fallback }
        return value
    }

    private static func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Manual save (call before app goes to background, if needed)

    func saveNow() {
        Self.persist(goals,     key: Self.goalsKey)
        Self.persist(lifeGoals, key: Self.lifeGoalsKey)
    }

    // MARK: - Reset to demos (useful for testing / "reset data" in settings)

    func resetToDefaults() {
        goals     = Goal.demos
        lifeGoals = LifeGoal.demos
    }
}
