import SwiftUI

struct GoalDetailView: View {
    @Binding var goal: Goal
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddSheet  = false
    @State private var newItemName      = ""
    @State private var editingItemID: UUID? = nil
    @State private var editBuffer       = ""

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()

            // Subtle color bloom behind the header
            VStack {
                RadialGradient(
                    colors: [goal.color.opacity(0.18), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 260
                )
                .frame(height: 320)
                .ignoresSafeArea()
                Spacer()
            }

            List {
                headerSection
                itemsSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                        .foregroundStyle(goal.color)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addItemSheet
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(spacing: 20) {
                // Progress ring with icon
                ZStack {
                    Circle()
                        .stroke(goal.color.opacity(0.18), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: goal.progress)
                        .stroke(goal.color,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                                   value: goal.progress)

                    Image(systemName: goal.icon)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(goal.color)
                }
                .frame(width: 110, height: 110)

                VStack(spacing: 6) {
                    Text(goal.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(goal.color)

                    let done  = goal.items.filter(\.isComplete).count
                    let total = goal.items.count
                    Text("\(Int(goal.progress * 100))% complete  ·  \(done) of \(total)")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

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
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.white.opacity(item.isComplete ? 0.03 : 0.06))
                )
                .listRowSeparatorTint(.white.opacity(0.07))
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .onDelete { indices in
                goal.items.remove(atOffsets: indices)
            }
            .onMove { from, to in
                goal.items.move(fromOffsets: from, toOffset: to)
            }
        } header: {
            Text("Goals")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 0))
        }
    }

    // MARK: - Add Sheet

    private var addItemSheet: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("New \(goal.name) Goal")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            TextField("e.g. Meditate 10 minutes", text: $newItemName)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .tint(goal.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit { commitNewItem() }

            Button(action: commitNewItem) {
                Text("Add Goal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(newItemName.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? .white.opacity(0.3) : goal.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(goal.color.opacity(
                        newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.06 : 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(260)])
        .presentationBackground(Color(red: 0.08, green: 0.08, blue: 0.13))
        .presentationCornerRadius(24)
    }

    private func commitNewItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.3)) {
            goal.items.append(GoalItem(name: trimmed))
        }
        newItemName      = ""
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
                    .foregroundStyle(item.isComplete ? goalColor : .white.opacity(0.28))
                    .animation(.spring(response: 0.2), value: item.isComplete)
            }
            .buttonStyle(.plain)

            // Name — editable on tap
            if isEditing {
                TextField("Goal name", text: $editBuffer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(goalColor)
                    .onSubmit { commitEdit() }
            } else {
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundStyle(item.isComplete ? .white.opacity(0.35) : .white.opacity(0.88))
                    .strikethrough(item.isComplete, color: .white.opacity(0.22))
                    .animation(.easeInOut(duration: 0.18), value: item.isComplete)
                    .onTapGesture {
                        editBuffer = item.name
                        withAnimation { editingID = item.id }
                    }
            }

            Spacer()

            if isEditing {
                Button("Done") { commitEdit() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(goalColor)
            }
        }
        .padding(.vertical, 14)
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
