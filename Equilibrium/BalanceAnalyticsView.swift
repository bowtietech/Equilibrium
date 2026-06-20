import SwiftUI
import Charts

// MARK: - BalanceAnalyticsView

struct BalanceAnalyticsView: View {
    @EnvironmentObject private var store:  DataStore
    @EnvironmentObject private var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    let initialMode: AppMode

    @State private var mode:  AppMode
    @State private var range: HistoryRange = .month

    enum HistoryRange: String, CaseIterable {
        case week    = "7D"
        case month   = "30D"
        case quarter = "90D"
        case all     = "All"

        func cutoff(from now: Date) -> Date? {
            guard let days = days else { return nil }
            return Calendar.current.date(byAdding: .day, value: -days, to: now)
        }
        private var days: Int? {
            switch self { case .week: 7; case .month: 30; case .quarter: 90; case .all: nil }
        }
    }

    init(initialMode: AppMode) {
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        modePicker
                        rangeSelector

                        if mode == .daily {
                            dailyContent
                        } else {
                            lifeContent
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                }
            }
        }
    }

    // MARK: - Mode + Range Controls

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(AppMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.3)) { mode = m }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon).font(.system(size: 11))
                        Text(m.rawValue).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(mode == m ? 1 : 0.4))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(mode == m ? Color.appRowFill : .clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.appRowFill.opacity(0.5))
        .clipShape(Capsule())
    }

    private var rangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(HistoryRange.allCases, id: \.self) { r in
                Button {
                    withAnimation(.spring(response: 0.25)) { range = r }
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(range == r ? Color.primary : Color.primary.opacity(0.35))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(range == r ? Color.appRowFill : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Daily Content

    private var dailyContent: some View {
        let history = filtered(store.dailyBalanceHistory)
        let avgScore = history.isEmpty ? 0 : history.map(\.score).reduce(0,+) / Double(history.count)

        return VStack(spacing: 24) {
            // Summary header
            summaryHeader(score: avgScore,
                          label: history.isEmpty ? "No history yet" : avgLabel(history),
                          caption: "avg daily balance")

            // Balance over time chart
            if history.count >= 2 {
                chartCard(title: "Daily Balance") {
                    balanceChart(history, color: .cyan)
                }
            } else {
                emptyChart("Track your balance daily to see trends here")
            }

            // Per-goal breakdown
            let active = store.goals.filter(\.isActive)
            if !active.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Goals Today")
                    ForEach(active) { goal in
                        let p: Double = goal.isHealthBacked
                            ? (health.progressById[goal.id] ?? 0)
                            : (goal.todayProgress ?? 0)
                        goalRow(goal.name, icon: goal.icon,
                                color: goal.color, progress: p)
                    }
                }
            }
        }
    }

    // MARK: - Life Content

    private var lifeContent: some View {
        let history = filtered(store.lifeBalanceHistory)
        let active  = store.lifeGoals.filter(\.isActive)
        let avg     = history.isEmpty ? 0 : history.map(\.score).reduce(0,+) / Double(history.count)

        return VStack(spacing: 24) {
            summaryHeader(score: avg,
                          label: history.isEmpty ? "No history yet" : avgLabel(history),
                          caption: "avg life progress")

            if history.count >= 2 {
                chartCard(title: "Life Balance") {
                    balanceChart(history, color: .purple)
                }
            } else {
                emptyChart("Track your life goals to see trends here")
            }

            // Per-metric-goal sparklines
            let metricGoals = active.filter {
                if case .metric(let d) = $0.kind { return d.history.count >= 2 }
                return false
            }

            if !metricGoals.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Metric Goals")
                    ForEach(metricGoals) { goal in
                        if case .metric(let data) = goal.kind {
                            metricGoalCard(goal: goal, data: data)
                        }
                    }
                }
            }

            // Project goals completion
            let projectGoals = active.filter {
                if case .project = $0.kind { return true }
                return false
            }

            if !projectGoals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Project Goals")
                    ForEach(projectGoals) { goal in
                        goalRow(goal.name, icon: goal.icon,
                                color: goal.color, progress: goal.progress)
                    }
                }
            }
        }
    }

    // MARK: - Reusable Chart Components

    @ViewBuilder
    private func balanceChart(_ history: [BalanceEntry], color: Color) -> some View {
        Chart {
            ForEach(history) { entry in
                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Balance", entry.score * 100)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Balance", entry.score * 100)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Balance", entry.score * 100)
                )
                .foregroundStyle(color)
                .symbolSize(history.count > 20 ? 0 : 30)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(.primary.opacity(0.1))
                AxisValueLabel {
                    Text("\(val.as(Int.self) ?? 0)%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.28))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(.primary.opacity(0.08))
                AxisValueLabel(format: xAxisFormat, centered: false)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.28))
            }
        }
        .frame(height: 160)
    }

    @ViewBuilder
    private func metricGoalCard(goal: LifeGoal, data: MetricData) -> some View {
        let hist = filtered(data.history.map { BalanceEntry(date: $0.date, score: normalised($0.value, data: data)) })
        let current = data.currentValue
        let target  = data.targetValue

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: goal.icon)
                    .foregroundStyle(goal.color)
                    .font(.system(size: 13))
                Text(goal.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                Spacer()
                Text("\(formatted(current)) / \(formatted(target)) \(data.unit)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.35))
            }

            if hist.count >= 2 {
                Chart {
                    ForEach(hist) { e in
                        AreaMark(
                            x: .value("Date", e.date),
                            y: .value("Value", e.score * 100)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [goal.color.opacity(0.22), goal.color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", e.date),
                            y: .value("Value", e.score * 100)
                        )
                        .foregroundStyle(goal.color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks { AxisGridLine().foregroundStyle(.primary.opacity(0.06)) } }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { _ in
                        AxisValueLabel(format: xAxisFormat)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.24))
                    }
                }
                .frame(height: 90)
            }
        }
        .padding(14)
        .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Small Helpers

    @ViewBuilder
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.38))
            content()
        }
        .padding(16)
        .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func summaryHeader(score: Double, label: String, caption: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: score)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(score * 100))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                    Text("%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(scoreColor(score).opacity(0.7))
                }
                Text(caption)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.28))
            }
            Spacer()
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.2))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func goalRow(_ name: String, icon: String, color: Color, progress: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14))
                .frame(width: 24)
            Text(name)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.8))
            Spacer()
            Text("\(Int(progress * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: g.size.width * CGFloat(progress))
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(width: 64, height: 6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(Color.appRowFill, in: RoundedRectangle(cornerRadius: 11))
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.35))
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func emptyChart(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 13, weight: .light))
            .foregroundStyle(.primary.opacity(0.28))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.appRowFill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data Helpers

    private func filtered(_ entries: [BalanceEntry]) -> [BalanceEntry] {
        guard let cutoff = range.cutoff(from: Date()) else { return entries }
        return entries.filter { $0.date >= cutoff }
    }

    private func filtered(_ entries: [MetricEntry]) -> [MetricEntry] {
        guard let cutoff = range.cutoff(from: Date()) else { return entries }
        return entries.filter { $0.date >= cutoff }
    }

    private func normalised(_ value: Double, data: MetricData) -> Double {
        guard data.targetValue != data.startValue else { return 0 }
        let raw = (value - data.startValue) / (data.targetValue - data.startValue)
        let clamped = max(0, min(1, raw))
        return data.direction == .lower ? 1 - clamped : clamped
    }

    private func formatted(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }

    private func avgLabel(_ h: [BalanceEntry]) -> String {
        guard let first = h.first, let last = h.last else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: first.date)) – \(f.string(from: last.date))"
    }

    private func scoreColor(_ s: Double) -> Color {
        s >= 0.7 ? .green : s >= 0.4 ? .orange : .red
    }

    // Sensible x-axis stride + format for the selected range
    private var xAxisStride: Calendar.Component {
        switch range { case .week: .day; case .month: .weekOfYear; default: .month }
    }
    private var xAxisFormat: Date.FormatStyle {
        switch range {
        case .week:    .dateTime.day().month(.abbreviated)
        case .month:   .dateTime.day().month(.abbreviated)
        default:       .dateTime.month(.abbreviated)
        }
    }
}
