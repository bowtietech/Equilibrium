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
                Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()
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
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(mode == .daily ? "add daily goal" : "add life goal")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.28))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
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
        case suggestions = "Suggestions"
        case healthKit   = "Health"
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

    @State private var tab: Tab = .suggestions
    @State private var addedIDs          = Set<String>()   // names/HK ids added in this session
    @State private var preExistingNames  = Set<String>()   // goal names already in store on open
    @State private var preExistingHKIds  = Set<String>()   // HK ids already in store on open
    @State private var healthValues: [String: Double] = [:]
    @State private var loadingHealth  = false
    @State private var customName     = ""
    @State private var customIcon     = "star.fill"
    @State private var customColorIdx = 0
    @State private var flash: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.bottom, 12)

            Group {
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
        .onAppear {
            // Snapshot the store so we never remove goals the user already had data in.
            preExistingNames = Set(store.goals.map { $0.name })
            preExistingHKIds = Set(store.goals.compactMap { $0.healthKitIdentifier })
        }
        .task {
            if health.isAvailable && !health.isAuthorized {
                await health.requestAuthorization()
            }
            await loadHealthValues()
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
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
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func suggestionCard(_ sg: SuggestedGoal) -> some View {
        let isPreExisting    = preExistingNames.contains(sg.name)
        let isSessionAdded   = addedIDs.contains(sg.name)
        let alreadyAdded     = isPreExisting || isSessionAdded
        Button {
            if isSessionAdded {
                // Only remove goals we added this session — never touch pre-existing data
                store.goals.removeAll { $0.name == sg.name }
                addedIDs.remove(sg.name)
            } else if !isPreExisting {
                store.goals.append(sg.toGoal())
                addedIDs.insert(sg.name)
                showFlash(sg.name)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: sg.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(sg.colorData.value)
                    Spacer()
                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(alreadyAdded ? sg.colorData.value : .white.opacity(0.25))
                        .font(.system(size: 16))
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
                    .fill(alreadyAdded
                          ? sg.colorData.value.opacity(0.18)
                          : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(alreadyAdded ? sg.colorData.value.opacity(0.5) : Color.clear,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: alreadyAdded)
    }

    // MARK: Health tab

    private var healthTab: some View {
        Group {
            if !health.isAvailable {
                centeredNote("HealthKit is not available on this device.")
            } else if loadingHealth {
                VStack { Spacer(); ProgressView().tint(.white.opacity(0.4)); Spacer() }
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
        let isPreExisting  = preExistingHKIds.contains(template.id)
        let isSessionAdded = addedIDs.contains(template.id)
        let alreadyAdded   = isPreExisting || isSessionAdded
        let value = healthValues[template.id] ?? 0

        Button {
            if isSessionAdded {
                store.goals.removeAll { $0.healthKitIdentifier == template.id }
                addedIDs.remove(template.id)
            } else if !isPreExisting {
                store.goals.append(Goal(
                    name: template.name, colorData: template.colorData, icon: template.icon,
                    items: [],
                    healthKitIdentifier: template.id,
                    healthKitTarget: template.defaultTarget,
                    healthKitUnit: template.unitLabel
                ))
                addedIDs.insert(template.id)
                showFlash(template.name)
            }
        } label: {
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
                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(alreadyAdded ? template.colorData.value : .white.opacity(0.25))
                    .font(.system(size: 20))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(alreadyAdded
                          ? template.colorData.value.opacity(0.12)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(alreadyAdded ? template.colorData.value.opacity(0.4) : Color.clear,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: alreadyAdded)
    }

    // MARK: Custom tab

    private var customTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                fieldLabel("Goal name")
                TextField("e.g. Morning Routine", text: $customName)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                fieldLabel("Color")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Self.colorPalette.indices, id: \.self) { i in
                            Circle()
                                .fill(Self.colorPalette[i].value)
                                .frame(width: 34, height: 34)
                                .overlay(Circle()
                                    .stroke(.white.opacity(customColorIdx == i ? 0.9 : 0),
                                            lineWidth: 2.5)
                                    .padding(-3))
                                .onTapGesture { customColorIdx = i }
                                .animation(.spring(response: 0.25), value: customColorIdx)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                fieldLabel("Icon")
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

                let canAdd = !customName.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    let trimmed = customName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.goals.append(
                        Goal(name: trimmed,
                             colorData: Self.colorPalette[customColorIdx],
                             icon: customIcon, items: [])
                    )
                    showFlash(trimmed)
                    customName = ""
                } label: {
                    Label("Add goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canAdd ? .white : .white.opacity(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            canAdd
                                ? Self.colorPalette[customColorIdx].value.opacity(0.28)
                                : Color.white.opacity(0.06),
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
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func centeredNote(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
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
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.white.opacity(0.1), in: Capsule())
        .padding(.bottom, 4)
    }
}

// MARK: - Add Life Goal

private struct AddLifeContent: View {
    @EnvironmentObject private var store: DataStore

    private enum Tab: String, CaseIterable {
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

    @State private var tab: Tab              = .suggestions
    @State private var addedIDs              = Set<String>()
    @State private var preExistingNames      = Set<String>()
    @State private var customName            = ""
    @State private var customIcon            = "star.fill"
    @State private var customColorIdx        = 0
    @State private var flash: String?        = nil

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.bottom, 12)

            Group {
                if tab == .suggestions { suggestionsTab }
                else                   { customTab }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)
            .frame(maxHeight: .infinity)

            if let name = flash {
                flashBanner(name)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            preExistingNames = Set(store.lifeGoals.map { $0.name })
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
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
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func lifeGoalCard(_ sg: SuggestedLifeGoal) -> some View {
        let isPreExisting  = preExistingNames.contains(sg.name)
        let isSessionAdded = addedIDs.contains(sg.name)
        let alreadyAdded   = isPreExisting || isSessionAdded
        let kindLabel: String = {
            switch sg.kind {
            case .metric: return "Metric"
            case .project(let s): return "\(s.count) milestones"
            }
        }()

        Button {
            if isSessionAdded {
                store.lifeGoals.removeAll { $0.name == sg.name }
                addedIDs.remove(sg.name)
            } else if !isPreExisting {
                store.lifeGoals.append(sg.toLifeGoal())
                addedIDs.insert(sg.name)
                showFlash(sg.name)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: sg.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(sg.colorData.value)
                    Spacer()
                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(alreadyAdded ? sg.colorData.value : .white.opacity(0.25))
                        .font(.system(size: 16))
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
                    .fill(alreadyAdded ? sg.colorData.value.opacity(0.18) : Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(alreadyAdded ? sg.colorData.value.opacity(0.5) : Color.clear,
                                lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: alreadyAdded)
    }

    // MARK: Custom

    private var customTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                fieldLabel("Goal name")
                TextField("e.g. Build my dream home", text: $customName)
                    .font(.system(size: 15)).foregroundStyle(.white).tint(.white)
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                fieldLabel("Color")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Self.colorPalette.indices, id: \.self) { i in
                            Circle().fill(Self.colorPalette[i].value).frame(width: 34, height: 34)
                                .overlay(Circle()
                                    .stroke(.white.opacity(customColorIdx == i ? 0.9 : 0),
                                            lineWidth: 2.5)
                                    .padding(-3))
                                .onTapGesture { customColorIdx = i }
                                .animation(.spring(response: 0.25), value: customColorIdx)
                        }
                    }.padding(.horizontal, 2)
                }

                fieldLabel("Icon")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(Self.iconOptions, id: \.self) { sym in
                        Button { customIcon = sym } label: {
                            Image(systemName: sym).font(.system(size: 17))
                                .foregroundStyle(customIcon == sym
                                                 ? Self.colorPalette[customColorIdx].value
                                                 : .white.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(customIcon == sym
                                          ? Self.colorPalette[customColorIdx].value.opacity(0.18)
                                          : Color.white.opacity(0.05)))
                        }.buttonStyle(.plain)
                    }
                }

                let canAdd = !customName.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    let trimmed = customName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.lifeGoals.append(
                        LifeGoal(name: trimmed,
                                 colorData: Self.colorPalette[customColorIdx],
                                 icon: customIcon, kind: .project([]))
                    )
                    showFlash(trimmed)
                    customName = ""
                } label: {
                    Label("Add life goal", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canAdd ? .white : .white.opacity(0.25))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(
                            canAdd
                                ? Self.colorPalette[customColorIdx].value.opacity(0.28)
                                : Color.white.opacity(0.06),
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
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.white.opacity(0.1), in: Capsule())
        .padding(.bottom, 4)
    }
}
