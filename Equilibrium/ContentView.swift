import SwiftUI

struct ContentView: View {
    @State private var goals          = Goal.demos
    @State private var activeIndex    = 0
    @State private var navigateToDetail = false

    private var active: Goal { goals[activeIndex] }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 0) {
                    appLabel
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

    // MARK: - Sub-views

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
            RadialGradient(
                colors: [active.color.opacity(0.12), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .animation(.easeInOut(duration: 0.5), value: activeIndex)
        }
        .ignoresSafeArea()
    }

    private var appLabel: some View {
        Text("equilibrium")
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.28))
            .padding(.top, 16)
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

            Text("\(Int(active.progress * 100))% complete")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .id("pct-\(activeIndex)")
                .transition(.opacity)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: activeIndex)
        .frame(height: 88)
        .padding(.bottom, 4)
    }

    private var wheelArea: some View {
        GoalWheelView(goals: goals, activeIndex: $activeIndex, onActiveTap: {
            navigateToDetail = true
        })
        .frame(maxWidth: .infinity)
        .frame(height: 340)
    }

    private var hint: some View {
        Text("swipe to explore  ·  tap to open")
            .font(.system(size: 12, weight: .light, design: .monospaced))
            .foregroundStyle(.white.opacity(0.18))
            .padding(.top, 8)
            .padding(.bottom, 28)
    }
}

#Preview {
    ContentView()
}
