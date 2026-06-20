import SwiftUI

// MARK: - Entry point

struct LifeGoalDetailView: View {
    @Binding var goal: LifeGoal

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
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

    @State private var showingLog   = false
    @State private var logText      = ""
    @State private var editingTitle = false
    @State private var titleBuffer  = ""
    @FocusState private var titleFocused: Bool

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
                    .listRowBackground(Color.appRowFill.opacity(0.7))
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
                            .foregroundStyle(.primary.opacity(0.5))
                        Spacer()
                        Text("\(data.unitPrefix)\(data.formatted(entry.value))\(data.unit)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(goal.color.opacity(0.9))
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.appRowFill.opacity(0.7))
                    .listRowSeparatorTint(Color.appRowFill)
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
                if editingTitle {
                    HStack(spacing: 8) {
                        TextField("Goal name", text: $titleBuffer)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(goal.color)
                            .tint(goal.color)
                            .focused($titleFocused)
                            .onSubmit { commitTitle() }
                        Button("Done") { commitTitle() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(goal.color)
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text(goal.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(goal.color)
                        .onTapGesture {
                            titleBuffer = goal.name
                            editingTitle = true
                            titleFocused = true
                        }
                }

                HStack(spacing: 12) {
                    metricPill(label: "Current", value: data.currentLabel)
                    Image(systemName: data.direction == .lower ? "arrow.down" : "arrow.up")
                        .font(.system(size: 12))
                        .foregroundStyle(goal.color.opacity(0.6))
                    metricPill(label: "Target",  value: data.targetLabel)
                }

                Text("\(Int(data.progress * 100))% of the way there")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            if !editingTitle {
                Text("tap name to rename")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.15))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func commitTitle() {
        let t = titleBuffer.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { goal.name = t }
        titleFocused = false
        withAnimation { editingTitle = false }
    }

    private func metricPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.appRowFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var logSheet: some View {
        VStack(spacing: 20) {
            Capsule().fill(.primary.opacity(0.2))
                .frame(width: 36, height: 4).padding(.top, 8)

            Text("Log \(goal.name)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current value (\(data.unit.trimmingCharacters(in: .whitespaces)))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.4))

                TextField(data.currentLabel, text: $logText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .tint(goal.color)
                    .padding()
                    .background(Color.appRowFill)
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
            .foregroundStyle(Double(logText) != nil ? goal.color : .primary.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(goal.color.opacity(Double(logText) != nil ? 0.15 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 13))

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(300)])
        .presentationBackground(Color.appSurface)
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

    @State private var expandedIDs   = Set<UUID>()
    @State private var showingAdd    = false
    @State private var addParentID: UUID? = nil
    @State private var newName       = ""
    @State private var editingTitle  = false
    @State private var titleBuffer   = ""
    @State private var editingNodeID: UUID? = nil
    @State private var nodeBuffer    = ""
    @FocusState private var titleFocused: Bool
    @FocusState private var nodeFocused: Bool

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

            // Areas + their children as flat List rows so every level supports swipe-to-delete
            Section {
                ForEach(subgoalBinding) { $parent in
                    // ── Area (parent) row ──────────────────────────────────────────
                    areaRow($parent)
                        .listRowBackground(Color.appRowFill)
                        .listRowSeparatorTint(Color.appRowFill)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    subgoalBinding.wrappedValue.removeAll { $0.id == parent.id }
                                }
                            } label: { Label("Delete", systemImage: "trash") }
                        }

                    // ── Children (shown when area is expanded) ───────────────────
                    if expandedIDs.contains(parent.id) {
                        ForEach($parent.children) { $child in
                            childRow($child, color: goal.color)
                                .listRowBackground(Color.appRowFill.opacity(0.5))
                                .listRowSeparatorTint(Color.appRowFill)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            parent.children.removeAll { $0.id == child.id }
                                        }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                                .transition(.asymmetric(
                                    insertion: .push(from: .top).combined(with: .opacity),
                                    removal:   .opacity
                                ))
                        }
                    }
                }
            } header: {
                HStack {
                    sectionHeader("Areas")
                    Spacer()
                    Text("swipe to delete")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.18))
                        .textCase(nil)
                        .padding(.trailing, 20)
                }
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

    // MARK: Area row

    private func areaRow(_ parent: Binding<SubGoal>) -> some View {
        let sub        = parent.wrappedValue
        let isExpanded = expandedIDs.contains(sub.id)
        let hasChildren = !sub.children.isEmpty

        return HStack(spacing: 14) {
            // Checkbox — tapping completes/un-completes the area itself
            Button {
                withAnimation(.spring(response: 0.25)) {
                    parent.isComplete.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: sub.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(sub.isComplete ? goal.color : .primary.opacity(0.28))
                    .animation(.spring(response: 0.2), value: sub.isComplete)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if editingNodeID == sub.id {
                    HStack(spacing: 6) {
                        TextField("Area name", text: $nodeBuffer)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .tint(goal.color)
                            .focused($nodeFocused)
                            .onSubmit { commitNode(parent) }
                        Button("Done") { commitNode(parent) }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(goal.color)
                            .buttonStyle(.plain)
                    }
                } else {
                    Text(sub.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(sub.isComplete ? 0.4 : 0.9))
                        .strikethrough(sub.isComplete, color: .primary.opacity(0.2))
                        .onTapGesture {
                            nodeBuffer = sub.name
                            editingNodeID = sub.id
                            nodeFocused = true
                        }
                }
                if hasChildren {
                    let done  = sub.children.filter { $0.progress >= 1.0 }.count
                    let total = sub.children.count
                    Text("\(done)/\(total) · \(Int(sub.progress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(goal.color.opacity(0.6))
                }
            }

            Spacer()

            // Add sub-goal button
            Button {
                addParentID = sub.id
                showingAdd  = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(goal.color.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(goal.color.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Expand/collapse indicator
            if hasChildren {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.28), value: isExpanded)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasChildren, editingNodeID == nil else { return }
            withAnimation(.spring(response: 0.28)) {
                if isExpanded { expandedIDs.remove(sub.id) }
                else          { expandedIDs.insert(sub.id) }
            }
        }
    }

    private func commitNode(_ parent: Binding<SubGoal>) {
        nodeFocused = false
        let t = nodeBuffer.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { parent.wrappedValue.name = t }
        withAnimation { editingNodeID = nil }
    }

    // MARK: Child row

    private func childRow(_ child: Binding<SubGoal>, color: Color) -> some View {
        let c = child.wrappedValue
        return HStack(spacing: 12) {
            // Indent accent
            Rectangle()
                .fill(color.opacity(0.22))
                .frame(width: 2, height: 28)
                .padding(.leading, 24)

            Button {
                withAnimation(.spring(response: 0.25)) {
                    child.isComplete.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: c.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(c.isComplete ? color : .primary.opacity(0.28))
                    .animation(.spring(response: 0.2), value: c.isComplete)
            }
            .buttonStyle(.plain)

            if editingNodeID == c.id {
                HStack(spacing: 6) {
                    TextField("Sub-goal name", text: $nodeBuffer)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .tint(color)
                        .focused($nodeFocused)
                        .onSubmit { commitChildNode(child) }
                    Button("Done") { commitChildNode(child) }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                        .buttonStyle(.plain)
                }
            } else {
                Text(c.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(c.isComplete ? 0.35 : 0.82))
                    .strikethrough(c.isComplete, color: .primary.opacity(0.2))
                    .onTapGesture {
                        nodeBuffer = c.name
                        editingNodeID = c.id
                        nodeFocused = true
                    }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.trailing, 16)
        .contentShape(Rectangle())
    }

    private func commitChildNode(_ child: Binding<SubGoal>) {
        nodeFocused = false
        let t = nodeBuffer.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { child.wrappedValue.name = t }
        withAnimation { editingNodeID = nil }
    }

    // MARK: Header & Add sheet

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
                if editingTitle {
                    HStack(spacing: 8) {
                        TextField("Goal name", text: $titleBuffer)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(goal.color)
                            .tint(goal.color)
                            .focused($titleFocused)
                            .onSubmit { commitTitle() }
                        Button("Done") { commitTitle() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(goal.color)
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text(goal.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(goal.color)
                        .onTapGesture {
                            titleBuffer = goal.name
                            editingTitle = true
                            titleFocused = true
                        }
                }
                let done  = subgoals.filter { $0.progress >= 1.0 }.count
                Text("\(done) of \(subgoals.count) areas complete · \(Int(goal.progress * 100))%")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.35))
                if !editingTitle {
                    Text("tap name to rename")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.15))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func commitTitle() {
        let t = titleBuffer.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { goal.name = t }
        titleFocused = false
        withAnimation { editingTitle = false }
    }

    private var addSheet: some View {
        let isChild = addParentID != nil
        let title   = isChild ? "Add Sub-Goal" : "Add Area"
        return VStack(spacing: 20) {
            Capsule().fill(.primary.opacity(0.2))
                .frame(width: 36, height: 4).padding(.top, 8)
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            TextField("Name", text: $newName)
                .textFieldStyle(.plain).font(.system(size: 16))
                .foregroundStyle(.primary).tint(goal.color)
                .padding().background(Color.appRowFill)
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
            .foregroundStyle(newName.isEmpty ? .primary.opacity(0.3) : goal.color)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(goal.color.opacity(newName.isEmpty ? 0.06 : 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(260)])
        .presentationBackground(Color.appSurface)
        .presentationCornerRadius(24)
    }
}

// MARK: - Shared helpers

private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.primary.opacity(0.3))
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 0))
}

#Preview {
    NavigationStack {
        LifeGoalDetailView(goal: .constant(LifeGoal.demos[2]))
    }
}
