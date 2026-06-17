import SwiftUI
import HealthKit

// MARK: - Schedule picker helpers (local to this file)

private enum ScheduleType: String, CaseIterable {
    case daily    = "Every day"
    case weekdays = "Specific days"
    case monthly  = "Monthly"
    case once     = "Specific date"
}

private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]  // index 0 = Sun (weekday 1)

// MARK: - GoalDetailView

struct GoalDetailView: View {
    @Binding var goal: Goal
    @EnvironmentObject private var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddSheet   = false
    @State private var editingItemID: UUID? = nil
    @State private var editBuffer        = ""
    @State private var editingTitle      = false
    @State private var titleBuffer       = ""
    @FocusState private var titleFocused: Bool

    // Add-sheet state
    @State private var newItemName       = ""
    @State private var scheduleType      = ScheduleType.daily
    @State private var weekdaySelection  = Set<Int>([2, 3, 4, 5, 6])  // Mon–Fri default
    @State private var monthDay          = Calendar.current.component(.day, from: Date())
    @State private var onceDate          = Date()

    private var derivedSchedule: GoalSchedule {
        switch scheduleType {
        case .daily:    return .daily
        case .weekdays: return .weekdays(weekdaySelection.sorted())
        case .monthly:  return .monthly(monthDay)
        case .once:     return .once(onceDate)
        }
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack {
                RadialGradient(
                    colors: [goal.color.opacity(0.18), .clear],
                    center: .top, startRadius: 0, endRadius: 260
                )
                .frame(height: 320)
                .ignoresSafeArea()
                Spacer()
            }

            List {
                headerSection
                if goal.isHealthBacked {
                    healthSection
                } else {
                    itemsSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !goal.isHealthBacked {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                            .foregroundStyle(goal.color)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addItemSheet
        }
    }

    // MARK: - Header

    private var effectiveProgress: Double {
        if let hkP = health.progressById[goal.id] { return hkP }
        return goal.todayProgress ?? goal.progress
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 20) {
                ZStack {
                    Circle().stroke(goal.color.opacity(0.18), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: effectiveProgress)
                        .stroke(goal.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                                   value: effectiveProgress)
                    Image(systemName: goal.icon)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(goal.color)
                }
                .frame(width: 110, height: 110)

                VStack(spacing: 6) {
                    if editingTitle {
                        HStack(spacing: 8) {
                            TextField("Goal name", text: $titleBuffer)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
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
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(goal.color)
                            .onTapGesture {
                                titleBuffer = goal.name
                                editingTitle = true
                                titleFocused = true
                            }
                    }

                    if goal.isHealthBacked, let target = goal.healthKitTarget,
                       let unit = goal.healthKitUnit {
                        let current = effectiveProgress * target
                        Text("\(formattedValue(current, unit: unit)) / \(formattedValue(target, unit: unit))")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.38))
                    } else if let tp = goal.todayProgress {
                        let done  = goal.items.filter { $0.isActiveToday && $0.isComplete }.count
                        let total = goal.items.filter(\.isActiveToday).count
                        Text("\(Int(tp * 100))% today  ·  \(done)/\(total) complete")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.38))
                    } else {
                        Text("no goals scheduled today")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                }
                if !editingTitle {
                    Text("tap name to rename")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.15))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func commitTitle() {
        let t = titleBuffer.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { goal.name = t }
        titleFocused = false
        withAnimation { editingTitle = false }
    }

    private func formattedValue(_ value: Double, unit: String) -> String {
        if unit == "steps" && value >= 1000 { return String(format: "%.1fk", value / 1000) }
        if value < 10                       { return String(format: "%.1f \(unit)", value) }
        return "\(Int(value)) \(unit)"
    }

    // MARK: - Health section (replaces items for HK-backed goals)

    private var healthSection: some View {
        Section {
            VStack(spacing: 16) {
                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.appRowFill).frame(height: 8)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [goal.color, goal.color.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * effectiveProgress, height: 8)
                                .animation(.spring(response: 0.6), value: effectiveProgress)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("0")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.25))
                        Spacer()
                        if let target = goal.healthKitTarget, let unit = goal.healthKitUnit {
                            Text(formattedValue(target, unit: unit))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.25))
                        }
                    }
                }

                // Source badge
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                    Text("Synced from Apple Health")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.35))
                }
            }
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        Section {
            ForEach($goal.items) { $item in
                GoalItemRow(
                    item: $item,
                    goalColor: goal.color,
                    editingID: $editingItemID,
                    editBuffer: $editBuffer
                )
                .listRowBackground(
                    item.isActiveToday ? Color.appRowFill : Color.appRowFill.opacity(0.5)
                )
                .listRowSeparatorTint(Color.appRowFill)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .onDelete { goal.items.remove(atOffsets: $0) }
            .onMove  { goal.items.move(fromOffsets: $0, toOffset: $1) }
        } header: {
            HStack {
                Text("Goals")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.3))
                    .textCase(nil)
                Spacer()
                Text("swipe to delete  ·  hold to reorder")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.18))
                    .textCase(nil)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
        }
    }

    // MARK: - Add Sheet

    private var addItemSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(.primary.opacity(0.2))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("New \(goal.name) Goal")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            // Name field
            TextField("e.g. Meditate 10 minutes", text: $newItemName)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .tint(goal.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appRowFill)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Schedule picker
            schedulePicker

            // Add button
            Button(action: commitNewItem) {
                Text("Add Goal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canAdd ? goal.color : .primary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(goal.color.opacity(canAdd ? 0.15 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(!canAdd)

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(scheduleSheetHeight)])
        .presentationBackground(Color.appSurface)
        .presentationCornerRadius(24)
        .onSubmit { commitNewItem() }
    }

    private var canAdd: Bool {
        !newItemName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !(scheduleType == .weekdays && weekdaySelection.isEmpty)
    }

    private var scheduleSheetHeight: CGFloat {
        switch scheduleType {
        case .daily:    return 320
        case .weekdays: return 380
        case .monthly:  return 400
        case .once:     return 460
        }
    }

    @ViewBuilder
    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REPEAT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.3))

            // Type segmented tabs
            HStack(spacing: 6) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.25)) { scheduleType = type }
                    } label: {
                        Text(type.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(scheduleType == type ? goal.color : .primary.opacity(0.45))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(scheduleType == type
                                        ? goal.color.opacity(0.18)
                                        : Color.appRowFill)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Extra picker depending on type
            switch scheduleType {
            case .daily:
                EmptyView()

            case .weekdays:
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { wd in
                        let selected = weekdaySelection.contains(wd)
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                if selected { weekdaySelection.remove(wd) }
                                else        { weekdaySelection.insert(wd) }
                            }
                        } label: {
                            Text(weekdayLabels[wd - 1])
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(selected ? goal.color : .primary.opacity(0.35))
                                .frame(width: 36, height: 36)
                                .background(selected
                                            ? goal.color.opacity(0.2)
                                            : Color.appRowFill)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .monthly:
                Picker("Day of month", selection: $monthDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
                .tint(goal.color)

            case .once:
                DatePicker("Date", selection: $onceDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(goal.color)
                    .frame(height: 160)
                    .scaleEffect(0.88)
            }
        }
    }

    private func commitNewItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !(scheduleType == .weekdays && weekdaySelection.isEmpty) else { return }
        withAnimation(.spring(response: 0.3)) {
            goal.items.append(GoalItem(name: trimmed, schedule: derivedSchedule))
        }
        newItemName      = ""
        scheduleType     = .daily
        weekdaySelection = [2, 3, 4, 5, 6]
        onceDate         = Date()
        showingAddSheet  = false
    }
}

// MARK: - Goal Item Row

struct GoalItemRow: View {
    @Binding var item: GoalItem
    let goalColor: Color
    @Binding var editingID: UUID?
    @Binding var editBuffer: String

    private var isEditing: Bool { editingID == item.id }

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    item.isComplete.toggle()
                }
            } label: {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isComplete ? goalColor : .primary.opacity(0.28))
                    .animation(.spring(response: 0.2), value: item.isComplete)
            }
            .buttonStyle(.plain)

            // Name + schedule
            VStack(alignment: .leading, spacing: 3) {
                if isEditing {
                    TextField("Goal name", text: $editBuffer)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .tint(goalColor)
                        .onSubmit { commitEdit() }
                } else {
                    Text(item.name)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.primary.opacity(item.isComplete ? 0.35 : 0.88))
                        .strikethrough(item.isComplete, color: .primary.opacity(0.22))
                        .animation(.easeInOut(duration: 0.18), value: item.isComplete)
                        .onTapGesture {
                            editBuffer = item.name
                            withAnimation { editingID = item.id }
                        }
                }

                // Schedule label
                HStack(spacing: 4) {
                    if item.isActiveToday {
                        Circle()
                            .fill(goalColor)
                            .frame(width: 5, height: 5)
                    }
                    Text(item.schedule.label)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(item.isActiveToday
                                         ? goalColor.opacity(0.65)
                                         : .primary.opacity(0.22))
                }
            }

            Spacer()

            if isEditing {
                Button("Done") { commitEdit() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(goalColor)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func commitEdit() {
        let trimmed = editBuffer.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { item.name = trimmed }
        editingID = nil
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: .constant(Goal.demos[0]))
    }
}
