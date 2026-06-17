import SwiftUI

// MARK: - Storage keys

private enum PK {
    static let name         = "profile_name"
    static let tagline      = "profile_tagline"
    static let dobTS        = "profile_dob"
    static let heightIn     = "profile_height_in"
    static let weightLbs    = "profile_weight_lbs"
    static let notifs       = "profile_notifs"
    static let reminderHour = "profile_reminder_h"
    static let avatarColor  = "profile_avatar_col"
    static let joinTS       = "profile_joined"
}

// MARK: - ProfileView

struct ProfileView: View {

    // Stats from the home screen
    let balanceScore: Double
    let dailyGoalCount: Int
    let lifeGoalCount: Int

    // Persisted profile fields
    @AppStorage(PK.name)         private var name: String  = ""
    @AppStorage(PK.tagline)      private var tagline: String = ""
    @AppStorage(PK.dobTS)        private var dobTS: Double  = 0
    @AppStorage(PK.heightIn)     private var heightIn: Int  = 67
    @AppStorage(PK.weightLbs)    private var weightLbs: Bool = true
    @AppStorage(PK.notifs)       private var notifsOn: Bool = true
    @AppStorage(PK.reminderHour) private var reminderHour: Int = 8
    @AppStorage(PK.avatarColor)  private var colorIdx: Int  = 0
    @AppStorage(PK.joinTS)       private var joinTS: Double  = 0

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var showDOB    = false
    @State private var showHeight = false

    // MARK: Palette

    static let palette: [Color] = [
        Color(red: 0.58, green: 0.40, blue: 0.96),
        Color(red: 1.00, green: 0.55, blue: 0.10),
        Color(red: 0.18, green: 0.78, blue: 0.42),
        Color(red: 0.15, green: 0.82, blue: 0.94),
        Color(red: 1.00, green: 0.32, blue: 0.55),
        Color(red: 0.28, green: 0.56, blue: 1.00),
    ]

    private var accent: Color { Self.palette[colorIdx] }

    // MARK: Computed helpers

    private var initials: String {
        let words = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        switch words.count {
        case 0:  return ""
        case 1:  return String(words[0].prefix(2)).uppercased()
        default: return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
    }

    private var dob: Date? { dobTS > 0 ? Date(timeIntervalSince1970: dobTS) : nil }

    private var ageLabel: String {
        guard let d = dob else { return "—" }
        let yrs = Calendar.current.dateComponents([.year], from: d, to: .now).year ?? 0
        return "\(yrs)"
    }

    private var heightLabel: String {
        "\(heightIn / 12)' \(heightIn % 12)\""
    }

    private var reminderLabel: String {
        let h = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        return "\(h):00 \(reminderHour < 12 ? "AM" : "PM")"
    }

    private var joinedLabel: String {
        guard joinTS > 0 else { return "today" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: Date(timeIntervalSince1970: joinTS))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.09).ignoresSafeArea()
                RadialGradient(
                    colors: [accent.opacity(0.14), .clear],
                    center: .top, startRadius: 0, endRadius: 420
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: colorIdx)

                List {
                    avatarSection
                    statsSection
                    personalSection
                    preferencesSection
                    aboutSection
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("profile")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.28))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .onAppear {
            if joinTS == 0 { joinTS = Date().timeIntervalSince1970 }
            if name.isEmpty { nameFocused = true }
        }
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        Section {
            VStack(spacing: 20) {
                avatarCircle
                colorPicker
                nameField
                taglineField
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(accent.gradient)
                .frame(width: 90, height: 90)
                .shadow(color: accent.opacity(0.45), radius: 22)

            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(initials)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(response: 0.35), value: colorIdx)
    }

    private var colorPicker: some View {
        HStack(spacing: 14) {
            ForEach(Self.palette.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { colorIdx = i }
                } label: {
                    ZStack {
                        Circle().fill(Self.palette[i]).frame(width: 22, height: 22)
                        if colorIdx == i {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nameField: some View {
        TextField("Your name", text: $name)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .focused($nameFocused)
            .submitLabel(.done)
    }

    private var taglineField: some View {
        TextField("Add a tagline…", text: $tagline)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .submitLabel(.done)
    }

    // MARK: - Stats section

    private var statsSection: some View {
        Section {
            HStack(spacing: 10) {
                statPill(
                    value: "\(Int(balanceScore * 100))%",
                    label: "today's balance",
                    color: scoreColor(balanceScore)
                )
                statPill(value: "\(dailyGoalCount)", label: "daily goals",  color: .white.opacity(0.55))
                statPill(value: "\(lifeGoalCount)",  label: "life goals",   color: .white.opacity(0.55))
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Personal section

    private var personalSection: some View {
        Section {
            // Birthday
            profileRow(icon: "birthday.cake", label: "Birthday") {
                Text(dob != nil ? "Age \(ageLabel)" : "Set")
                    .profileValue(set: dob != nil)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { showDOB.toggle(); showHeight = false } }

            if showDOB {
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                dob ?? Calendar.current.date(
                                    byAdding: .year, value: -28, to: .now)!
                            },
                            set: { dobTS = $0.timeIntervalSince1970 }
                        ),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                    if dob != nil {
                        Button("Clear date") {
                            withAnimation { dobTS = 0; showDOB = false }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.65))
                        .padding(.bottom, 8)
                    }
                }
                .listRowBackground(rowBG)
            }

            // Height
            profileRow(icon: "ruler", label: "Height") {
                Text(heightIn > 0 ? heightLabel : "Set")
                    .profileValue(set: heightIn > 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { showHeight.toggle(); showDOB = false } }

            if showHeight {
                HStack(spacing: 0) {
                    Picker("Feet", selection: Binding(
                        get: { heightIn / 12 },
                        set: { heightIn = $0 * 12 + (heightIn % 12) }
                    )) {
                        ForEach(4...7, id: \.self) { ft in Text("\(ft) ft").tag(ft) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Inches", selection: Binding(
                        get: { heightIn % 12 },
                        set: { heightIn = (heightIn / 12) * 12 + $0 }
                    )) {
                        ForEach(0...11, id: \.self) { i in Text("\(i) in").tag(i) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(rowBG)
            }

        } header: { sectionHeader("Personal") }
        .listRowBackground(rowBG)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    // MARK: - Preferences section

    private var preferencesSection: some View {
        Section {
            // Weight unit
            profileRow(icon: "scalemass", label: "Weight Unit") {
                Picker("", selection: $weightLbs) {
                    Text("lbs").tag(true)
                    Text("kg").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 104)
            }

            // Notifications toggle
            profileRow(icon: "bell", label: "Daily Reminder") {
                Toggle("", isOn: $notifsOn)
                    .tint(accent)
                    .labelsHidden()
            }

            // Reminder time
            if notifsOn {
                profileRow(icon: "clock", label: "Reminder Time") {
                    Picker("", selection: $reminderHour) {
                        ForEach(0...23, id: \.self) { h in
                            let d = h % 12 == 0 ? 12 : h % 12
                            Text("\(d):00 \(h < 12 ? "AM" : "PM")").tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(accent)
                }
            }
        } header: { sectionHeader("Preferences") }
        .listRowBackground(rowBG)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section {
            profileRow(icon: "calendar.badge.plus", label: "Member since") {
                Text(joinedLabel).profileValue(set: true)
            }
            profileRow(icon: "info.circle", label: "Version") {
                Text("1.0").profileValue(set: true)
            }
        } header: { sectionHeader("About") }
        .listRowBackground(rowBG)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    // MARK: - Layout helpers

    private var rowBG: some View {
        Color.white.opacity(0.05)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.28))
            .textCase(nil)
    }

    @ViewBuilder
    private func profileRow<T: View>(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack {
            Label {
                Text(label).foregroundStyle(.white.opacity(0.8))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 20)
            }
            Spacer()
            trailing()
        }
    }

    private func scoreColor(_ s: Double) -> Color {
        if s < 0.4 { return Color(red: 1.0, green: 0.40, blue: 0.40) }
        if s < 0.7 { return Color(red: 1.0, green: 0.76, blue: 0.22) }
        return Color(red: 0.28, green: 0.88, blue: 0.54)
    }
}

// MARK: - Text style helper

private extension Text {
    func profileValue(set: Bool) -> some View {
        self
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(set ? .white.opacity(0.55) : .white.opacity(0.22))
    }
}

#Preview {
    ProfileView(balanceScore: 0.73, dailyGoalCount: 6, lifeGoalCount: 6)
}
