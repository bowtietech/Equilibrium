import SwiftUI

struct Goal: Identifiable {
    let id = UUID()
    let name: String
    var progress: Double // 0.0 = not started, 1.0 = complete
    let color: Color
    let icon: String
}

extension Goal {
    static let demos: [Goal] = [
        Goal(name: "Mindfulness", progress: 0.72, color: Color(red: 0.58, green: 0.40, blue: 0.96), icon: "brain.head.profile"),
        Goal(name: "Exercise",    progress: 0.45, color: Color(red: 1.00, green: 0.55, blue: 0.10), icon: "figure.run"),
        Goal(name: "Sleep",       progress: 0.60, color: Color(red: 0.30, green: 0.45, blue: 0.95), icon: "moon.zzz"),
        Goal(name: "Nutrition",   progress: 0.80, color: Color(red: 0.18, green: 0.78, blue: 0.42), icon: "leaf"),
        Goal(name: "Hydration",   progress: 0.35, color: Color(red: 0.15, green: 0.82, blue: 0.94), icon: "drop"),
        Goal(name: "Social",      progress: 0.55, color: Color(red: 1.00, green: 0.32, blue: 0.55), icon: "person.2"),
    ]
}
