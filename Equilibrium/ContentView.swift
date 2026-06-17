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

    @AppStorage("profile_name")        private var profileName: String = ""
    @AppStorage("profile_avatar_col")  private var profileColorIdx: Int = 0

    private var entries: [WheelEntry] {
        switch mode {
        case .daily:
            return store.goals.map { goal in
                goal.wheelEntry(healthProgress: health.progressById[goal.id])
            }
        case .life:
            return store.lifeGoals.map(\.wheelEntry)
        }
    }

    private var active: WheelEntry {
        guard !entries.isEmpty else {
            return WheelEntry(id: UUID(), name: "", color: .white, icon: "circle", progress: 0)
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
                    Spacer()
                    goalInfo
                    wheelArea
                    hint
                    Spacer()
                    scoreCard
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToDetail) {
                detailDestination
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                balanceScore: store.goals.balanceScore,
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
        .onChange(of: mode) { _, newMode in
            let count = newMode == .daily ? store.goals.count : store.lifeGoals.count
            withAnimation(.spring(response: 0.4)) {
                activeIndex = count > 0 ? 0 : 0   // always reset; guard in detailDestination handles empty
            }
            navigateToDetail = false
        }
        .task { await health.refresh(goals: store.goals) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await health.refresh(goals: store.goals) } }
        }
        .onChange(of: store.goals) { _, goals in
            Task { await health.refresh(goals: goals) }
        }
    }

    @ViewBuilder
    private var detailDestination: some View {
        switch mode {
        case .daily:
            if store.goals.indices.contains(activeIndex) {
                GoalDetailView(goal: $store.goals[activeIndex])
            }
        case .life:
            if store.lifeGoals.indices.contains(activeIndex) {
                LifeGoalDetailView(goal: $store.lifeGoals[activeIndex])
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
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
                .foregroundStyle(.white.opacity(0.28))

            Spacer()

            HStack(spacing: 10) {
                Button { showAddGoal = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.09), in: Circle())
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
                                .foregroundStyle(.white.opacity(0.6))
                        } else {
                            let words = profileName.trimmingCharacters(in: .whitespaces).split(separator: " ")
                            let ini: String = words.count > 1
                                ? (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
                                : String(words.first?.prefix(2) ?? "").uppercased()
                            Text(ini)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
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
                    .foregroundStyle(mode == m ? .white : .white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(mode == m ? Color.white.opacity(0.12) : .clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
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

    private var dailyScoreCard: some View {
        let score = store.goals.balanceScore
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
                    .foregroundStyle(.white.opacity(0.28))
            }

            Spacer()

            Text(todayLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
        }
        .cardStyle()
    }

    private var lifeProgressCard: some View {
        let score = store.lifeGoals.map(\.progress).reduce(0, +) / max(1, Double(store.lifeGoals.count))
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
                    .foregroundStyle(.white.opacity(0.28))
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
            .foregroundStyle(.white.opacity(0.2))
        }
        .cardStyle()
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
    }

    @ViewBuilder
    private var progressSubtitle: some View {
        switch mode {
        case .daily:
            if store.goals.isEmpty {
                Text("no goals set")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            } else {
                let g = store.goals[min(activeIndex, store.goals.count - 1)]
                if let tp = g.todayProgress {
                    Text("\(Int(tp * 100))% today")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text("no goals today")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
        case .life:
            if store.lifeGoals.isEmpty {
                Text("no life goals set")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            } else {
                let lg = store.lifeGoals[min(activeIndex, store.lifeGoals.count - 1)]
                switch lg.kind {
                case .metric(let m):
                    Text("\(m.currentLabel) → \(m.targetLabel)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                case .project(let sgs):
                    let done = sgs.filter { $0.progress >= 1.0 }.count
                    Text("\(done)/\(sgs.count) areas complete")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
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
        .frame(height: 340)
    }

    private var hint: some View {
        Text("drag to spin  ·  tap to select  ·  tap active to open")
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundStyle(.white.opacity(0.16))
            .padding(.top, 8)
            .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func ringView(progress: Double, color: Color) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: 5)
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
            .background(.white.opacity(0.05))
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
