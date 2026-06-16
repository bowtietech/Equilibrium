import SwiftUI

// MARK: - Entry point

struct LifeGoalDetailView: View {
    @Binding var goal: LifeGoal

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()
            VStack {
                RadialGradient(
                    colors: [goal.color.opacity(0.18), .clear],
                    center: .top, startRadius: 0, endRadius: 280
                )
                .frame(height: 300).ignoresSafeArea()
                Spacer()
            }

            switch goal.kind {
            case .metric(let data):
                MetricGoalDetail(goal: $goal, data: data)
            case .project(let subs):
                ProjectGoalDetail(goal: $goal, subgoals: subs)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Metric Detail

private struct MetricGoalDetail: View {
    @Binding var goal: LifeGoal
    let data: MetricData

    @State private var showingLog  = false
    @State private var logText     = ""

    private var metricBinding: Binding<MetricData> {
        Binding(
            get: { if case .metric(let m) = goal.kind { return m } else { return data } },
            set: { goal.kind = .metric($0) }
        )
    }

    var body: some View {
        List {
            // Header
            Section {
                headerView.listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            // Chart
            Section {
                SparklineChart(entries: data.history,
                               color: goal.color,
                               direction: data.direction)
                    .frame(height: 140)
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparator(.hidden)
            } header: {
                sectionHeader("Progress over time")
            }
            // History entries
            Section {
                ForEach(data.history.reversed()) { entry in
                    HStack {
                        Text(dateLabel(entry.date))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("\(data.unitPrefix)\(data.formatted(entry.value))\(data.unit)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(goal.color.opacity(0.9))
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(.white.opacity(0.07))
                }
            } header: {
                sectionHeader("History")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingLog = true } label: {
                    Label("Log", systemImage: "plus.circle")
                        .foregroundStyle(goal.color)
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            logSheet
        }
    }

    private var headerView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(goal.color.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: data.progress)
                    .stroke(goal.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: data.progress)
                Image(systemName: goal.icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(goal.color)
            }
            .frame(width: 110, height: 110)

            VStack(spacing: 6) {
                Text(goal.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(goal.color)

                HStack(spacing: 12) {
                    metricPill(label: "Current", value: data.currentLabel)
                    Image(systemName: data.direction == .lower ? "arrow.down" : "arrow.up")
                        .font(.system(size: 12))
                        .foregroundStyle(goal.color.opacity(0.6))
                    metricPill(label: "Target",  value: data.targetLabel)
                }

                Text("\(Int(data.progress * 100))% of the way there")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func metricPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var logSheet: some View {
        VStack(spacing: 20) {
            Capsule().fill(.white.opacity(0.2))
                .frame(width: 36, height: 4).padding(.top, 8)

            Text("Log \(goal.name)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current value (\(data.unit.trimmingCharacters(in: .whitespaces)))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                TextField(data.currentLabel, text: $logText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(goal.color)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Save Entry") {
                if let val = Double(logText) {
                    var updated = metricBinding.wrappedValue
                    updated.currentValue = val
                    updated.history.append(MetricEntry(date: Date(), value: val))
                    metricBinding.wrappedValue = updated
                }
                logText = ""
                showingLog = false
            }
            .disabled(Double(logText) == nil)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Double(logText) != nil ? goal.color : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(goal.color.opacity(Double(logText) != nil ? 0.15 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 13))

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(300)])
        .presentationBackground(Color(red: 0.08, green: 0.08, blue: 0.13))
        .presentationCornerRadius(24)
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - Sparkline Chart

private struct SparklineChart: View {
    let entries: [MetricEntry]
    let color: Color
    let direction: MetricDirection

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let values = entries.map(\.value)
            guard let minV = values.min(), let maxV = values.max(), maxV > minV else {
                return AnyView(Color.clear)
            }
            let pts = entries.enumerated().map { i, e -> CGPoint in
                let x = w * CGFloat(i) / CGFloat(max(entries.count - 1, 1))
                let y = h * (1 - CGFloat((e.value - minV) / (maxV - minV)))
                return CGPoint(x: x, y: y)
            }
            return AnyView(
                ZStack(alignment: .bottomLeading) {
                    // Fill gradient under line
                    Canvas { ctx, _ in
                        var fill = Path()
                        if let first = pts.first {
                            fill.move(to: CGPoint(x: first.x, y: h))
                            fill.addLine(to: first)
                            pts.dropFirst().forEach { fill.addLine(to: $0) }
                            if let last = pts.last {
                                fill.addLine(to: CGPoint(x: last.x, y: h))
                            }
                            fill.closeSubpath()
                        }
                        ctx.fill(fill, with: .color(color.opacity(0.12)))
                    }

                    // Line
                    Canvas { ctx, _ in
                        var line = Path()
                        if let first = pts.first {
                            line.move(to: first)
                            pts.dropFirst().forEach { line.addLine(to: $0) }
                        }
                        ctx.stroke(line, with: .color(color),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }

                    // Dot on latest
                    if let last = pts.last {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .offset(x: last.x - 4, y: last.y - 4)
                    }
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Project Detail

private struct ProjectGoalDetail: View {
    @Binding var goal: LifeGoal
    let subgoals: [SubGoal]

    @State private var expandedIDs = Set<UUID>()
    @State private var showingAdd  = false
    @State private var addParentID: UUID? = nil
    @State private var newName     = ""

    private var subgoalBinding: Binding<[SubGoal]> {
        Binding(
            get: { if case .project(let s) = goal.kind { return s } else { return [] } },
            set: { goal.kind = .project($0) }
        )
    }

    var body: some View {
        List {
            // Header
            Section {
                projectHeader.listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            // Sub-goals
            Section {
                ForEach(subgoalBinding) { $parent in
                    SubGoalSection(
                        subgoal: $parent,
                        color: goal.color,
                        expandedIDs: $expandedIDs,
                        onAddChild: {
                            addParentID = parent.id
                            showingAdd  = true
                        }
                    )
                    .listRowBackground(Color.white.opacity(0.05))
                    .listRowSeparatorTint(.white.opacity(0.07))
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .onDelete { subgoalBinding.wrappedValue.remove(atOffsets: $0) }
            } header: {
                sectionHeader("Areas")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addParentID = nil; showingAdd = true } label: {
                    Label("Add Area", systemImage: "plus.circle")
                        .foregroundStyle(goal.color)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { addSheet }
    }

    private var projectHeader: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(goal.color.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(goal.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: goal.progress)
                Image(systemName: goal.icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(goal.color)
            }
            .frame(width: 110, height: 110)

            VStack(spacing: 6) {
                Text(goal.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(goal.color)
                let done  = subgoals.filter { $0.progress >= 1.0 }.count
                Text("\(done) of \(subgoals.count) areas complete · \(Int(goal.progress * 100))%")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var addSheet: some View {
        let isChild = addParentID != nil
        let title   = isChild ? "Add Sub-Goal" : "Add Area"
        return VStack(spacing: 20) {
            Capsule().fill(.white.opacity(0.2))
                .frame(width: 36, height: 4).padding(.top, 8)
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            TextField("Name", text: $newName)
                .textFieldStyle(.plain).font(.system(size: 16))
                .foregroundStyle(.white).tint(goal.color)
                .padding().background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Add") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                withAnimation(.spring(response: 0.3)) {
                    if let pid = addParentID {
                        if let idx = subgoalBinding.wrappedValue.firstIndex(where: { $0.id == pid }) {
                            subgoalBinding.wrappedValue[idx].children.append(SubGoal(name: trimmed))
                        }
                    } else {
                        subgoalBinding.wrappedValue.append(SubGoal(name: trimmed))
                    }
                }
                newName = ""; showingAdd = false
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(newName.isEmpty ? .white.opacity(0.3) : goal.color)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(goal.color.opacity(newName.isEmpty ? 0.06 : 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(260)])
        .presentationBackground(Color(red: 0.08, green: 0.08, blue: 0.13))
        .presentationCornerRadius(24)
    }
}

// MARK: - SubGoal Section (expandable, 2 levels shown)

private struct SubGoalSection: View {
    @Binding var subgoal: SubGoal
    let color: Color
    @Binding var expandedIDs: Set<UUID>
    let onAddChild: () -> Void

    private var isExpanded: Bool { expandedIDs.contains(subgoal.id) }

    var body: some View {
        VStack(spacing: 0) {
            // Parent row
            HStack(spacing: 14) {
                // Mini ring
                ZStack {
                    Circle().stroke(color.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: subgoal.progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4), value: subgoal.progress)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subgoal.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    let done  = subgoal.children.filter { $0.isComplete }.count
                    let total = subgoal.children.count
                    if total > 0 {
                        Text("\(done)/\(total) · \(Int(subgoal.progress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(color.opacity(0.6))
                    }
                }

                Spacer()

                // Add child button
                Button(action: onAddChild) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Expand toggle
                if !subgoal.children.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.28)) {
                            if isExpanded { expandedIDs.remove(subgoal.id) }
                            else          { expandedIDs.insert(subgoal.id) }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Children
            if isExpanded {
                ForEach($subgoal.children) { $child in
                    HStack(spacing: 14) {
                        // Indent line
                        Rectangle()
                            .fill(color.opacity(0.25))
                            .frame(width: 1)
                            .padding(.leading, 22)

                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                child.isComplete.toggle()
                            }
                        } label: {
                            Image(systemName: child.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(child.isComplete ? color : .white.opacity(0.28))
                                .animation(.spring(response: 0.2), value: child.isComplete)
                        }
                        .buttonStyle(.plain)

                        Text(child.name)
                            .font(.system(size: 14))
                            .foregroundStyle(child.isComplete ? .white.opacity(0.35) : .white.opacity(0.85))
                            .strikethrough(child.isComplete, color: .white.opacity(0.2))

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.trailing, 16)
                    .background(Color.white.opacity(0.03))
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal:   .opacity
                    ))
                }
            }
        }
    }
}

// MARK: - Shared helpers

private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.3))
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 0))
}

#Preview {
    NavigationStack {
        LifeGoalDetailView(goal: .constant(LifeGoal.demos[2]))
    }
}
