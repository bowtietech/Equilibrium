import SwiftUI

struct GoalItem: Identifiable {
    var id = UUID()
    var name: String
    var isComplete: Bool = false
}

struct Goal: Identifiable {
    var id = UUID()
    var name: String
    var color: Color
    var icon: String
    var items: [GoalItem]

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isComplete).count) / Double(items.count)
    }
}

extension Goal {
    static let demos: [Goal] = [
        Goal(name: "Mindfulness", color: Color(red: 0.58, green: 0.40, blue: 0.96), icon: "brain.head.profile", items: [
            GoalItem(name: "Meditate 10 minutes",    isComplete: true),
            GoalItem(name: "Morning journal entry",  isComplete: true),
            GoalItem(name: "Breathwork session",     isComplete: true),
            GoalItem(name: "Digital detox 1 hour",   isComplete: false),
        ]),
        Goal(name: "Exercise", color: Color(red: 1.00, green: 0.55, blue: 0.10), icon: "figure.run", items: [
            GoalItem(name: "Morning run",           isComplete: false),
            GoalItem(name: "Strength training",     isComplete: true),
            GoalItem(name: "Evening walk",          isComplete: false),
            GoalItem(name: "Stretch & mobility",    isComplete: false),
            GoalItem(name: "Active recovery",       isComplete: false),
        ]),
        Goal(name: "Sleep", color: Color(red: 0.30, green: 0.45, blue: 0.95), icon: "moon.zzz", items: [
            GoalItem(name: "In bed by 10 PM",          isComplete: true),
            GoalItem(name: "No screens after 9 PM",    isComplete: true),
            GoalItem(name: "8 hours of sleep",         isComplete: true),
            GoalItem(name: "Consistent wake time",     isComplete: false),
            GoalItem(name: "Room temp 67°F",           isComplete: false),
        ]),
        Goal(name: "Nutrition", color: Color(red: 0.18, green: 0.78, blue: 0.42), icon: "leaf", items: [
            GoalItem(name: "5 servings of vegetables", isComplete: true),
            GoalItem(name: "No processed sugar",       isComplete: true),
            GoalItem(name: "Protein with every meal",  isComplete: true),
            GoalItem(name: "Cook at home",             isComplete: true),
            GoalItem(name: "No late-night snacking",   isComplete: false),
        ]),
        Goal(name: "Hydration", color: Color(red: 0.15, green: 0.82, blue: 0.94), icon: "drop", items: [
            GoalItem(name: "Morning glass of water",         isComplete: true),
            GoalItem(name: "Drink 64 oz total",              isComplete: false),
            GoalItem(name: "Herbal tea instead of coffee",   isComplete: false),
            GoalItem(name: "No alcohol today",               isComplete: false),
        ]),
        Goal(name: "Social", color: Color(red: 1.00, green: 0.32, blue: 0.55), icon: "person.2", items: [
            GoalItem(name: "Call a friend",             isComplete: true),
            GoalItem(name: "Family dinner",             isComplete: false),
            GoalItem(name: "Compliment someone",        isComplete: true),
            GoalItem(name: "Volunteer 1 hour",          isComplete: false),
            GoalItem(name: "Phone away at meals",       isComplete: false),
        ]),
    ]
}
