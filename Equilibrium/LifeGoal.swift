import SwiftUI

// MARK: - SubGoal (recursive tree node)

struct SubGoal: Identifiable, Codable, Equatable {
    var id        = UUID()
    var name: String
    var isComplete: Bool    = false
    var children: [SubGoal] = []

    var progress: Double {
        if children.isEmpty { return isComplete ? 1.0 : 0.0 }
        return children.map(\.progress).reduce(0, +) / Double(children.count)
    }

    var completedChildCount: Int { children.filter { $0.progress >= 1.0 }.count }
}

// MARK: - Metric

enum MetricDirection: String, Codable, Equatable {
    case higher   // want to increase (savings, vocabulary)
    case lower    // want to decrease (body weight, time)
}

struct MetricEntry: Identifiable, Codable, Equatable {
    var id    = UUID()
    var date: Date
    var value: Double
}

struct MetricData: Codable, Equatable {
    var unit: String
    var unitPrefix: String     = ""
    var direction: MetricDirection
    var startValue: Double
    var currentValue: Double
    var targetValue: Double
    var history: [MetricEntry]

    var progress: Double {
        let range = abs(targetValue - startValue)
        guard range > 0 else { return 0 }
        let delta: Double = direction == .higher
            ? currentValue - startValue
            : startValue  - currentValue
        return max(0, min(1, delta / range))
    }

    func formatted(_ v: Double) -> String {
        if abs(v) >= 1_000 {
            let k = v / 1_000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))K" : String(format: "%.1fK", k)
        }
        return v.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(v))" : String(format: "%.1f", v)
    }

    var currentLabel: String { "\(unitPrefix)\(formatted(currentValue))\(unit)" }
    var targetLabel:  String { "\(unitPrefix)\(formatted(targetValue))\(unit)" }
}

// MARK: - LifeGoalKind

enum LifeGoalKind: Codable, Equatable {
    case metric(MetricData)
    case project([SubGoal])

    private enum CK: String, CodingKey { case type, metric, subgoals }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        switch self {
        case .metric(let data):
            try c.encode("metric", forKey: .type)
            try c.encode(data, forKey: .metric)
        case .project(let subs):
            try c.encode("project", forKey: .type)
            try c.encode(subs, forKey: .subgoals)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        switch try c.decode(String.self, forKey: .type) {
        case "metric":  self = .metric(try c.decode(MetricData.self, forKey: .metric))
        default:        self = .project(try c.decode([SubGoal].self, forKey: .subgoals))
        }
    }
}

// MARK: - LifeGoal

struct LifeGoal: Identifiable, Codable, Equatable {
    var id        = UUID()
    var name: String
    var colorData: GoalColor
    var icon: String
    var kind: LifeGoalKind
    var isActive: Bool = true

    var color: Color { colorData.value }

    var progress: Double {
        switch kind {
        case .metric(let m):
            return m.progress
        case .project(let sgs):
            guard !sgs.isEmpty else { return 0 }
            return sgs.map(\.progress).reduce(0, +) / Double(sgs.count)
        }
    }

    var wheelEntry: WheelEntry {
        WheelEntry(id: id, name: name, color: color, icon: icon, progress: progress)
    }
}

// MARK: - Backward-compatible Codable for LifeGoal

extension LifeGoal {
    enum CodingKeys: String, CodingKey {
        case id, name, colorData, icon, kind, isActive
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,         forKey: .id)
        name      = try c.decode(String.self,       forKey: .name)
        colorData = try c.decode(GoalColor.self,    forKey: .colorData)
        icon      = try c.decode(String.self,       forKey: .icon)
        kind      = try c.decode(LifeGoalKind.self, forKey: .kind)
        isActive  = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}

// MARK: - Demo Data

extension LifeGoal {
    static var demos: [LifeGoal] {
        [
            LifeGoal(
                name: "Body Composition", colorData: .teal,
                icon: "figure.strengthtraining.traditional",
                kind: .metric(MetricData(
                    unit: " lbs", direction: .lower,
                    startValue: 192, currentValue: 188, targetValue: 175,
                    history: trendHistory(from: 192, to: 188, days: 60, step: 7, noise: 0.8)
                ))
            ),
            LifeGoal(
                name: "Financial Freedom", colorData: .gold,
                icon: "chart.line.uptrend.xyaxis",
                kind: .metric(MetricData(
                    unit: "", unitPrefix: "$", direction: .higher,
                    startValue: 10_000, currentValue: 52_000, targetValue: 100_000,
                    history: trendHistory(from: 10_000, to: 52_000, days: 180, step: 30, noise: 500)
                ))
            ),
            LifeGoal(
                name: "Remodel Home", colorData: .amber, icon: "house",
                kind: .project([
                    SubGoal(name: "Kitchen", children: [
                        SubGoal(name: "New countertops",  isComplete: true),
                        SubGoal(name: "Cabinet hardware", isComplete: true),
                        SubGoal(name: "Backsplash tile",  isComplete: false),
                    ]),
                    SubGoal(name: "Master Bathroom", children: [
                        SubGoal(name: "Replace bathtub",  isComplete: false),
                        SubGoal(name: "Paint walls",      isComplete: true),
                        SubGoal(name: "Install vanity",   isComplete: false),
                        SubGoal(name: "New tile floor",   isComplete: false),
                    ]),
                    SubGoal(name: "Living Room", children: [
                        SubGoal(name: "Fresh paint",      isComplete: true),
                        SubGoal(name: "New flooring",     isComplete: false),
                        SubGoal(name: "Built-in shelves", isComplete: false),
                    ]),
                    SubGoal(name: "Backyard", children: [
                        SubGoal(name: "Deck renovation",  isComplete: false),
                        SubGoal(name: "Landscaping",      isComplete: false),
                    ]),
                ])
            ),
            LifeGoal(
                name: "Career Growth", colorData: .blue, icon: "briefcase",
                kind: .project([
                    SubGoal(name: "Technical Skills", children: [
                        SubGoal(name: "Swift certification",  isComplete: true),
                        SubGoal(name: "System design course", isComplete: false),
                        SubGoal(name: "AI/ML fundamentals",   isComplete: false),
                    ]),
                    SubGoal(name: "Leadership", children: [
                        SubGoal(name: "Lead a project",    isComplete: true),
                        SubGoal(name: "Mentor junior dev", isComplete: false),
                        SubGoal(name: "Public speaking",   isComplete: false),
                    ]),
                    SubGoal(name: "Network", children: [
                        SubGoal(name: "Attend 3 conferences", isComplete: false),
                        SubGoal(name: "LinkedIn 500+",        isComplete: true),
                    ]),
                ])
            ),
            LifeGoal(
                name: "Learn Spanish", colorData: .violet, icon: "text.bubble",
                kind: .metric(MetricData(
                    unit: " words", direction: .higher,
                    startValue: 0, currentValue: 1_200, targetValue: 3_000,
                    history: trendHistory(from: 0, to: 1_200, days: 90, step: 7, noise: 25)
                ))
            ),
            LifeGoal(
                name: "Write a Book", colorData: .rose, icon: "book.closed",
                kind: .project([
                    SubGoal(name: "Pre-writing", children: [
                        SubGoal(name: "Outline all chapters",   isComplete: true),
                        SubGoal(name: "Character profiles",     isComplete: true),
                        SubGoal(name: "Research & world-build", isComplete: true),
                    ]),
                    SubGoal(name: "First Draft", children: [
                        SubGoal(name: "Part 1 (ch. 1–5)",   isComplete: true),
                        SubGoal(name: "Part 2 (ch. 6–10)",  isComplete: false),
                        SubGoal(name: "Part 3 (ch. 11–15)", isComplete: false),
                    ]),
                    SubGoal(name: "Revision",   isComplete: false),
                    SubGoal(name: "Publishing", children: [
                        SubGoal(name: "Find literary agent",  isComplete: false),
                        SubGoal(name: "Submit to publishers", isComplete: false),
                    ]),
                ])
            ),
        ]
    }

    private static func trendHistory(from start: Double, to end: Double,
                                     days: Int, step: Int, noise: Double) -> [MetricEntry] {
        let cal  = Calendar.current
        let now  = Date()
        var seed = UInt64(42)

        func lcg() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(1 << 31) - 1.0
        }

        return stride(from: 0, through: days, by: step).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -(days - i), to: now) else { return nil }
            let t   = Double(i) / Double(days)
            let val = start + (end - start) * t + lcg() * noise
            return MetricEntry(date: d, value: val)
        }
    }
}
