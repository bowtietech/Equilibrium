import HealthKit
import SwiftUI

// MARK: - Metric template

struct HealthMetricTemplate: Identifiable {
    let id: String          // HK type identifier raw value
    let name: String
    let icon: String
    let colorData: GoalColor
    let defaultTarget: Double
    let unitLabel: String
    let category: String
    let queryKind: QueryKind
    /// When true the goal is to get the value DOWN to the target (e.g. resting HR).
    /// Progress = min(target / value, 1.0) so being at or below target = 100%.
    let isLowerBetter: Bool
    /// Multiply the raw HK value by this before comparing to target.
    /// Use 100.0 for percent-based metrics so they express as 0–100, not 0–1.
    var valueScale: Double = 1.0

    enum QueryKind {
        case quantitySum(HKQuantityTypeIdentifier, HKUnit)       // cumulative types (steps, calories…)
        case quantityAverage(HKQuantityTypeIdentifier, HKUnit)   // discrete types (heart rate…)
        case sleep          // HKCategoryTypeIdentifier.sleepAnalysis → hours
        case mindful        // HKCategoryTypeIdentifier.mindfulSession → minutes
    }

    // MARK: - Locale helpers

    /// True when the device locale uses the metric system for mass/distance.
    private static var usesMetric: Bool { Locale.current.usesMetricSystem }

    static var massUnit:         HKUnit { usesMetric ? .gramUnit(with: .kilo) : .pound() }
    static var massUnitLabel:    String { usesMetric ? "kg" : "lbs" }
    static var massDefault:      Double { usesMetric ? 70 : 154 }     // ~70 kg ≈ 154 lbs

    static var distUnit:         HKUnit { usesMetric ? .meterUnit(with: .kilo) : .mile() }
    static var distUnitLabel:    String { usesMetric ? "km" : "mi" }
    static var distDefault:      Double { usesMetric ? 5 : 3 }        // ~5 km ≈ 3 mi

    // MARK: - Template catalog

    static var all: [HealthMetricTemplate] = [
        // Fitness
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.stepCount.rawValue,
            name:          "Daily Steps",
            icon:          "figure.walk",
            colorData:     .teal,
            defaultTarget: 10_000,
            unitLabel:     "steps",
            category:      "Fitness",
            queryKind:     .quantitySum(.stepCount, .count()),
            isLowerBetter: false
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            name:          "Active Calories",
            icon:          "flame.fill",
            colorData:     .orange,
            defaultTarget: 500,
            unitLabel:     "kcal",
            category:      "Fitness",
            queryKind:     .quantitySum(.activeEnergyBurned, .kilocalorie()),
            isLowerBetter: false
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
            name:          "Exercise Time",
            icon:          "figure.run",
            colorData:     .green,
            defaultTarget: 30,
            unitLabel:     "min",
            category:      "Fitness",
            queryKind:     .quantitySum(.appleExerciseTime, .minute()),
            isLowerBetter: false
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            name:          "Distance",
            icon:          "map",
            colorData:     .cyan,
            defaultTarget: distDefault,
            unitLabel:     distUnitLabel,
            category:      "Fitness",
            queryKind:     .quantitySum(.distanceWalkingRunning, distUnit),
            isLowerBetter: false
        ),
        // Sleep
        HealthMetricTemplate(
            id:            HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            name:          "Sleep",
            icon:          "moon.fill",
            colorData:     .indigo,
            defaultTarget: 8,
            unitLabel:     "hrs",
            category:      "Sleep",
            queryKind:     .sleep,
            isLowerBetter: false
        ),
        // Mindfulness
        HealthMetricTemplate(
            id:            HKCategoryTypeIdentifier.mindfulSession.rawValue,
            name:          "Mindfulness",
            icon:          "brain.head.profile",
            colorData:     .purple,
            defaultTarget: 10,
            unitLabel:     "min",
            category:      "Mindfulness",
            queryKind:     .mindful,
            isLowerBetter: false
        ),
        // Body — lower is better; user must set their own target
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.restingHeartRate.rawValue,
            name:          "Resting Heart Rate",
            icon:          "heart.fill",
            colorData:     .rose,
            defaultTarget: 60,
            unitLabel:     "bpm",
            category:      "Body",
            queryKind:     .quantityAverage(.restingHeartRate, .count().unitDivided(by: .minute())),
            isLowerBetter: true
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.bodyMass.rawValue,
            name:          "Body Weight",
            icon:          "scalemass.fill",
            colorData:     .blue,
            defaultTarget: massDefault,
            unitLabel:     massUnitLabel,
            category:      "Body",
            queryKind:     .quantityAverage(.bodyMass, massUnit),
            isLowerBetter: true
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.bodyFatPercentage.rawValue,
            name:          "Body Fat",
            icon:          "figure.arms.open",
            colorData:     .amber,
            defaultTarget: 20,        // user enters 20 meaning 20%
            unitLabel:     "%",
            category:      "Body",
            queryKind:     .quantityAverage(.bodyFatPercentage, .percent()),
            isLowerBetter: true,
            valueScale:    100        // HK returns 0–1; multiply to get 0–100
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.bodyMassIndex.rawValue,
            name:          "BMI",
            icon:          "person.fill",
            colorData:     .violet,
            defaultTarget: 22,
            unitLabel:     "",
            category:      "Body",
            queryKind:     .quantityAverage(.bodyMassIndex, .count()),
            isLowerBetter: true
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue,
            name:          "Heart Rate Variability",
            icon:          "waveform.path.ecg",
            colorData:     .pink,
            defaultTarget: 50,
            unitLabel:     "ms",
            category:      "Body",
            queryKind:     .quantityAverage(.heartRateVariabilitySDNN,
                                            .secondUnit(with: .milli)),
            isLowerBetter: false
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.oxygenSaturation.rawValue,
            name:          "Blood Oxygen",
            icon:          "lungs.fill",
            colorData:     .cyan,
            defaultTarget: 98,        // user enters 98 meaning 98%
            unitLabel:     "%",
            category:      "Body",
            queryKind:     .quantityAverage(.oxygenSaturation, .percent()),
            isLowerBetter: false,
            valueScale:    100
        ),
        // Activity
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.flightsClimbed.rawValue,
            name:          "Flights Climbed",
            icon:          "figure.stairs",
            colorData:     .teal,
            defaultTarget: 10,
            unitLabel:     "flights",
            category:      "Fitness",
            queryKind:     .quantitySum(.flightsClimbed, .count()),
            isLowerBetter: false
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.basalEnergyBurned.rawValue,
            name:          "Resting Calories",
            icon:          "flame",
            colorData:     .gold,
            defaultTarget: 1800,
            unitLabel:     "kcal",
            category:      "Fitness",
            queryKind:     .quantitySum(.basalEnergyBurned, .kilocalorie()),
            isLowerBetter: false
        ),
        // Nutrition
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.dietaryWater.rawValue,
            name:          "Water",
            icon:          "drop.fill",
            colorData:     .blue,
            defaultTarget: 2.5,
            unitLabel:     "L",
            category:      "Nutrition",
            queryKind:     .quantitySum(.dietaryWater, .literUnit(with: .none)),
            isLowerBetter: false
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue,
            name:          "Calories Consumed",
            icon:          "fork.knife",
            colorData:     .green,
            defaultTarget: 2000,
            unitLabel:     "kcal",
            category:      "Nutrition",
            queryKind:     .quantitySum(.dietaryEnergyConsumed, .kilocalorie()),
            isLowerBetter: false
        ),
    ]

    static func find(identifier: String) -> HealthMetricTemplate? {
        all.first { $0.id == identifier }
    }
}

// MARK: - HealthKitManager

@MainActor
final class HealthKitManager: ObservableObject {

    @Published var isAuthorized  = false
    @Published var progressById: [UUID: Double] = [:]   // goal.id → 0…1

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        var readTypes = Set<HKObjectType>()
        for t in HealthMetricTemplate.all {
            switch t.queryKind {
            case .quantitySum(let id, _), .quantityAverage(let id, _):
                if let qt = HKQuantityType.quantityType(forIdentifier: id) { readTypes.insert(qt) }
            case .sleep:
                if let ct = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(ct) }
            case .mindful:
                if let ct = HKObjectType.categoryType(forIdentifier: .mindfulSession) { readTypes.insert(ct) }
            }
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Re-authorize + refresh (called from settings)

    /// Re-requests authorization for all known templates (picks up newly added metric types
    /// or third-party sources like smart scales) then refreshes goal progress.
    func syncAll(goals: [Goal]) async {
        await requestAuthorization()
        await refresh(goals: goals)
    }

    // MARK: - Life goal refresh

    /// Returns a map of life-goal ID → latest HK value for all health-linked life goals.
    /// Call this and then apply the results to `store.lifeGoals` on the main actor.
    func latestLifeGoalValues(for lifeGoals: [LifeGoal]) async -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for goal in lifeGoals {
            guard
                let identifier = goal.healthKitIdentifier,
                let template   = HealthMetricTemplate.find(identifier: identifier)
            else { continue }
            let value = await latestValue(for: template)
            if value > 0 { result[goal.id] = value }
        }
        return result
    }

    /// Fetches the most recent HealthKit value for a template (looks back
    /// further than today for body metrics like weight/BMI that aren't measured daily).
    func latestValue(for template: HealthMetricTemplate) async -> Double {
        guard isAvailable else { return 0 }
        let raw: Double
        switch template.queryKind {
        case .quantitySum(let id, let unit):
            raw = await sumToday(identifier: id, unit: unit)
        case .quantityAverage(let id, let unit):
            raw = await latestSample(identifier: id, unit: unit)
        case .sleep:
            raw = await sleepHoursLastNight()
        case .mindful:
            raw = await mindfulMinutesToday()
        }
        return raw * template.valueScale
    }

    // MARK: - Refresh goal progress

    func refresh(goals: [Goal]) async {
        var updated: [UUID: Double] = [:]
        for goal in goals where goal.isActive {
            guard
                let identifier = goal.healthKitIdentifier,
                let target     = goal.healthKitTarget, target > 0,
                let template   = HealthMetricTemplate.find(identifier: identifier)
            else { continue }

            let value = await todayValue(for: template)
            guard value > 0 else { updated[goal.id] = 0; continue }

            if template.isLowerBetter {
                // Goal is to reach (or go below) the target value.
                // value <= target → complete (1.0); value > target → partial.
                updated[goal.id] = min(target / value, 1.0)
            } else {
                updated[goal.id] = min(value / target, 1.0)
            }
        }
        progressById = updated
    }

    // MARK: - Today snapshot for a single template (used in HealthImportView)

    func todayValue(for template: HealthMetricTemplate) async -> Double {
        guard isAvailable else { return 0 }
        let raw: Double
        switch template.queryKind {
        case .quantitySum(let id, let unit):
            raw = await sumToday(identifier: id, unit: unit)
        case .quantityAverage(let id, let unit):
            raw = await averageToday(identifier: id, unit: unit)
        case .sleep:
            raw = await sleepHoursLastNight()
        case .mindful:
            raw = await mindfulMinutesToday()
        }
        return raw * template.valueScale
    }

    // MARK: - Query helpers

    /// Fetches the single most-recent sample regardless of date (for long-term metrics
    /// like body weight / BMI that aren't recorded every day).
    private func latestSample(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let s = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0); return
                }
                continuation.resume(returning: s.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func averageToday(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func sumToday(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func sleepHoursLastNight() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .hour, value: -18, to: today) ?? today
        let end   = cal.date(byAdding: .hour, value: 14, to: today) ?? today
        let pred  = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: pred,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let asleep: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let seconds = (samples as? [HKCategorySample])?
                    .filter { asleep.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                continuation.resume(returning: seconds / 3600)
            }
            store.execute(query)
        }
    }

    private func mindfulMinutesToday() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let pred  = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: pred,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let seconds = (samples as? [HKCategorySample])?
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                continuation.resume(returning: seconds / 60)
            }
            store.execute(query)
        }
    }
}
