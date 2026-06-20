import SwiftUI

enum AppMode: String, CaseIterable {
    case daily = "Daily"
    case life  = "Life Goals"

    var icon: String {
        switch self {
        case .daily: return "calendar"
        case .life:  return "star"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store:  DataStore
    @EnvironmentObject private var health: HealthKitManager

    @Environment(\.scenePhase) private var scenePhase

    @State private var mode             = AppMode.daily
    @State private var activeIndex      = 0
    @State private var navigateToDetail = false
    @State private var showProfile      = false
    @State private var showHealthImport = false
    @State private var showAddGoal      = false
    @State private var showAnalytics    = false
    @State private var selectedDate     = Calendar.current.startOfDay(for: Date())
    @State private var weekOffset       = 0   // weeks relative to current week

    @AppStorage("profile_name")        private var profileName: String = ""
    @AppStorage("profile_avatar_col")  private var profileColorIdx: Int = 0

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var entries: [WheelEntry] {
        switch mode {
        case .daily:
            return store.goals
                .filter { $0.isActive && ($0.items.isEmpty || $0.items.contains { $0.isActive(on: selectedDate) }) }
                .map { goal in
                    goal.wheelEntry(on: selectedDate,
                                    healthProgress: isToday ? health.progressById[goal.id] : nil)
                }
        case .life:
            return store.lifeGoals.filter(\.isActive).map(\.wheelEntry)
        }
    }

    private var active: WheelEntry {
        guard !entries.isEmpty else {
            return WheelEntry(id: UUID(), name: "", color: .primary, icon: "circle", progress: 0)
        }
        return entries[min(activeIndex, entries.count - 1)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 0) {
                    appLabel
                    modeSwitcher
                    if mode == .daily { dayStrip }
                    Spacer()
                    goalInfo
                    wheelArea

                    Spacer()
                    scoreCard
                }
                AIAssistantOverlay()
            }
            //.preferredColorScheme(.dark) — handled by RootView
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToDetail) {
                detailDestination
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                balanceScore: computedDailyBalance,
                dailyGoalCount: store.goals.count,
                lifeGoalCount: store.lifeGoals.count,
                showHealthImport: $showHealthImport
            )
        }
        .sheet(isPresented: $showHealthImport) {
            HealthImportView()
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(mode: mode)
        }
        .sheet(isPresented: $showAnalytics) {
            BalanceAnalyticsView(initialMode: mode)
                .environmentObject(store)
                .environmentObject(health)
        }
        .onChange(of: mode) { _, newMode in
            let count = newMode == .daily ? store.goals.count : store.lifeGoals.count
            withAnimation(.spring(response: 0.4)) {
                activeIndex = count > 0 ? 0 : 0   // always reset; guard in detailDestination handles empty
            }
            navigateToDetail = false
        }
        .task {
            await health.refresh(goals: store.goals)
            await applyLifeGoalHealthUpdates()
            store.recordBalance(daily: computedDailyBalance, life: computedLifeBalance)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await health.refresh(goals: store.goals)
                    await applyLifeGoalHealthUpdates()
                    store.recordBalance(daily: computedDailyBalance, life: computedLifeBalance)
                }
            }
        }
        .onChange(of: store.goals) { old, new in
            let prevActive = old.filter(\.isActive).count
            let nextActive = new.filter(\.isActive).count
            if mode == .daily {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    if nextActive > prevActive {
                        // Goal added or re-activated — jump to it (it's last in the active list)
                        activeIndex = max(0, nextActive - 1)
                    } else if activeIndex >= nextActive {
                        activeIndex = max(0, nextActive - 1)
                    }
                }
            }
            Task {
                await health.refresh(goals: new)
                store.recordBalance(daily: computedDailyBalance, life: computedLifeBalance)
            }
        }
        .onChange(of: store.lifeGoals) { old, new in
            let prevActive = old.filter(\.isActive).count
            let nextActive = new.filter(\.isActive).count
            if mode == .life {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    if nextActive > prevActive {
                        activeIndex = max(0, nextActive - 1)
                    } else if activeIndex >= nextActive {
                        activeIndex = max(0, nextActive - 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailDestination: some View {
        switch mode {
        case .daily:
            // activeIndex indexes into the active-filtered list; map back to store array
            let activeGoals = store.goals.indices.filter { store.goals[$0].isActive }
            if activeGoals.indices.contains(activeIndex),
               store.goals.indices.contains(activeGoals[activeIndex]) {
                GoalDetailView(goal: $store.goals[activeGoals[activeIndex]])
            }
        case .life:
            let activeLife = store.lifeGoals.indices.filter { store.lifeGoals[$0].isActive }
            if activeLife.indices.contains(activeIndex),
               store.lifeGoals.indices.contains(activeLife[activeIndex]) {
                LifeGoalDetailView(goal: $store.lifeGoals[activeLife[activeIndex]])
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.appBg
            RadialGradient(
                colors: [active.color.opacity(0.11), .clear],
                center: .center, startRadius: 0, endRadius: 320
            )
            .animation(.easeInOut(duration: 0.5), value: activeIndex)
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var appLabel: some View {
        HStack {
            Text("equilibrium")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.28))

            Spacer()

            HStack(spacing: 10) {
                Button { showAddGoal = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(Color.appRowFill.opacity(1.5), in: Circle())
                }
                .buttonStyle(.plain)

                Button { showProfile = true } label: {
                    let col = ProfileView.palette[profileColorIdx]
                    ZStack {
                        Circle()
                            .fill(col.gradient)
                            .frame(width: 32, height: 32)
                            .shadow(color: col.opacity(0.4), radius: 8)
                        if profileName.isEmpty {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(.primary.opacity(0.6))
                        } else {
                            let words = profileName.trimmingCharacters(in: .whitespaces).split(separator: " ")
                            let ini: String = words.count > 1
                                ? (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
                                : String(words.first?.prefix(2) ?? "").uppercased()
                            Text(ini)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.35), value: profileColorIdx)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Day strip

    private var dayStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Build 7 days for the displayed week
        let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset,
                                 to: cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!)!
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }

        return VStack(spacing: 4) {
            // Day chips row — swipeable
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                    let isT        = cal.isDateInToday(day)
                    let hasTasks   = store.goals.filter(\.isActive).contains {
                            !$0.items.isEmpty && $0.items.contains { $0.isActive(on: day) }
                        }
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedDate = day }
                    } label: {
                        VStack(spacing: 2) {
                            Text(dayAbbrev(day))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(isSelected ? 1.0 : 0.4))
                            Text(dayNumber(day))
                                .font(.system(size: 14, weight: isSelected || isT ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.primary
                                                 : isT ? Color.accentColor
                                                 : Color.primary.opacity(0.55))
                            Circle()
                                .fill(hasTasks
                                      ? (isSelected ? Color.primary : Color.accentColor.opacity(0.6))
                                      : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.appRowFill : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) else { return }
                        let feedback = UIImpactFeedbackGenerator(style: .light)
                        feedback.impactOccurred()
                        withAnimation(.spring(response: 0.3)) {
                            if dx < 0 { weekOffset += 1 } else { weekOffset -= 1 }
                        }
                    }
            )

            // "Today" pill — shown when not on current week
            if weekOffset != 0 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        weekOffset   = 0
                        selectedDate = today
                    }
                } label: {
                    Text("Back to Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.spring(response: 0.3), value: weekOffset)
    }

    private func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }
    private func dayStrip_label(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d"
        return f.string(from: date)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(AppMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        mode = m
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 12))
                        Text(m.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(mode == m ? 1.0 : 0.4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(mode == m ? Color.appRowFill.opacity(2) : .clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.appRowFill)
        .clipShape(Capsule())
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    // MARK: - Score / Progress Card

    @ViewBuilder
    private var scoreCard: some View {
        switch mode {
        case .daily:  dailyScoreCard
        case .life:   lifeProgressCard
        }
    }

    /// Balance across all active daily goals for the selected date,
    /// incorporating live HealthKit values for health-backed goals.
    private var computedDailyBalance: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.progress).reduce(0, +) / Double(entries.count)
    }

    private var computedLifeBalance: Double {
        let active = store.lifeGoals.filter(\.isActive)
        guard !active.isEmpty else { return 0 }
        return active.map(\.progress).reduce(0, +) / Double(active.count)
    }

    private var dailyScoreCard: some View {
        let score = computedDailyBalance
        return HStack(spacing: 14) {
            ringView(progress: score, color: scoreColor(score))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(score * 100))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: Int(score * 100))
                    Text("%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(scoreColor(score).opacity(0.7))
                }
                Text("today's balance")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.28))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.18))
                Text(todayLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.2))
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture { showAnalytics = true }
    }

    private var lifeProgressCard: some View {
        let score = computedLifeBalance
        return HStack(spacing: 14) {
            ringView(progress: score, color: scoreColor(score))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(score * 100))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: Int(score * 100))
                    Text("%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(scoreColor(score).opacity(0.7))
                }
                Text("overall life progress")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.28))
            }

            Spacer()

            // Life goal type breakdown
            let metricCount  = store.lifeGoals.filter { if case .metric  = $0.kind { return true }; return false }.count
            let projectCount = store.lifeGoals.filter { if case .project = $0.kind { return true }; return false }.count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(metricCount) metric")
                Text("\(projectCount) project")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.2))
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture { showAnalytics = true }
    }

    // MARK: - Goal Info

    private var goalInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: active.icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(active.color)
                Text(active.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(active.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .id("name-\(mode)-\(activeIndex)")
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.88)),
                removal:   .opacity.combined(with: .scale(scale: 1.06))
            ))

            progressSubtitle
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: activeIndex)
        .frame(height: 88)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !entries.isEmpty else { return }
            navigateToDetail = true
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard entries.count > 1 else { return }
                    let dx = value.translation.width
                    guard abs(dx) > abs(value.translation.height) else { return }
                    let feedback = UIImpactFeedbackGenerator(style: .light)
                    feedback.impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        if dx < 0 {
                            activeIndex = (activeIndex + 1) % entries.count
                        } else {
                            activeIndex = (activeIndex - 1 + entries.count) % entries.count
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private var progressSubtitle: some View {
        let activeDaily = store.goals.filter(\.isActive)
        let activeLife  = store.lifeGoals.filter(\.isActive)
        switch mode {
        case .daily:
            if activeDaily.isEmpty {
                Text("no goals on wheel")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.25))
            } else {
                let visibleGoals = store.goals.filter { $0.isActive && ($0.items.isEmpty || $0.items.contains { $0.isActive(on: selectedDate) }) }
                if visibleGoals.isEmpty {
                    Text("no goals scheduled")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.25))
                } else {
                    let g = visibleGoals[min(activeIndex, visibleGoals.count - 1)]
                    if isToday, g.isHealthBacked, let p = health.progressById[g.id] {
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.45))
                    } else if let p = g.progress(on: selectedDate) {
                        let dayLabel = isToday ? "today" : dayStrip_label(selectedDate)
                        Text("\(Int(p * 100))% · \(dayLabel)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.45))
                    } else {
                        Text("nothing scheduled")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                }
            }
        case .life:
            if activeLife.isEmpty {
                Text("no life goals on wheel")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.25))
            } else {
                let lg = activeLife[min(activeIndex, activeLife.count - 1)]
                switch lg.kind {
                case .metric(let m):
                    Text("\(m.currentLabel) → \(m.targetLabel)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.45))
                case .project(let sgs):
                    let done = sgs.filter { $0.progress >= 1.0 }.count
                    Text("\(done)/\(sgs.count) areas complete")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.45))
                }
            }
        }
    }

    // MARK: - Wheel

    private var wheelArea: some View {
        GoalWheelView(goals: entries, activeIndex: $activeIndex, onActiveTap: {
            navigateToDetail = true
        })
        .frame(maxWidth: .infinity)
        .frame(height: 400)
    }

    private var hint: some View {
        Text("drag to spin  ·  tap to select  ·  tap active to open")
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.16))
            .padding(.top, 8)
            .padding(.bottom, 20)
    }

    // MARK: - Helpers

    /// Fetches the latest HealthKit value for every health-backed life goal and
    /// updates `store.lifeGoals[n].kind.metric.currentValue` (plus appends to history
    /// once per day).
    @MainActor
    private func applyLifeGoalHealthUpdates() async {
        let updates = await health.latestLifeGoalValues(for: store.lifeGoals)
        guard !updates.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())
        for (id, value) in updates {
            guard let idx = store.lifeGoals.firstIndex(where: { $0.id == id }),
                  case .metric(var data) = store.lifeGoals[idx].kind
            else { continue }
            data.currentValue = value
            let lastDay = data.history.last.map { Calendar.current.startOfDay(for: $0.date) }
            if lastDay != today {
                data.history.append(MetricEntry(date: Date(), value: value))
            }
            store.lifeGoals[idx].kind = .metric(data)
        }
    }

    private func ringView(progress: Double, color: Color) -> some View {
        ZStack {
            Circle().stroke(Color.appSeparator, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
        }
    }

    private func scoreColor(_ s: Double) -> Color {
        if s < 0.4 { return Color(red: 1.0, green: 0.40, blue: 0.40) }
        if s < 0.7 { return Color(red: 1.0, green: 0.76, blue: 0.22) }
        return Color(red: 0.28, green: 0.88, blue: 0.54)
    }

    private var todayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"
        return f.string(from: Date())
    }
}

// MARK: - Card style helper

private extension View {
    func cardStyle() -> some View {
        self
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.appRowFill)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.top, 10)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore())
        .environmentObject(AuthManager())
}
