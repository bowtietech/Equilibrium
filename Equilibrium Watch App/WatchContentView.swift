import SwiftUI

struct WatchContentView: View {
    @State private var goals       = Goal.demos
    @State private var activeIndex = 0

    private var active: Goal { goals[activeIndex] }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
                .ignoresSafeArea()

            RadialGradient(
                colors: [active.color.opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 120
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: activeIndex)

            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: active.icon)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(active.color)

                    Text(active.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(active.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .id("name-\(activeIndex)")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: activeIndex)

                GoalWheelView(goals: goals.map(\.wheelEntry), activeIndex: $activeIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("\(Int(active.progress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .id("pct-\(activeIndex)")
                    .transition(.opacity)
                    .animation(.spring(response: 0.25), value: activeIndex)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    WatchContentView()
}
