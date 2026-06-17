import SwiftUI

// MARK: - Entry point

struct AddGoalSheet: View {
    let mode: AppMode
    @EnvironmentObject private var store:  DataStore
    @EnvironmentObject private var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                RadialGradient(
                    colors: [Color(red: 0.30, green: 0.20, blue: 0.60).opacity(0.25), .clear],
                    center: .top, startRadius: 0, endRadius: 400
                )
                .ignoresSafeArea()

                if mode == .daily {
                    AddDailyContent()
                } else {
                    AddLifeContent()
                }
            }
            //.preferredColorScheme(.dark) — handled by RootView
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(mode == .daily ? "manage daily goals" : "manage life goals")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.28))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

// MARK: - Health metric target config sheet

private struct HKTargetConfigSheet: View {
    let template: HealthMetricTemplate
    var onAdd: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var targetText: String

    init(template: HealthMetricTemplate, onAdd: @escaping (Double) -> Void) {
        self.template = template
        self.onAdd    = onAdd
        _targetText   = State(initialValue: String(format: "%.0f", template.defaultTarget))
    }

    private var parsedTarget: Double? {
        let t = Double(targetText.trimmingCharacters(in: .whitespaces))
        return (t ?? 0) > 0 ? t : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Icon + name
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(template.colorData.value.opacity(0.18))
                                .frame(width: 64, height: 64)
                            Image(systemName: template.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(template.colorData.value)
                        }
                        Text(template.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                        if template.isLowerBetter {
                            Text("You'll be at 100% when your reading reaches this value or below.")
                                .font(.system(size: 13))
                                .foregroundStyle(.primary.opacity(0.45))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("Set your daily target for this metric.")
                                .font(.system(size: 13))
                                .foregroundStyle(.primary.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Target input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TARGET (\(template.unitLabel.uppercased()))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.3))

                        HStack {
                            TextField("", text: $targetText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .tint(template.colorData.value)
                                .multilineTextAlignment(.center)
                            Text(template.unitLabel)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)

                    // Add button
                    Button {
                        guard let t = parsedTarget else { return }
                        onAdd(t)
                        dismiss()
                    } label: {
                        Label("Add goal", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(parsedTarget != nil ? Color.primary : Color.primary.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                parsedTarget != nil
                                    ? template.colorData.value.opacity(0.28)
                                    : Color.appRowFill,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(parsedTarget == nil)
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .padding(.top, 40)
            }
            //.preferredColorScheme(.dark) — handled by RootView
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Add Daily Goal

private struct AddDailyContent: View {
    @EnvironmentObject private var store:  DataStore
    @EnvironmentObject private var health: HealthKitManager

    private enum Tab: String, CaseIterable {
        case manage      = "Wheel"
        case suggestions = "Suggestions"
        case healthKit   = "Health"
        case custom      = "Custom"
    }

    private static let iconOptions = [
        "star.fill","heart.fill","brain.head.profile","figure.run","moon.fill","leaf",
        "drop","flame.fill","book.fill","music.note","paintbrush.fill","laptopcomputer",
        "person.2.fill","house.fill","dollarsign.circle.fill","bicycle","dumbbell.fill",
        "fork.knife","bed.double.fill","sun.max.fill","map","airplane","graduationcap.fill",
        "trophy.fill","camera.fill","gym.bag.fill","cross.fill","pills.fill"
    ]

    @State private var tab: Tab = .manage
    @State private var healthValues: [String: Double] = [:]
    @State private var loadingHealth  = false
    @State private var customName     = ""
    @State private var customIcon     = "star.fill"
    @State private var flash: String? = nil
    @State private var configuringHKTemplate: HealthMetricTemplate? = nil

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.bottom, 12)

            Group {
                if tab == .manage      { manageTab }
                if tab == .suggestions { suggestionsTab }
                if tab == .healthKit   { healthTab }
                if tab == .custom      { customTab }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)
            .frame(maxHeight: .infinity)

            if let name = flash {
                flashBanner(name)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
        .task {
            if health.isAvailable && !health.isAuthorized {
                await health.requestAuthorization()
            }
            await loadHealthValues()
        }
        .sheet(item: $configuringHKTemplate) { template in
            HKTargetConfigSheet(template: template) { target in
                store.goals.append(Goal(
                    name: template.name, colorData: template.colorData, icon: template.icon,
                    items: [],
                    healthKitIdentifier: template.id,
                    healthKitTarget: target,
                    healthKitUnit: template.unitLabel
                ))
                showFlash(template.name)
            }
            .environmentObject(store)
            .environmentObject(health)
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button { withAnimation(.spring(response: 0.3)) { tab = t } } label: {
                        Text(t.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tab == t ? Color.primary : Color.primary.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(tab == t ? Color.appRowFill.opacity(2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    // MARK: Manage tab

    private var manageTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if store.goals.isEmpty {
                    emptyManageNote("No daily goals yet. Add some from the other tabs.")
                } else {
                    VStack(spacing: 1) {
                        ForEach($store.goals) { $goal in
                            manageRow(goal: $goal)
                        }
                    }
                    .background(Color.appRowFill.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    Text("Tap to toggle goals on or off the wheel. Their data is always preserved.")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func manageRow(goal: Binding<Goal>) -> some View {
        let g = goal.wrappedValue
        return Button {
            withAnimation(.spring(response: 0.3)) {
                goal.isActive.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(g.colorData.value.opacity(g.isActive ? 0.2 : 0.07))
                        .frame(width: 38, height: 38)
                    Image(systemName: g.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(g.isActive ? g.colorData.value : .primary.opacity(0.3))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(g.isActive ? Color.primary : Color.primary.opacity(0.4))
                    Text(g.isActive ? "On wheel" : "Off wheel")
                        .font(.system(size: 11))
                        .foregroundStyle(g.isActive
                                         ? g.colorData.value.opacity(0.7)
                                         : .primary.opacity(0.22))
                }
                Spacer()
                Image(systemName: g.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(g.isActive ? g.colorData.value : .primary.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Suggestions tab

    private var suggestionsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(SuggestedGoal.categories, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cat.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.3))
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
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func suggestionCard(_ sg: SuggestedGoal) -> some View {
        // A goal is "on wheel" if it exists in the store AND isActive, or if it was added this session
        let existing    = store.goals.first { $0.name == sg.name }
        let onWheel     = existing?.isActive == true
        let offWheel    = existing != nil && existing?.isActive == false

        Button {
            if let idx = store.goals.firstIndex(where: { $0.name == sg.name }) {
                if store.goals[idx].isActive {
                    // Already active → toggle off wheel
                    withAnimation(.spring(response: 0.3)) {
                        store.goals[idx].isActive = false
                    }
                } else {
                    // Off wheel → bring back
                    withAnimation(.spring(response: 0.3)) {
                        store.goals[idx].isActive = true
                    }
                    showFlash(sg.name)
                }
            } else {
                // Not in store at all → add
                store.goals.append(sg.toGoal())
                showFlash(sg.name)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: sg.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(onWheel ? sg.colorData.value : .primary.opacity(offWheel ? 0.3 : 0.6))
                    Spacer()
                    Image(systemName: onWheel ? "checkmark.circle.fill"
                          : (offWheel ? "minus.circle" : "plus.circle"))
                        .foregroundStyle(onWheel ? sg.colorData.value
                                         : (offWheel ? Color.primary.opacity(0.3) : Color.primary.opacity(0.25)))
                        .font(.system(size: 16))
                }
                Text(sg.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(onWheel ? Color.primary : Color.primary.opacity(0.55))
                Text("\(sg.itemNames.count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(onWheel
                          ? sg.colorData.value.opacity(0.18)
                          : Color.appRowFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(onWheel ? sg.colorData.value.opacity(0.5) : Color.clear,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: onWheel)
    }

    // MARK: Health tab

    private var healthTab: some View {
        Group {
            if !health.isAvailable {
                centeredNote("HealthKit is not available on this device.")
            } else if loadingHealth {
                VStack { Spacer(); ProgressView().tint(.primary.opacity(0.4)); Spacer() }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(HealthMetricTemplate.all) { template in
                            healthRow(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func healthRow(_ template: HealthMetricTemplate) -> some View {
        let existing = store.goals.first { $0.healthKitIdentifier == template.id }
        let onWheel  = existing?.isActive == true
        let offWheel = existing != nil && existing?.isActive == false
        let value    = healthValues[template.id] ?? 0

        Button {
            if let idx = store.goals.firstIndex(where: { $0.healthKitIdentifier == template.id }) {
                withAnimation(.spring(response: 0.3)) {
                    store.goals[idx].isActive.toggle()
                }
                if store.goals[idx].isActive { showFlash(template.name) }
            } else {
                // Not in store yet — for lower-is-better metrics, ask for target first
                if template.isLowerBetter {
                    configuringHKTemplate = template
                } else {
                    store.goals.append(Goal(
                        name: template.name, colorData: template.colorData, icon: template.icon,
                        items: [],
                        healthKitIdentifier: template.id,
                        healthKitTarget: template.defaultTarget,
                        healthKitUnit: template.unitLabel
                    ))
                    showFlash(template.name)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(template.colorData.value.opacity(onWheel ? 0.2 : 0.1))
                        .frame(width: 42, height: 42)
                    Image(systemName: template.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(onWheel ? template.colorData.value : .primary.opacity(0.4))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(onWheel ? Color.primary : Color.primary.opacity(0.65))
                    Text(value > 0
                         ? "Today: \(formattedHK(value, unit: template.unitLabel))"
                         : (template.isLowerBetter
                            ? "Set your target \(template.unitLabel)"
                            : "Target: \(formattedHK(template.defaultTarget, unit: template.unitLabel))"))
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.38))
                }
                Spacer()
                Image(systemName: onWheel  ? "checkmark.circle.fill"
                      : (offWheel ? "minus.circle" : "plus.circle"))
                    .foregroundStyle(onWheel  ? template.colorData.value
                                     : (offWheel ? Color.primary.opacity(0.3) : Color.primary.opacity(0.25)))
                    .font(.system(size: 20))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(onWheel
                          ? template.colorData.value.opacity(0.12)
                          : Color.appRowFill.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(onWheel ? template.colorData.value.opacity(0.4) : Color.clear,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: onWheel)
    }

    // MARK: Custom tab

    private var customTab: some View {
        let autoColor = GoalColor.next(avoiding: store.goals.map(\.colorData))
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                fieldLabel("Goal name")
                TextField("e.g. Morning Routine", text: $customName)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .tint(.primary)
                    .padding(14)
                    .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 12))

                fieldLabel("Icon")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(Self.iconOptions, id: \.self) { sym in
                        Button { customIcon = sym } label: {
                            Image(systemName: sym)
                                .font(.system(size: 17))
                                .foregroundStyle(customIcon == sym
                                                 ? autoColor.value
                                                 : .primary.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(customIcon == sym
                                              ? autoColor.value.opacity(0.18)
                                              : Color.appRowFill)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                let canAdd = !customName.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    let trimmed = customName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let color = GoalColor.next(avoiding: store.goals.map(\.colorData))
                    store.goals.append(
                        Goal(name: trimmed, colorData: color, icon: customIcon, items: [])
                    )
                    showFlash(trimmed)
                    customName = ""
                    customIcon = "star.fill"
                } label: {
                    Label("Add goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canAdd ? Color.primary : Color.primary.opacity(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            canAdd ? autoColor.value.opacity(0.28) : Color.appRowFill,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func centeredNote(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.3))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func emptyManageNote(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.2))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(minHeight: 200)
    }

    private func formattedHK(_ v: Double, unit: String) -> String {
        if unit == "steps" && v >= 1000 { return String(format: "%.1fk \(unit)", v / 1000) }
        if v < 10 { return String(format: "%.1f \(unit)", v) }
        return "\(Int(v)) \(unit)"
    }

    private func loadHealthValues() async {
        guard health.isAuthorized else { return }
        loadingHealth = true
        var vals: [String: Double] = [:]
        for t in HealthMetricTemplate.all { vals[t.id] = await health.todayValue(for: t) }
        healthValues  = vals
        loadingHealth = false
    }

    private func showFlash(_ name: String) {
        withAnimation(.spring(response: 0.3)) { flash = name }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.25)) { flash = nil }
        }
    }

    private func flashBanner(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\"\(name)\" added to your wheel")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color.appRowFill.opacity(1.6), in: Capsule())
        .padding(.bottom, 4)
    }
}

// MARK: - Add Life Goal

private struct AddLifeContent: View {
    @EnvironmentObject private var store: DataStore

    private enum Tab: String, CaseIterable {
        case manage      = "Wheel"
        case suggestions = "Suggestions"
        case custom      = "Custom"
    }

    private static let iconOptions = [
        "star.fill","heart.fill","trophy.fill","rocket.fill","book.fill","graduationcap.fill",
        "house.fill","briefcase.fill","dollarsign.circle.fill","creditcard.fill","chart.line.uptrend.xyaxis",
        "figure.run","scalemass.fill","globe","music.note","paintbrush.fill","camera.fill",
        "person.2.fill","leaf","dumbbell.fill","cross.fill","airplane","mountain.2.fill"
    ]

    @State private var tab: Tab         = .manage
    @State private var customName       = ""
    @State private var customIcon       = "star.fill"
    @State private var flash: String?   = nil

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.bottom, 12)

            Group {
                if tab == .manage      { manageTab }
                if tab == .suggestions { suggestionsTab }
                if tab == .custom      { customTab }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)
            .frame(maxHeight: .infinity)

            if let name = flash {
                flashBanner(name)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.spring(response: 0.3)) { tab = t } } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tab == t ? Color.primary : Color.primary.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tab == t ? Color.appRowFill.opacity(2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    // MARK: Manage tab

    private var manageTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if store.lifeGoals.isEmpty {
                    emptyManageNote("No life goals yet. Add some from the other tabs.")
                } else {
                    VStack(spacing: 1) {
                        ForEach($store.lifeGoals) { $goal in
                            manageRow(goal: $goal)
                        }
                    }
                    .background(Color.appRowFill.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    Text("Tap to toggle goals on or off the wheel. Their data is always preserved.")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func manageRow(goal: Binding<LifeGoal>) -> some View {
        let g = goal.wrappedValue
        return Button {
            withAnimation(.spring(response: 0.3)) {
                goal.isActive.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(g.colorData.value.opacity(g.isActive ? 0.2 : 0.07))
                        .frame(width: 38, height: 38)
                    Image(systemName: g.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(g.isActive ? g.colorData.value : .primary.opacity(0.3))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(g.isActive ? Color.primary : Color.primary.opacity(0.4))
                    Text(g.isActive ? "On wheel" : "Off wheel")
                        .font(.system(size: 11))
                        .foregroundStyle(g.isActive
                                         ? g.colorData.value.opacity(0.7)
                                         : .primary.opacity(0.22))
                }
                Spacer()
                Image(systemName: g.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(g.isActive ? g.colorData.value : .primary.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Suggestions

    private var suggestionsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(SuggestedLifeGoal.categories, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cat.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.3))
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
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func lifeGoalCard(_ sg: SuggestedLifeGoal) -> some View {
        let existing   = store.lifeGoals.first { $0.name == sg.name }
        let onWheel    = existing?.isActive == true
        let offWheel   = existing != nil && existing?.isActive == false
        let kindLabel: String = {
            switch sg.kind {
            case .metric: return "Metric"
            case .project(let s): return "\(s.count) milestones"
            }
        }()

        Button {
            if let idx = store.lifeGoals.firstIndex(where: { $0.name == sg.name }) {
                withAnimation(.spring(response: 0.3)) {
                    store.lifeGoals[idx].isActive.toggle()
                }
                if store.lifeGoals[idx].isActive { showFlash(sg.name) }
            } else {
                store.lifeGoals.append(sg.toLifeGoal())
                showFlash(sg.name)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: sg.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(onWheel ? sg.colorData.value : .primary.opacity(offWheel ? 0.3 : 0.6))
                    Spacer()
                    Image(systemName: onWheel ? "checkmark.circle.fill"
                          : (offWheel ? "minus.circle" : "plus.circle"))
                        .foregroundStyle(onWheel ? sg.colorData.value
                                         : (offWheel ? Color.primary.opacity(0.3) : Color.primary.opacity(0.25)))
                        .font(.system(size: 16))
                }
                Text(sg.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(onWheel ? Color.primary : Color.primary.opacity(0.55))
                Text(kindLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(onWheel ? sg.colorData.value.opacity(0.18) : Color.appRowFill)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(onWheel ? sg.colorData.value.opacity(0.5) : Color.clear,
                                lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: onWheel)
    }

    // MARK: Custom

    private var customTab: some View {
        let autoColor = GoalColor.next(avoiding: store.lifeGoals.map(\.colorData))
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                fieldLabel("Goal name")
                TextField("e.g. Build my dream home", text: $customName)
                    .font(.system(size: 15)).foregroundStyle(.primary).tint(.primary)
                    .padding(14)
                    .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 12))

                fieldLabel("Icon")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(Self.iconOptions, id: \.self) { sym in
                        Button { customIcon = sym } label: {
                            Image(systemName: sym).font(.system(size: 17))
                                .foregroundStyle(customIcon == sym
                                                 ? autoColor.value
                                                 : .primary.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(customIcon == sym
                                          ? autoColor.value.opacity(0.18)
                                          : Color.appRowFill))
                        }.buttonStyle(.plain)
                    }
                }

                let canAdd = !customName.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    let trimmed = customName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let color = GoalColor.next(avoiding: store.lifeGoals.map(\.colorData))
                    store.lifeGoals.append(
                        LifeGoal(name: trimmed, colorData: color, icon: customIcon, kind: .project([]))
                    )
                    showFlash(trimmed)
                    customName = ""
                    customIcon = "star.fill"
                } label: {
                    Label("Add life goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canAdd ? Color.primary : Color.primary.opacity(0.25))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(
                            canAdd ? autoColor.value.opacity(0.28) : Color.appRowFill,
                            in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyManageNote(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.2))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(minHeight: 200)
    }

    private func showFlash(_ name: String) {
        withAnimation(.spring(response: 0.3)) { flash = name }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.25)) { flash = nil }
        }
    }

    private func flashBanner(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\"\(name)\" added to your wheel")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color.appRowFill.opacity(1.6), in: Capsule())
        .padding(.bottom, 4)
    }
}
