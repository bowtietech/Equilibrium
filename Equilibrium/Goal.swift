import SwiftUI

// MARK: - Schedule

enum GoalSchedule: Equatable {
    case daily
    case weekdays([Int])  // Calendar weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
    case monthly(Int)     // day-of-month 1–31
    case once(Date)       // a specific calendar date

    var isActiveToday: Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .daily:
            return true
        case .weekdays(let days):
            return days.contains(cal.component(.weekday, from: now))
        case .monthly(let day):
            return cal.component(.day, from: now) == day
        case .once(let date):
            return cal.isDate(date, inSameDayAs: now)
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
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: date)
        }
    }

    private func daySuffix(_ n: Int) -> String {
        switch n {
        case 11, 12, 13: return "th"
        case _ where n % 10 == 1: return "st"
        case _ where n % 10 == 2: return "nd"
        case _ where n % 10 == 3: return "rd"
        default: return "th"
        }
    }
}

// MARK: - GoalItem

struct GoalItem: Identifiable {
    var id       = UUID()
    var name: String
    var isComplete: Bool    = false
    var schedule: GoalSchedule = .daily

    var isActiveToday: Bool { schedule.isActiveToday }
}

// MARK: - Goal

struct Goal: Identifiable {
    var id   = UUID()
    var name: String
    var color: Color
    var icon: String
    var items: [GoalItem]

    /// Overall completion across all items regardless of schedule.
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isComplete).count) / Double(items.count)
    }

    /// Completion for items active today only. nil if nothing scheduled today.
    var todayProgress: Double? {
        let today = items.filter(\.isActiveToday)
        guard !today.isEmpty else { return nil }
        return Double(today.filter(\.isComplete).count) / Double(today.count)
    }
}

// MARK: - Balance Score

extension [Goal] {
    /// Average of todayProgress across goals that have items scheduled today.
    var balanceScore: Double {
        let scores = compactMap(\.todayProgress)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
}

// MARK: - Demo Data

extension Goal {
    static var demos: [Goal] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)  // 1=Sun … 7=Sat

        // Two complementary sets so at least one set is active most days
        let setA: [Int] = [2, 4, 6]   // Mon / Wed / Fri
        let setB: [Int] = [3, 5]      // Tue / Thu
        let weekend: [Int] = [1, 7]   // Sat / Sun
        _ = weekday

        return [
            Goal(
                name: "Mindfulness",
                color: Color(red: 0.58, green: 0.40, blue: 0.96),
                icon: "brain.head.profile",
                items: [
                    GoalItem(name: "Meditate 10 minutes",  isComplete: true,  schedule: .daily),
                    GoalItem(name: "Morning journal entry", isComplete: true,  schedule: .daily),
                    GoalItem(name: "Breathwork session",    isComplete: true,  schedule: .weekdays(setA)),
                    GoalItem(name: "Digital detox 1 hour",  isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Exercise",
                color: Color(red: 1.00, green: 0.55, blue: 0.10),
                icon: "figure.run",
                items: [
                    GoalItem(name: "Morning run",        isComplete: false, schedule: .weekdays(setA)),
                    GoalItem(name: "Strength training",  isComplete: true,  schedule: .weekdays(setB)),
                    GoalItem(name: "Evening walk",       isComplete: false, schedule: .daily),
                    GoalItem(name: "Stretch & mobility", isComplete: false, schedule: .daily),
                    GoalItem(name: "Active recovery",    isComplete: false, schedule: .weekdays(weekend)),
                ]
            ),
            Goal(
                name: "Sleep",
                color: Color(red: 0.30, green: 0.45, blue: 0.95),
                icon: "moon.zzz",
                items: [
                    GoalItem(name: "In bed by 10 PM",       isComplete: true,  schedule: .daily),
                    GoalItem(name: "No screens after 9 PM", isComplete: true,  schedule: .daily),
                    GoalItem(name: "8 hours of sleep",      isComplete: true,  schedule: .daily),
                    GoalItem(name: "Consistent wake time",  isComplete: false, schedule: .daily),
                    GoalItem(name: "Room temp 67°F",        isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Nutrition",
                color: Color(red: 0.18, green: 0.78, blue: 0.42),
                icon: "leaf",
                items: [
                    GoalItem(name: "5 servings of veg",     isComplete: true,  schedule: .daily),
                    GoalItem(name: "No processed sugar",    isComplete: true,  schedule: .daily),
                    GoalItem(name: "Protein every meal",    isComplete: true,  schedule: .daily),
                    GoalItem(name: "Cook at home",          isComplete: true,  schedule: .weekdays(setA + setB)),
                    GoalItem(name: "No late-night snacking",isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Hydration",
                color: Color(red: 0.15, green: 0.82, blue: 0.94),
                icon: "drop",
                items: [
                    GoalItem(name: "Morning glass of water",       isComplete: true,  schedule: .daily),
                    GoalItem(name: "Drink 64 oz total",            isComplete: false, schedule: .daily),
                    GoalItem(name: "Herbal tea instead of coffee", isComplete: false, schedule: .weekdays(setA)),
                    GoalItem(name: "No alcohol today",             isComplete: false, schedule: .daily),
                ]
            ),
            Goal(
                name: "Social",
                color: Color(red: 1.00, green: 0.32, blue: 0.55),
                icon: "person.2",
                items: [
                    GoalItem(name: "Call a friend",          isComplete: true,  schedule: .weekdays(setA)),
                    GoalItem(name: "Family dinner",          isComplete: false, schedule: .weekdays(weekend)),
                    GoalItem(name: "Compliment someone",     isComplete: true,  schedule: .daily),
                    GoalItem(name: "Volunteer 1 hour",       isComplete: false, schedule: .once(nextSaturday())),
                    GoalItem(name: "Phone away at meals",    isComplete: false, schedule: .daily),
                ]
            ),
        ]
    }

    private static func nextSaturday() -> Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = 7  // Saturday
        return cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) ?? Date()
    }
}
