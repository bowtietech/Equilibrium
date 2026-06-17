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

                VStack(spacing: 0) {
                    Text(modeLabel)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.35))
                        .padding(.top, 4)

                    if let a = active {
                        HStack(spacing: 4) {
                            Image(systemName: a.icon)
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(a.color)
                            Text(a.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(a.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .id("name-\(safeIndex)-\(modeLabel)")
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: safeIndex)
                        .padding(.top, 2)
                    } else {
                        Text("No \(modeLabel.lowercased()) goals")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.35))
                            .padding(.top, 2)
                    }

                    if entries.isEmpty {
                        Spacer()
                        Image(systemName: emptyIcon)
                            .font(.system(size: 28))
                            .foregroundStyle(.primary.opacity(0.15))
                        Spacer()
                    } else {
                        GoalWheelView(goals: entries, activeIndex: $activeIndex)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, -4)
                    }

                    if let a = active {
                        Text("\(Int(a.progress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.4))
                            .id("pct-\(safeIndex)-\(modeLabel)")
                            .transition(.opacity)
                            .animation(.spring(response: 0.25), value: safeIndex)
                            .padding(.bottom, 2)
                    }
                }
                .padding(.horizontal, 2)
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
