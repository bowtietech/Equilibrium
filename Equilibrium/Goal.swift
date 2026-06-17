import SwiftUI

// MARK: - GoalColor
// Stores color as plain Doubles — Codable without UIKit, works on iOS + watchOS.

struct GoalColor: Codable, Equatable {
    var r, g, b: Double
    var value: Color { Color(red: r, green: g, blue: b) }

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    // Shared palette
    static let purple = GoalColor(0.58, 0.40, 0.96)
    static let orange = GoalColor(1.00, 0.55, 0.10)
    static let indigo = GoalColor(0.30, 0.45, 0.95)
    static let green  = GoalColor(0.18, 0.78, 0.42)
    static let cyan   = GoalColor(0.15, 0.82, 0.94)
    static let pink   = GoalColor(1.00, 0.32, 0.55)
    static let blue   = GoalColor(0.28, 0.56, 1.00)
    static let teal   = GoalColor(0.12, 0.86, 0.78)
    static let gold   = GoalColor(0.98, 0.78, 0.12)
    static let amber  = GoalColor(1.00, 0.52, 0.18)
    static let violet = GoalColor(0.75, 0.30, 0.95)
    static let rose   = GoalColor(0.95, 0.25, 0.60)
}

// MARK: - Wheel Display Entry (shared by Daily and Life modes, view-model only)

struct WheelEntry: Identifiable {
    var id: UUID
    var name: String
    var color: Color
    var icon: String
    var progress: Double
}

// MARK: - Schedule

enum GoalSchedule: Equatable, Codable {
    case daily
    case weekdays([Int])   // Calendar weekday: 1=Sun 2=Mon … 7=Sat
    case monthly(Int)      // day-of-month 1–31
    case once(Date)        // specific calendar date

    // MARK: Codable (associated values require manual impl)

    private enum CK: String, CodingKey { case type, days, day, date }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        switch self {
        case .daily:
            try c.encode("daily", forKey: .type)
        case .weekdays(let days):
            try c.encode("weekdays", forKey: .type)
            try c.encode(days, forKey: .days)
        case .monthly(let day):
            try c.encode("monthly", forKey: .type)
            try c.encode(day, forKey: .day)
        case .once(let date):
            try c.encode("once", forKey: .type)
            try c.encode(date.timeIntervalSince1970, forKey: .date)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        switch try c.decode(String.self, forKey: .type) {
        case "weekdays": self = .weekdays(try c.decode([Int].self, forKey: .days))
        case "monthly":  self = .monthly(try c.decode(Int.self, forKey: .day))
        case "once":
            self = .once(Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .date)))
        default:         self = .daily
        }
    }

    // MARK: Helpers

    var isActiveToday: Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .daily:              return true
        case .weekdays(let days): return days.contains(cal.component(.weekday, from: now))
        case .monthly(let day):   return cal.component(.day, from: now) == day
        case .once(let date):     return cal.isDate(date, inSameDayAs: now)
        }
    }

    var label: String {
        switch self {
        case .daily:
            return "Every day"
        case .weekdays(let days):
            let abbrev = ["S", "M", "T", "W", "T", "F", "S"]
            return days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? abbrev[$0 - 1] : nil }.joined(separator: "·")
        case .monthly(let day):
            return "Monthly · \(day)\(daySuffix(day))"
        case .once(let date):
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return f.string(from: date)
        }
    }

    private func daySuffix(_ n: Int) -> String {
        switch n {
        case 11, 12, 13:            return "th"
        case _ where n % 10 == 1:   return "st"
        case _ where n % 10 == 2:   return "nd"
        case _ where n % 10 == 3:   return "rd"
        default:                     return "th"
        }
    }
}

// MARK: - GoalItem

struct GoalItem: Identifiable, Codable, Equatable {
    var id       = UUID()
    var name: String
    var isComplete: Bool       = false
    var schedule: GoalSchedule = .daily

    var isActiveToday: Bool { schedule.isActiveToday }
}

// MARK: - Goal

struct Goal: Identifiable, Codable, Equatable {
    var id        = UUID()
    var name: String
    var colorData: GoalColor
    var icon: String
    var items: [GoalItem]
    /// When false the goal is hidden from the wheel and excluded from totals,
    /// but all data is preserved so it can be reactivated later.
    var isActive: Bool = true

    // HealthKit backing — when set, progress comes from HK not items
    var healthKitIdentifier: String?
    var healthKitTarget: Double?
    var healthKitUnit: String?

    var isHealthBacked: Bool { healthKitIdentifier != nil }

    // Computed — excluded from Codable automatically
    var color: Color { colorData.value }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isComplete).count) / Double(items.count)
    }

    var todayProgress: Double? {
        let today = items.filter(\.isActiveToday)
        guard !today.isEmpty else { return nil }
        return Double(today.filter(\.isComplete).count) / Double(today.count)
    }

    /// Returns a WheelEntry, optionally overriding progress with a live HealthKit value.
    func wheelEntry(healthProgress: Double? = nil) -> WheelEntry {
        let p = healthProgress ?? todayProgress ?? progress
        return WheelEntry(id: id, name: name, color: color, icon: icon, progress: p)
    }

    // Legacy convenience kept for non-HK callers
    var wheelEntry: WheelEntry { wheelEntry() }
}

// MARK: - Backward-compatible Codable for Goal

extension Goal {
    enum CodingKeys: String, CodingKey {
        case id, name, colorData, icon, items, isActive
        case healthKitIdentifier, healthKitTarget, healthKitUnit
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,       forKey: .id)
        name      = try c.decode(String.self,     forKey: .name)
        colorData = try c.decode(GoalColor.self,  forKey: .colorData)
        icon      = try c.decode(String.self,     forKey: .icon)
        items     = try c.decode([GoalItem].self, forKey: .items)
        isActive  = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        healthKitIdentifier = try c.decodeIfPresent(String.self, forKey: .healthKitIdentifier)
        healthKitTarget     = try c.decodeIfPresent(Double.self, forKey: .healthKitTarget)
        healthKitUnit       = try c.decodeIfPresent(String.self, forKey: .healthKitUnit)
    }
}

// MARK: - Balance Score

extension [Goal] {
    var balanceScore: Double {
        let scores = compactMap(\.todayProgress)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
}

// MARK: - Demo Data

extension Goal {
    static var demos: [Goal] {
        let cal     = Calendar.current
        let setA: [Int] = [2, 4, 6]   // Mon / Wed / Fri
        let setB: [Int] = [3, 5]      // Tue / Thu
        let weekend: [Int] = [1, 7]   // Sat / Sun
        _ = cal

        return [
            Goal(
                name: "Mindfulness", colorData: .purple, icon: "brain.head.profile",
                items: [
                    GoalItem(name: "Meditate 10 minutes",   isComplete: true,  schedule: .daily),
                    GoalItem(name: "Morning journal entry",  isComplete: true,  schedule: .daily),
                    GoalItem(name: "Breathwork session",     isComplete: true,  schedule: .weekdays(setA)),
                    GoalItem(name: "Digital detox 1 hour",   isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Exercise", colorData: .orange, icon: "figure.run",
                items: [
                    GoalItem(name: "Morning run",        isComplete: false, schedule: .weekdays(setA)),
                    GoalItem(name: "Strength training",   isComplete: true,  schedule: .weekdays(setB)),
                    GoalItem(name: "Evening walk",        isComplete: false, schedule: .daily),
                    GoalItem(name: "Stretch & mobility",  isComplete: false, schedule: .daily),
                    GoalItem(name: "Active recovery",     isComplete: false, schedule: .weekdays(weekend)),
                ]
            ),
            Goal(
                name: "Sleep", colorData: .indigo, icon: "moon.zzz",
                items: [
                    GoalItem(name: "In bed by 10 PM",       isComplete: true,  schedule: .daily),
                    GoalItem(name: "No screens after 9 PM", isComplete: true,  schedule: .daily),
                    GoalItem(name: "8 hours of sleep",      isComplete: true,  schedule: .daily),
                    GoalItem(name: "Consistent wake time",  isComplete: false, schedule: .daily),
                    GoalItem(name: "Room temp 67°F",        isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Nutrition", colorData: .green, icon: "leaf",
                items: [
                    GoalItem(name: "5 servings of veg",      isComplete: true,  schedule: .daily),
                    GoalItem(name: "No processed sugar",      isComplete: true,  schedule: .daily),
                    GoalItem(name: "Protein every meal",      isComplete: true,  schedule: .daily),
                    GoalItem(name: "Cook at home",            isComplete: true,  schedule: .weekdays(setA + setB)),
                    GoalItem(name: "No late-night snacking",  isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Hydration", colorData: .cyan, icon: "drop",
                items: [
                    GoalItem(name: "Morning glass of water",        isComplete: true,  schedule: .daily),
                    GoalItem(name: "Drink 64 oz total",              isComplete: false, schedule: .daily),
                    GoalItem(name: "Herbal tea instead of coffee",   isComplete: false, schedule: .weekdays(setA)),
                    GoalItem(name: "No alcohol today",               isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Social", colorData: .pink, icon: "person.2",
                items: [
                    GoalItem(name: "Call a friend",       isComplete: true,  schedule: .weekdays(setA)),
                    GoalItem(name: "Family dinner",        isComplete: false, schedule: .weekdays(weekend)),
                    GoalItem(name: "Compliment someone",   isComplete: true,  schedule: .daily),
                    GoalItem(name: "Volunteer 1 hour",     isComplete: false, schedule: .once(nextSaturday())),
                    GoalItem(name: "Phone away at meals",  isComplete: false, schedule: .daily),
                ]
            ),
        ]
    }

    private static func nextSaturday() -> Date {
        var comps = DateComponents(); comps.weekday = 7
        return Calendar.current.nextDate(after: Date(), matching: comps,
                                         matchingPolicy: .nextTime) ?? Date()
    }
}
