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

    enum QueryKind {
        case quantitySum(HKQuantityTypeIdentifier, HKUnit)       // cumulative types (steps, calories…)
        case quantityAverage(HKQuantityTypeIdentifier, HKUnit)   // discrete types (heart rate…)
        case sleep          // HKCategoryTypeIdentifier.sleepAnalysis → hours
        case mindful        // HKCategoryTypeIdentifier.mindfulSession → minutes
    }

    static let all: [HealthMetricTemplate] = [
        // Fitness
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.stepCount.rawValue,
            name:          "Daily Steps",
            icon:          "figure.walk",
            colorData:     .teal,
            defaultTarget: 10_000,
            unitLabel:     "steps",
            category:      "Fitness",
            queryKind:     .quantitySum(.stepCount, .count())
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            name:          "Active Calories",
            icon:          "flame.fill",
            colorData:     .orange,
            defaultTarget: 500,
            unitLabel:     "kcal",
            category:      "Fitness",
            queryKind:     .quantitySum(.activeEnergyBurned, .kilocalorie())
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
            name:          "Exercise Time",
            icon:          "figure.run",
            colorData:     .green,
            defaultTarget: 30,
            unitLabel:     "min",
            category:      "Fitness",
            queryKind:     .quantitySum(.appleExerciseTime, .minute())
        ),
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            name:          "Distance",
            icon:          "map",
            colorData:     .cyan,
            defaultTarget: 5,
            unitLabel:     "km",
            category:      "Fitness",
            queryKind:     .quantitySum(.distanceWalkingRunning, .meterUnit(with: .kilo))
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
            queryKind:     .sleep
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
            queryKind:     .mindful
        ),
        // Body
        HealthMetricTemplate(
            id:            HKQuantityTypeIdentifier.restingHeartRate.rawValue,
            name:          "Resting Heart Rate",
            icon:          "heart.fill",
            colorData:     .rose,
            defaultTarget: 60,
            unitLabel:     "bpm",
            category:      "Body",
            queryKind:     .quantityAverage(.restingHeartRate, .count().unitDivided(by: .minute()))
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

    // MARK: - Refresh goal progress

    func refresh(goals: [Goal]) async {
        var updated: [UUID: Double] = [:]
        for goal in goals {
            guard
                let identifier = goal.healthKitIdentifier,
                let target     = goal.healthKitTarget, target > 0,
                let template   = HealthMetricTemplate.find(identifier: identifier)
            else { continue }

            let value = await todayValue(for: template)
            updated[goal.id] = min(value / target, 1.0)
        }
        progressById = updated
    }

    // MARK: - Today snapshot for a single template (used in HealthImportView)

    func todayValue(for template: HealthMetricTemplate) async -> Double {
        guard isAvailable else { return 0 }
        switch template.queryKind {
        case .quantitySum(let id, let unit):
            return await sumToday(identifier: id, unit: unit)
        case .quantityAverage(let id, let unit):
            return await averageToday(identifier: id, unit: unit)
        case .sleep:
            return await sleepHoursLastNight()
        case .mindful:
            return await mindfulMinutesToday()
        }
    }

    // MARK: - Query helpers

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
