import SwiftUI

struct GoalWheelView: View {
    let goals: [Goal]
    @Binding var activeIndex: Int
    var onActiveTap: () -> Void = {}

    @State private var rotation: Double = 0
    @State private var dragDelta: Double = 0

    private var currentRotation: Double { rotation + dragDelta }

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let radius = size * 0.43
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            Canvas { ctx, _ in
                drawWheel(ctx: ctx, center: center, radius: radius)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let moved = hypot(Double(val.translation.width), Double(val.translation.height))
                        guard moved > 6 else { return }
                        dragDelta = Double(val.translation.width) * 0.012
                        let candidate = nearestGoal(rotation: currentRotation)
                        if candidate != activeIndex {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                activeIndex = candidate
                            }
                        }
                    }
                    .onEnded { val in
                        let moved = hypot(Double(val.translation.width), Double(val.translation.height))
                        if moved < 6 {
                            dragDelta = 0
                            handleTap(at: val.startLocation, center: center, radius: radius)
                        } else {
                            rotation += Double(val.translation.width) * 0.012
                            dragDelta = 0
                            snap()
                        }
                    }
            )
        }
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = hypot(dx, dy)

        let hubR = min(radius * 0.065, 9.0)
        guard dist > hubR * 3 && dist < radius * 1.45 else { return }

        let tapAngle = atan2(Double(dy), Double(dx))
        let step = 2.0 * Double.pi / Double(goals.count)

        var minDiff = Double.infinity
        var nearest = activeIndex

        for i in 0..<goals.count {
            let goalAngle = -(Double.pi / 2) + Double(i) * step + currentRotation
            var diff = (tapAngle - goalAngle).truncatingRemainder(dividingBy: 2 * .pi)
            if diff >  .pi { diff -= 2 * .pi }
            if diff < -.pi { diff += 2 * .pi }
            if abs(diff) < minDiff { minDiff = abs(diff); nearest = i }
        }

        if nearest == activeIndex {
            onActiveTap()
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                activeIndex = nearest
            }
            var adj = (Double(nearest) * step + rotation).truncatingRemainder(dividingBy: 2 * .pi)
            if adj >  .pi { adj -= 2 * .pi }
            if adj < -.pi { adj += 2 * .pi }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                rotation -= adj
            }
        }
    }

    // MARK: - Drawing

    private func drawWheel(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let step = 2.0 * Double.pi / Double(goals.count)

        drawRing(ctx: ctx, center: center, radius: radius,          opacity: 0.10)
        drawRing(ctx: ctx, center: center, radius: radius * 0.5,    opacity: 0.05)
        drawRing(ctx: ctx, center: center, radius: radius * 0.25,   opacity: 0.04)

        for (i, goal) in goals.enumerated() {
            let angle   = -(Double.pi / 2) + Double(i) * step + currentRotation
            let lineLen = radius * max(0.04, 1.0 - goal.progress)
            let endPt   = point(from: center, angle: angle, distance: lineLen)
            let farPt   = point(from: center, angle: angle, distance: radius)
            let isActive = i == activeIndex

            // Ghost track to outer ring
            var track = Path()
            track.move(to: center)
            track.addLine(to: farPt)
            ctx.stroke(track, with: .color(goal.color.opacity(0.14)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Active line with glow, otherwise plain
            var line = Path()
            line.move(to: center)
            line.addLine(to: endPt)

            if isActive {
                ctx.drawLayer { layer in
                    layer.addFilter(.shadow(color: goal.color, radius: 10, x: 0, y: 0))
                    layer.stroke(line, with: .color(goal.color),
                                 style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
            } else {
                ctx.stroke(line, with: .color(goal.color.opacity(0.65)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // End-point dot
            let dr: CGFloat = isActive ? 7.5 : 5
            let dotRect = CGRect(x: endPt.x - dr, y: endPt.y - dr, width: dr * 2, height: dr * 2)

            if isActive {
                ctx.drawLayer { layer in
                    layer.addFilter(.shadow(color: goal.color, radius: 8, x: 0, y: 0))
                    layer.fill(Path(ellipseIn: dotRect), with: .color(goal.color))
                }
                // Outer ring on active dot
                let haloRect = dotRect.insetBy(dx: -3, dy: -3)
                ctx.stroke(Path(ellipseIn: haloRect),
                           with: .color(goal.color.opacity(0.3)),
                           lineWidth: 1.5)
            } else {
                ctx.fill(Path(ellipseIn: dotRect), with: .color(goal.color.opacity(0.7)))
            }
        }

        // Center hub
        let hubR: CGFloat = min(radius * 0.065, 9)
        let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .white, radius: 6, x: 0, y: 0))
            layer.fill(Path(ellipseIn: hubRect), with: .color(.white))
        }

        // Top indicator pip
        let pipR: CGFloat = max(2.5, radius * 0.022)
        let pipY  = center.y - radius - pipR * 2.5
        let pipRect = CGRect(x: center.x - pipR, y: pipY - pipR, width: pipR * 2, height: pipR * 2)
        ctx.fill(Path(ellipseIn: pipRect), with: .color(.white.opacity(0.35)))
    }

    private func drawRing(ctx: GraphicsContext, center: CGPoint, radius: CGFloat, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.stroke(Path(ellipseIn: rect),
                   with: .color(.white.opacity(opacity)),
                   lineWidth: 1)
    }

    private func point(from center: CGPoint, angle: Double, distance: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance)
    }

    // MARK: - Rotation Logic

    private func nearestGoal(rotation: Double) -> Int {
        let step = 2.0 * Double.pi / Double(goals.count)
        var minDiff = Double.infinity
        var idx = 0
        for i in 0..<goals.count {
            var n = (Double(i) * step + rotation).truncatingRemainder(dividingBy: 2 * .pi)
            if n >  .pi { n -= 2 * .pi }
            if n < -.pi { n += 2 * .pi }
            if abs(n) < minDiff { minDiff = abs(n); idx = i }
        }
        return idx
    }

    private func snap() {
        let step = 2.0 * Double.pi / Double(goals.count)
        var adj = (Double(activeIndex) * step + rotation).truncatingRemainder(dividingBy: 2 * .pi)
        if adj >  .pi { adj -= 2 * .pi }
        if adj < -.pi { adj += 2 * .pi }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            rotation -= adj
        }
    }
}
