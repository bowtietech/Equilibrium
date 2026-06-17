import SwiftUI

// MARK: - Local mode enum (watch-only)
private enum WatchMode: String, CaseIterable {
    case daily = "daily"
    case life  = "life"
}

// MARK: - Root view

struct WatchContentView: View {
    @EnvironmentObject private var watchStore: WatchDataStore
    @State private var mode: WatchMode = .daily

    var body: some View {
        TabView(selection: $mode) {
            WatchGoalPage(
                modeLabel:   "TODAY",
                entries:     watchStore.goals.filter(\.isActive).map(\.wheelEntry),
                emptyIcon:   "list.bullet.clipboard"
            )
            .tag(WatchMode.daily)

            WatchGoalPage(
                modeLabel:   "LIFE",
                entries:     watchStore.lifeGoals.filter(\.isActive).map(\.wheelEntry),
                emptyIcon:   "mountain.2"
            )
            .tag(WatchMode.life)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .animation(.easeInOut(duration: 0.28), value: mode)
    }
}

// MARK: - Single mode page

struct WatchGoalPage: View {
    let modeLabel: String
    let entries:   [WheelEntry]
    let emptyIcon: String

    @State private var activeIndex = 0

    private var safeIndex: Int {
        entries.isEmpty ? 0 : min(activeIndex, entries.count - 1)
    }
    private var active: WheelEntry? { entries.isEmpty ? nil : entries[safeIndex] }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background ──────────────────────────────────────────────
                Color.appBg.ignoresSafeArea()

                if let a = active {
                    RadialGradient(
                        colors: [a.color.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * 0.6
                    )
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: safeIndex)
                }

                // ── Wheel fills the whole canvas ─────────────────────────────
                if entries.isEmpty {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 36))
                        .foregroundStyle(.primary.opacity(0.12))
                } else {
                    GoalWheelView(goals: entries, activeIndex: $activeIndex)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                // ── Labels overlaid at top and bottom ────────────────────────
                VStack {
                    // Mode chip + goal name at top
                    VStack(spacing: 1) {
                        Text(modeLabel)
                            .font(.system(size: 7, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.30))

                        if let a = active {
                            HStack(spacing: 3) {
                                Image(systemName: a.icon)
                                    .font(.system(size: 9, weight: .light))
                                    .foregroundStyle(a.color)
                                Text(a.name)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(a.color)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .id("name-\(safeIndex)-\(modeLabel)")
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: safeIndex)
                        } else {
                            Text("No \(modeLabel.lowercased()) goals")
                                .font(.system(size: 11))
                                .foregroundStyle(.primary.opacity(0.30))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                    Spacer()

                    // Percentage at bottom
                    if let a = active {
                        Text("\(Int(a.progress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.38))
                            .id("pct-\(safeIndex)-\(modeLabel)")
                            .transition(.opacity)
                            .animation(.spring(response: 0.25), value: safeIndex)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .onChange(of: entries.count) { _, count in
            if activeIndex >= count && count > 0 {
                activeIndex = count - 1
            }
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchDataStore())
}
