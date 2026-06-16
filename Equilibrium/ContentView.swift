import SwiftUI

struct ContentView: View {
    @State private var goals            = Goal.demos
    @State private var activeIndex      = 0
    @State private var navigateToDetail = false

    private var active: Goal       { goals[activeIndex] }
    private var score: Double      { goals.balanceScore }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 0) {
                    appLabel
                    balanceCard
                    Spacer(minLength: 0)
                    goalInfo
                    wheelArea
                    hint
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToDetail) {
                GoalDetailView(goal: $goals[activeIndex])
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
            RadialGradient(
                colors: [active.color.opacity(0.11), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .animation(.easeInOut(duration: 0.5), value: activeIndex)
        }
        .ignoresSafeArea()
    }

    // MARK: - Sub-views

    private var appLabel: some View {
        Text("equilibrium")
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.28))
            .padding(.top, 16)
    }

    private var balanceCard: some View {
        HStack(spacing: 14) {
            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(
                        scoreColor(score),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: score)
            }
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
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var goalInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: active.icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(active.color)
                Text(active.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(active.color)
            }
            .id("name-\(activeIndex)")
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.88)),
                removal:   .opacity.combined(with: .scale(scale: 1.06))
            ))

            todayProgressLabel
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: activeIndex)
        .frame(height: 88)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var todayProgressLabel: some View {
        if let tp = active.todayProgress {
            Text("\(Int(tp * 100))% today")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .id("pct-\(activeIndex)")
                .transition(.opacity)
        } else {
            Text("no goals today")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .id("notoday-\(activeIndex)")
                .transition(.opacity)
        }
    }

    private var wheelArea: some View {
        GoalWheelView(goals: goals, activeIndex: $activeIndex, onActiveTap: {
            navigateToDetail = true
        })
        .frame(maxWidth: .infinity)
        .frame(height: 320)
    }

    private var hint: some View {
        Text("drag to spin  ·  tap to select  ·  tap active to open")
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundStyle(.white.opacity(0.16))
            .padding(.top, 8)
            .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func scoreColor(_ s: Double) -> Color {
        if s < 0.4 { return Color(red: 1.0, green: 0.40, blue: 0.40) }
        if s < 0.7 { return Color(red: 1.0, green: 0.76, blue: 0.22) }
        return Color(red: 0.28, green: 0.88, blue: 0.54)
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: Date())
    }
}

#Preview {
    ContentView()
}
