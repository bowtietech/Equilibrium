import SwiftUI
import HealthKit

// MARK: - Suggested goal catalog

struct SuggestedGoal: Identifiable {
    let id   = UUID()
    let name: String
    let icon: String
    let colorData: GoalColor
    let category: String
    let itemNames: [String]

    func toGoal() -> Goal {
        Goal(name: name, colorData: colorData, icon: icon,
             items: itemNames.map { GoalItem(name: $0, isComplete: false, schedule: .daily) })
    }

    static let all: [SuggestedGoal] = [
        // Fitness
        SuggestedGoal(name: "Exercise", icon: "figure.run", colorData: .orange,
                      category: "Fitness",
                      itemNames: ["Morning workout", "Evening stretch", "Active recovery"]),
        SuggestedGoal(name: "Movement", icon: "figure.walk", colorData: .teal,
                      category: "Fitness",
                      itemNames: ["Take the stairs", "Walk during lunch", "Stand every hour"]),
        // Mindfulness
        SuggestedGoal(name: "Mindfulness", icon: "brain.head.profile", colorData: .purple,
                      category: "Mind",
                      itemNames: ["10-minute meditation", "Morning journaling", "Breathwork session"]),
        SuggestedGoal(name: "Digital Detox", icon: "iphone.slash", colorData: .violet,
                      category: "Mind",
                      itemNames: ["No phone first 30 min", "Phone-free meals", "No screens after 9 PM"]),
        // Nutrition
        SuggestedGoal(name: "Nutrition", icon: "leaf", colorData: .green,
                      category: "Nutrition",
                      itemNames: ["5 servings of veg", "Protein at every meal", "No processed sugar"]),
        SuggestedGoal(name: "Hydration", icon: "drop", colorData: .cyan,
                      category: "Nutrition",
                      itemNames: ["8 glasses of water", "Morning glass on wake", "No sugary drinks"]),
        // Sleep
        SuggestedGoal(name: "Sleep", icon: "moon.zzz", colorData: .indigo,
                      category: "Sleep",
                      itemNames: ["In bed by 10:30 PM", "8 hours of sleep", "Consistent wake time"]),
        SuggestedGoal(name: "Wind Down", icon: "moon.stars", colorData: .blue,
                      category: "Sleep",
                      itemNames: ["No screens after 9", "Read for 20 minutes", "Room at 67°F"]),
        // Social
        SuggestedGoal(name: "Relationships", icon: "person.2.fill", colorData: .pink,
                      category: "Social",
                      itemNames: ["Reach out to a friend", "Quality family time", "Random act of kindness"]),
        // Growth
        SuggestedGoal(name: "Learning", icon: "book.fill", colorData: .gold,
                      category: "Growth",
                      itemNames: ["Read for 30 minutes", "Learn something new", "Practice a skill"]),
        SuggestedGoal(name: "Finances", icon: "dollarsign.circle.fill", colorData: .amber,
                      category: "Growth",
                      itemNames: ["Review daily spending", "No impulse purchases", "Save 10% of income"]),
    ]

    static var categories: [String] {
        var seen = Set<String>()
        return all.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }
}

// MARK: - Suggested life goal catalog

struct SuggestedLifeGoal: Identifiable {
    let id   = UUID()
    let name: String
    let icon: String
    let colorData: GoalColor
    let category: String
    let detail: String          // shown in card subtitle
    let kind: LifeGoalKind

    func toLifeGoal() -> LifeGoal {
        LifeGoal(name: name, colorData: colorData, icon: icon, kind: kind)
    }

    static let all: [SuggestedLifeGoal] = [
        // Health & Body
        SuggestedLifeGoal(name: "Reach goal weight", icon: "scalemass.fill", colorData: .teal,
                          category: "Health",
                          detail: "Track body weight toward a target",
                          kind: .metric(MetricData(unit: " lbs", direction: .lower,
                                                   startValue: 200, currentValue: 200, targetValue: 175, history: []))),
        SuggestedLifeGoal(name: "Run a 5K", icon: "figure.run", colorData: .orange,
                          category: "Health",
                          detail: "Build up to your first 5-kilometer run",
                          kind: .project([
                            SubGoal(name: "Walk 2 miles without stopping"),
                            SubGoal(name: "Run 1 mile non-stop"),
                            SubGoal(name: "Run 5K non-stop"),
                          ])),
        // Financial
        SuggestedLifeGoal(name: "Build emergency fund", icon: "dollarsign.circle.fill", colorData: .green,
                          category: "Financial",
                          detail: "Save 3–6 months of expenses",
                          kind: .metric(MetricData(unit: "", unitPrefix: "$", direction: .higher,
                                                   startValue: 0, currentValue: 0, targetValue: 15_000, history: []))),
        SuggestedLifeGoal(name: "Pay off debt", icon: "creditcard.fill", colorData: .amber,
                          category: "Financial",
                          detail: "Track your balance down to zero",
                          kind: .metric(MetricData(unit: "", unitPrefix: "$", direction: .lower,
                                                   startValue: 10_000, currentValue: 10_000, targetValue: 0, history: []))),
        // Personal growth
        SuggestedLifeGoal(name: "Write a book", icon: "book.fill", colorData: .purple,
                          category: "Growth",
                          detail: "From first draft to finished manuscript",
                          kind: .project([
                            SubGoal(name: "Outline chapters"),
                            SubGoal(name: "Write first draft"),
                            SubGoal(name: "Edit & revise"),
                            SubGoal(name: "Publish or share"),
                          ])),
        SuggestedLifeGoal(name: "Learn a language", icon: "globe", colorData: .blue,
                          category: "Growth",
                          detail: "Reach conversational fluency",
                          kind: .project([
                            SubGoal(name: "Learn 500 vocabulary words"),
                            SubGoal(name: "Complete beginner course"),
                            SubGoal(name: "Hold a 5-minute conversation"),
                          ])),
        SuggestedLifeGoal(name: "Launch a side project", icon: "rocket.fill", colorData: .rose,
                          category: "Growth",
                          detail: "Take an idea from concept to reality",
                          kind: .project([
                            SubGoal(name: "Define the idea & audience"),
                            SubGoal(name: "Build an MVP"),
                            SubGoal(name: "Get first users / customers"),
                          ])),
        // Home & Life
        SuggestedLifeGoal(name: "Home renovation", icon: "house.fill", colorData: .gold,
                          category: "Home",
                          detail: "Tackle a major home improvement project",
                          kind: .project([
                            SubGoal(name: "Define scope & budget"),
                            SubGoal(name: "Hire contractors"),
                            SubGoal(name: "Complete the work"),
                          ])),
        SuggestedLifeGoal(name: "Declutter & organize", icon: "tray.fill", colorData: .cyan,
                          category: "Home",
                          detail: "Create a calm, organized living space",
                          kind: .project([
                            SubGoal(name: "Declutter every room"),
                            SubGoal(name: "Set up storage systems"),
                            SubGoal(name: "Donate / sell excess"),
                          ])),
    ]

    static var categories: [String] {
        var seen = Set<String>()
        return all.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject private var store:  DataStore
    @EnvironmentObject private var health: HealthKitManager

    @State private var step               = 0
    @State private var pendingGoals:      [Goal]     = []
    @State private var pendingLifeGoals:  [LifeGoal] = []

    private let totalSteps = 4   // Welcome · Daily · Life · Review

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.30, green: 0.20, blue: 0.60).opacity(0.35), .clear],
                center: .top, startRadius: 0, endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                ZStack {
                    if step == 0 {
                        WelcomeStep(onNext: nextStep)
                            .transition(stepTransition)
                    }
                    if step == 1 {
                        PickerStep(pendingGoals: $pendingGoals, onNext: nextStep, onBack: prevStep)
                            .transition(stepTransition)
                    }
                    if step == 2 {
                        LifeGoalPickerStep(pendingLifeGoals: $pendingLifeGoals,
                                           onNext: nextStep, onBack: prevStep)
                            .transition(stepTransition)
                    }
                    if step == 3 {
                        ReviewStep(pendingGoals: $pendingGoals,
                                   pendingLifeGoals: $pendingLifeGoals,
                                   onFinish: finish, onBack: prevStep)
                            .transition(stepTransition)
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.white : Color.white.opacity(0.18))
                    .frame(width: i == step ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.35), value: step)
            }
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity))
    }

    // MARK: - Navigation

    private func nextStep() {
        withAnimation { step = min(step + 1, totalSteps - 1) }
    }

    private func prevStep() {
        withAnimation { step = max(step - 1, 0) }
    }

    private func finish() {
        store.completeOnboarding(goals: pendingGoals, lifeGoals: pendingLifeGoals)
        Task { await health.refresh(goals: pendingGoals) }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Visual
            ZStack {
                ForEach(0..<6) { i in
                    let angle = Double(i) * 60.0
                    let len = CGFloat([0.55, 0.7, 0.45, 0.8, 0.6, 0.5][i])
                    Rectangle()
                        .fill(palette[i].opacity(0.85))
                        .frame(width: 3, height: 80 * len)
                        .offset(y: -40 * len)
                        .rotationEffect(.degrees(angle))
                }
                Circle()
                    .fill(Color(red: 0.58, green: 0.40, blue: 0.96))
                    .frame(width: 14, height: 14)
            }
            .frame(width: 200, height: 200)
            .padding(.bottom, 40)

            Text("equilibrium")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            
            Text("Balance your life, one goal at a time.")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()

            ctaButton("Let's set up your goals", action: onNext)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private let palette: [Color] = [.purple, .orange, .green, .cyan, .pink, .indigo]
}

// MARK: - Step 1: Goal Picker

private struct PickerStep: View {
    @Binding var pendingGoals: [Goal]
    let onNext: () -> Void
    let onBack: () -> Void

    @EnvironmentObject private var health: HealthKitManager
    @State private var tab: PickerTab = .suggestions
    @State private var selectedSuggestionIDs = Set<UUID>()
    @State private var selectedHealthIDs     = Set<String>()
    @State private var healthValues: [String: Double] = [:]
    @State private var customName     = ""
    @State private var customIcon     = "star.fill"
    @State private var customColorIdx = 0
    @State private var loadingHealth  = false

    private enum PickerTab: String, CaseIterable {
        case suggestions = "Suggestions"
        case health      = "Health"
        case custom      = "Custom"
    }

    private static let colorPalette: [GoalColor] = [
        .purple, .orange, .green, .cyan, .pink, .indigo, .teal, .gold, .rose, .violet, .blue, .amber
    ]

    private static let iconOptions = [
        "star.fill","heart.fill","brain.head.profile","figure.run","moon.fill","leaf",
        "drop","flame.fill","book.fill","music.note","paintbrush.fill","laptopcomputer",
        "person.2.fill","house.fill","dollarsign.circle.fill","bicycle","dumbbell.fill",
        "fork.knife","bed.double.fill","sun.max.fill","map","airplane","graduationcap.fill",
        "trophy.fill","camera.fill","gym.bag.fill","cross.fill","pills.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("What would you like to track?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Pick from suggestions, connect Health, or create your own.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(PickerTab.allCases, id: \.self) { t in
                    Button { withAnimation(.spring(response: 0.3)) { tab = t } } label: {
                        Text(t.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tab == t ? .white : .white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                tab == t ? Color.white.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Tab content
            Group {
                if tab == .suggestions { suggestionsTab }
                if tab == .health      { healthTab }
                if tab == .custom      { customTab }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)
            .frame(maxHeight: .infinity)

            // Bottom selected chips + CTA
            VStack(spacing: 12) {
                if !pendingGoals.isEmpty { selectedChips }

                HStack(spacing: 12) {
                    backButton(action: onBack)
                    ctaButton(pendingGoals.isEmpty ? "Skip" : "Review (\(pendingGoals.count))",
                              action: onNext)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if health.isAvailable && !health.isAuthorized {
                await health.requestAuthorization()
            }
            await loadHealthValues()
        }
    }

    // MARK: Suggestions tab

    private var suggestionsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(SuggestedGoal.categories, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cat.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.leading, 4)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(SuggestedGoal.all.filter { $0.category == cat }) { sg in
                                suggestionCard(sg)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func suggestionCard(_ sg: SuggestedGoal) -> some View {
        let isSelected = selectedSuggestionIDs.contains(sg.id)
        Button {
            toggleSuggestion(sg)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: sg.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(sg.colorData.value)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(sg.colorData.value)
                            .font(.system(size: 16))
                    }
                }
                Text(sg.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(sg.itemNames.count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? sg.colorData.value.opacity(0.18)
                          : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? sg.colorData.value.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }

    // MARK: Health tab

    private var healthTab: some View {
        Group {
            if !health.isAvailable {
                unavailableView("HealthKit is not available on this device.")
            } else if loadingHealth {
                loadingView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(HealthMetricTemplate.all) { template in
                            healthRow(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func healthRow(_ template: HealthMetricTemplate) -> some View {
        let isSelected = selectedHealthIDs.contains(template.id)
        let value      = healthValues[template.id] ?? 0

        Button { toggleHealth(template) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(template.colorData.value.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: template.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(template.colorData.value)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(value > 0
                         ? "Today: \(formattedHK(value, unit: template.unitLabel))"
                         : "Target: \(formattedHK(template.defaultTarget, unit: template.unitLabel))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.38))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? template.colorData.value : .white.opacity(0.25))
                    .font(.system(size: 20))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? template.colorData.value.opacity(0.12)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? template.colorData.value.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }

    // MARK: Custom tab

    private var customTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    label("Goal name")
                    TextField("e.g. Morning Routine", text: $customName)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(14)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                // Color
                VStack(alignment: .leading, spacing: 8) {
                    label("Color")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.colorPalette.indices, id: \.self) { i in
                                let col = Self.colorPalette[i]
                                Circle()
                                    .fill(col.value)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(.white.opacity(customColorIdx == i ? 0.9 : 0), lineWidth: 2.5).padding(-3))
                                    .onTapGesture { customColorIdx = i }
                                    .animation(.spring(response: 0.25), value: customColorIdx)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Icon
                VStack(alignment: .leading, spacing: 8) {
                    label("Icon")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(Self.iconOptions, id: \.self) { sym in
                            Button { customIcon = sym } label: {
                                Image(systemName: sym)
                                    .font(.system(size: 17))
                                    .foregroundStyle(customIcon == sym
                                                     ? Self.colorPalette[customColorIdx].value
                                                     : .white.opacity(0.4))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(customIcon == sym
                                                  ? Self.colorPalette[customColorIdx].value.opacity(0.18)
                                                  : Color.white.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Add button
                Button { addCustomGoal() } label: {
                    Label("Add goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(customName.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? .white.opacity(0.25) : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            customName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.white.opacity(0.06)
                            : Self.colorPalette[customColorIdx].value.opacity(0.28),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: Selected chips

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pendingGoals) { goal in
                    HStack(spacing: 5) {
                        Image(systemName: goal.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(goal.color)
                        Text(goal.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                        Button { removeGoal(goal) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(goal.color.opacity(0.15), in: Capsule())
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Helpers

    private func toggleSuggestion(_ sg: SuggestedGoal) {
        if selectedSuggestionIDs.contains(sg.id) {
            selectedSuggestionIDs.remove(sg.id)
            pendingGoals.removeAll { $0.name == sg.name }
        } else {
            selectedSuggestionIDs.insert(sg.id)
            pendingGoals.append(sg.toGoal())
        }
    }

    private func toggleHealth(_ template: HealthMetricTemplate) {
        if selectedHealthIDs.contains(template.id) {
            selectedHealthIDs.remove(template.id)
            pendingGoals.removeAll { $0.healthKitIdentifier == template.id }
        } else {
            selectedHealthIDs.insert(template.id)
            let goal = Goal(
                name: template.name, colorData: template.colorData, icon: template.icon,
                items: [],
                healthKitIdentifier: template.id,
                healthKitTarget: template.defaultTarget,
                healthKitUnit: template.unitLabel
            )
            pendingGoals.append(goal)
        }
    }

    private func addCustomGoal() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let goal = Goal(name: trimmed, colorData: Self.colorPalette[customColorIdx],
                        icon: customIcon, items: [])
        pendingGoals.append(goal)
        customName = ""
    }

    private func removeGoal(_ goal: Goal) {
        pendingGoals.removeAll { $0.id == goal.id }
        selectedSuggestionIDs = selectedSuggestionIDs.filter { sid in
            SuggestedGoal.all.first(where: { $0.id == sid })?.name != goal.name
        }
        if let hkId = goal.healthKitIdentifier { selectedHealthIDs.remove(hkId) }
    }

    private func loadHealthValues() async {
        guard health.isAuthorized else { return }
        loadingHealth = true
        var vals: [String: Double] = [:]
        for t in HealthMetricTemplate.all { vals[t.id] = await health.todayValue(for: t) }
        healthValues  = vals
        loadingHealth = false
    }

    private func formattedHK(_ v: Double, unit: String) -> String {
        if unit == "steps" && v >= 1000 { return String(format: "%.1fk \(unit)", v / 1000) }
        if v < 10 { return String(format: "%.1f \(unit)", v) }
        return "\(Int(v)) \(unit)"
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.3))
    }

    private var loadingView: some View {
        VStack { Spacer(); ProgressView().tint(.white.opacity(0.4)); Spacer() }
    }

    private func unavailableView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            Text(msg)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

// MARK: - Step 2: Life Goal Picker

private struct LifeGoalPickerStep: View {
    @Binding var pendingLifeGoals: [LifeGoal]
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedIDs = Set<UUID>()
    @State private var customName     = ""
    @State private var customIcon     = "star.fill"
    @State private var customColorIdx = 0
    @State private var tab: LifeTab   = .suggestions

    private enum LifeTab: String, CaseIterable {
        case suggestions = "Suggestions"
        case custom      = "Custom"
    }

    private static let colorPalette: [GoalColor] = [
        .purple, .orange, .green, .cyan, .pink, .indigo, .teal, .gold, .rose, .violet, .blue, .amber
    ]
    private static let iconOptions = [
        "star.fill","heart.fill","trophy.fill","rocket.fill","book.fill","graduationcap.fill",
        "house.fill","briefcase.fill","dollarsign.circle.fill","creditcard.fill","chart.line.uptrend.xyaxis",
        "figure.run","scalemass.fill","globe","music.note","paintbrush.fill","camera.fill",
        "person.2.fill","leaf","dumbbell.fill","cross.fill","airplane","mountain.2.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Big picture goals")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Long-term ambitions, projects, and milestones.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(LifeTab.allCases, id: \.self) { t in
                    Button { withAnimation(.spring(response: 0.3)) { tab = t } } label: {
                        Text(t.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tab == t ? .white : .white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(tab == t ? Color.white.opacity(0.12) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Group {
                if tab == .suggestions { suggestionsTab }
                else                   { customTab }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)
            .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                if !pendingLifeGoals.isEmpty { selectedChips }
                HStack(spacing: 12) {
                    backButton(action: onBack)
                    ctaButton(pendingLifeGoals.isEmpty ? "Skip" : "Review (\(pendingLifeGoals.count))",
                              action: onNext)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Suggestions

    private var suggestionsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(SuggestedLifeGoal.categories, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cat.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.leading, 4)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(SuggestedLifeGoal.all.filter { $0.category == cat }) { sg in
                                lifeGoalCard(sg)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func lifeGoalCard(_ sg: SuggestedLifeGoal) -> some View {
        let isSelected = selectedIDs.contains(sg.id)
        let kindLabel: String = {
            switch sg.kind {
            case .metric: return "Metric"
            case .project(let s): return "\(s.count) milestones"
            }
        }()

        Button { toggle(sg) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: sg.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(sg.colorData.value)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(sg.colorData.value)
                            .font(.system(size: 16))
                    }
                }
                Text(sg.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(kindLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? sg.colorData.value.opacity(0.18) : Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? sg.colorData.value.opacity(0.5) : Color.clear, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }

    // MARK: Custom

    private var customTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Goal name")
                    TextField("e.g. Build my dream home", text: $customName)
                        .font(.system(size: 15)).foregroundStyle(.white).tint(.white)
                        .padding(14)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Color")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.colorPalette.indices, id: \.self) { i in
                                Circle().fill(Self.colorPalette[i].value).frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(.white.opacity(customColorIdx == i ? 0.9 : 0), lineWidth: 2.5).padding(-3))
                                    .onTapGesture { customColorIdx = i }
                                    .animation(.spring(response: 0.25), value: customColorIdx)
                            }
                        }.padding(.horizontal, 2)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Icon")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(Self.iconOptions, id: \.self) { sym in
                            Button { customIcon = sym } label: {
                                Image(systemName: sym).font(.system(size: 17))
                                    .foregroundStyle(customIcon == sym ? Self.colorPalette[customColorIdx].value : .white.opacity(0.4))
                                    .frame(width: 40, height: 40)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(customIcon == sym ? Self.colorPalette[customColorIdx].value.opacity(0.18) : Color.white.opacity(0.05)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Button { addCustom() } label: {
                    Label("Add life goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(customName.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.25) : .white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(
                            customName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.white.opacity(0.06)
                                : Self.colorPalette[customColorIdx].value.opacity(0.28),
                            in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24).padding(.bottom, 12)
        }
    }

    // MARK: Chips

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pendingLifeGoals) { lg in
                    HStack(spacing: 5) {
                        Image(systemName: lg.icon).font(.system(size: 11)).foregroundStyle(lg.color)
                        Text(lg.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        Button { pendingLifeGoals.removeAll { $0.id == lg.id } } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.4))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(lg.color.opacity(0.15), in: Capsule())
                }
            }.padding(.horizontal, 24)
        }
    }

    // MARK: Helpers

    private func toggle(_ sg: SuggestedLifeGoal) {
        if selectedIDs.contains(sg.id) {
            selectedIDs.remove(sg.id)
            pendingLifeGoals.removeAll { $0.name == sg.name }
        } else {
            selectedIDs.insert(sg.id)
            pendingLifeGoals.append(sg.toLifeGoal())
        }
    }

    private func addCustom() {
        let name = customName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        pendingLifeGoals.append(
            LifeGoal(name: name, colorData: Self.colorPalette[customColorIdx],
                     icon: customIcon, kind: .project([]))
        )
        customName = ""
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.3))
    }
}

// MARK: - Step 3: Review

private struct ReviewStep: View {
    @Binding var pendingGoals:     [Goal]
    @Binding var pendingLifeGoals: [LifeGoal]
    let onFinish: () -> Void
    let onBack:   () -> Void

    var body: some View {
        let totalCount = pendingGoals.count + pendingLifeGoals.count

        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(totalCount == 0 ? "No goals yet" : "Your goals")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(totalCount == 0
                     ? "You can always add goals from the main screen."
                     : "These will appear on your wheel. You can edit them anytime.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)

            if totalCount == 0 {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        if !pendingGoals.isEmpty {
                            sectionHeader("Daily Goals")
                            ForEach(pendingGoals) { goalRow($0, isLife: false) }
                        }
                        if !pendingLifeGoals.isEmpty {
                            sectionHeader("Life Goals").padding(.top, pendingGoals.isEmpty ? 0 : 8)
                            ForEach(pendingLifeGoals) { lifeGoalRow($0) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }

            VStack(spacing: 12) {
                ctaButton(totalCount == 0 ? "Start fresh" : "Start your journey",
                          action: onFinish)
                    .padding(.horizontal, 24)

                Button(action: onBack) {
                    Text("Go back")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal, isLife: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(goal.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: goal.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(goal.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(goal.isHealthBacked
                     ? "Apple Health · \(Int(goal.healthKitTarget ?? 0)) \(goal.healthKitUnit ?? "")"
                     : "\(goal.items.count) item\(goal.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
            Button { pendingGoals.removeAll { $0.id == goal.id } } label: {
                Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(.white.opacity(0.25))
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func lifeGoalRow(_ goal: LifeGoal) -> some View {
        let kindLabel: String = {
            switch goal.kind {
            case .metric: return "Metric goal"
            case .project(let s): return s.isEmpty ? "Project" : "\(s.count) milestones"
            }
        }()
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(goal.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: goal.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(goal.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(kindLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
            Button { pendingLifeGoals.removeAll { $0.id == goal.id } } label: {
                Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(.white.opacity(0.25))
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.15))
            Spacer()
        }
    }
}

// MARK: - Shared button helpers

private func ctaButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white)
            .cornerRadius(16)
    }
    .buttonStyle(.plain)
}

private func backButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 54, height: 54)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
}
