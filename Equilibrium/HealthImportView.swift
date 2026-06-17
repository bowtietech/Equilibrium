import SwiftUI
import HealthKit

struct HealthImportView: View {
    @EnvironmentObject private var store:  DataStore
    @EnvironmentObject private var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var todayValues: [String: Double]  = [:]
    @State private var configuring: HealthMetricTemplate? = nil
    @State private var isLoading = true

    private var categories: [String] {
        var seen = Set<String>()
        return HealthMetricTemplate.all.compactMap { t in
            seen.insert(t.category).inserted ? t.category : nil
        }
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                            .padding(10)
                            .background(Color.appRowFill, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Apple Health")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if !health.isAuthorized {
                    authPrompt
                } else if isLoading {
                    Spacer()
                    ProgressView().tint(.primary.opacity(0.4))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            ForEach(categories, id: \.self) { cat in
                                categorySection(cat)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        //.preferredColorScheme(.dark) — handled by RootView
        .task {
            if !health.isAuthorized {
                await health.requestAuthorization()
            }
            if health.isAuthorized { await fetchTodayValues() }
        }
        .sheet(item: $configuring) { template in
            HealthGoalConfigSheet(template: template, todayValue: todayValues[template.id] ?? 0) { target in
                addGoal(template: template, target: target)
            }
        }
    }

    // MARK: - Auth prompt

    private var authPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red.opacity(0.8))
            Text("Connect Apple Health")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Equilibrium will read your health data to automatically track your daily goals.")
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.55))
                .padding(.horizontal, 32)
            Button {
                Task { await health.requestAuthorization(); await fetchTodayValues() }
            } label: {
                Text("Allow Access")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appBg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.primary)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Category section

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let templates = HealthMetricTemplate.all.filter { $0.category == category }
        VStack(alignment: .leading, spacing: 10) {
            Text(category.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.35))
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(templates) { template in
                    metricRow(template)
                }
            }
        }
    }

    @ViewBuilder
    private func metricRow(_ template: HealthMetricTemplate) -> some View {
        let alreadyAdded = store.goals.contains { $0.healthKitIdentifier == template.id }
        let value        = todayValues[template.id] ?? 0
        let formatted    = formattedValue(value, unit: template.unitLabel)

        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(template.colorData.value.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: template.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(template.colorData.value)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(value > 0 ? "Today: \(formatted)" : "No data yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.4))
            }

            Spacer()

            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(template.colorData.value)
                    .font(.system(size: 20))
            } else {
                Button {
                    configuring = template
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.primary.opacity(0.3))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.appRowFill.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func fetchTodayValues() async {
        isLoading = true
        var result: [String: Double] = [:]
        for template in HealthMetricTemplate.all {
            result[template.id] = await health.todayValue(for: template)
        }
        todayValues = result
        isLoading = false
    }

    private func addGoal(template: HealthMetricTemplate, target: Double) {
        let newGoal = Goal(
            name:                template.name,
            colorData:           template.colorData,
            icon:                template.icon,
            items:               [],
            healthKitIdentifier: template.id,
            healthKitTarget:     target,
            healthKitUnit:       template.unitLabel
        )
        store.goals.append(newGoal)
        Task { await health.refresh(goals: store.goals) }
    }

    private func formattedValue(_ value: Double, unit: String) -> String {
        if value >= 1000 && unit == "steps" {
            return String(format: "%.1fk \(unit)", value / 1000)
        }
        if value < 10 {
            return String(format: "%.1f \(unit)", value)
        }
        return "\(Int(value)) \(unit)"
    }
}

// MARK: - Config sheet (set the daily target before adding)

private struct HealthGoalConfigSheet: View {
    let template:   HealthMetricTemplate
    let todayValue: Double
    let onAdd:      (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var target: Double

    init(template: HealthMetricTemplate, todayValue: Double, onAdd: @escaping (Double) -> Void) {
        self.template   = template
        self.todayValue = todayValue
        self.onAdd      = onAdd
        _target = State(initialValue: template.defaultTarget)
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 28) {
                // Icon
                ZStack {
                    Circle()
                        .fill(template.colorData.value.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: template.icon)
                        .font(.system(size: 34))
                        .foregroundStyle(template.colorData.value)
                }
                .padding(.top, 36)

                Text("Set your daily target")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                // Target stepper
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        stepButton(icon: "minus", action: { target = max(1, target - stepSize) })
                        VStack(spacing: 2) {
                            Text(formattedTarget)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                            Text(template.unitLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .frame(minWidth: 120)
                        stepButton(icon: "plus", action: { target = target + stepSize })
                    }

                    if todayValue > 0 {
                        Text("Today: \(Int(todayValue)) \(template.unitLabel)")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.appRowFill.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                Button {
                    onAdd(target)
                    dismiss()
                } label: {
                    Text("Add Goal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(template.colorData.value)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium])
        //.preferredColorScheme(.dark) — handled by RootView
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.appRowFill, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var stepSize: Double {
        switch template.unitLabel {
        case "steps": return 500
        case "kcal":  return 50
        case "km":    return 0.5
        default:      return 1
        }
    }

    private var formattedTarget: String {
        if template.unitLabel == "steps" { return String(format: "%.0f", target) }
        if target < 10                   { return String(format: "%.1f", target) }
        return "\(Int(target))"
    }
}
