import SwiftUI

struct GoalWheelView: View {
    let goals: [WheelEntry]
    @Binding var activeIndex: Int
    var onActiveTap: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    @State private var rotation: Double = 0
    @State private var dragDelta: Double = 0

    private var currentRotation: Double { rotation + dragDelta }

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            // 0.44 keeps ~27pt clearance on all sides so the pip indicator and
            // glow shadows aren't clipped by the Canvas frame.
            let radius = size * 0.44
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
                        dragDelta = angularDelta(start: val.startLocation,
                                                 current: val.location,
                                                 center: center)
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
                            rotation += dragDelta
                            dragDelta = 0
                            snap()
                        }
                    }
            )
        }
    }

    // MARK: - Circular Drag

    /// Signed angle (radians) to rotate from `start` to `current` around `center`.
    /// Uses cross/dot product so it's numerically stable with no atan2-wrap issues
    /// for movements up to ±180°, which covers all practical single-gesture usage.
    private func angularDelta(start: CGPoint, current: CGPoint, center: CGPoint) -> Double {
        let v0x = Double(start.x   - center.x)
        let v0y = Double(start.y   - center.y)
        let v1x = Double(current.x - center.x)
        let v1y = Double(current.y - center.y)
        let startDist = hypot(v0x, v0y)
        // Too close to center — fall back to a gentle horizontal sensitivity
        guard startDist > 12 else {
            return Double(current.x - start.x) * 0.006
        }
        let cross = v0x * v1y - v0y * v1x
        let dot   = v0x * v1x + v0y * v1y
        return atan2(cross, dot)
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = hypot(dx, dy)

        let hubR = min(radius * 0.065, 9.0)
        let centerZone = max(hubR * 4, 28.0)

        // Tap on the center hub → open the active goal
        if dist < centerZone {
            onActiveTap()
            return
        }

        guard !goals.isEmpty else { return }
        guard dist < radius * 1.45 else { return }

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
        guard !goals.isEmpty else { return }
        let safeActive = min(activeIndex, goals.count - 1)
        let step = 2.0 * Double.pi / Double(goals.count)

        // ── Static reference rings ──────────────────────────────────────────
        drawRing(ctx: ctx, center: center, radius: radius,        opacity: 0.10)
        drawRing(ctx: ctx, center: center, radius: radius * 0.5,  opacity: 0.05)
        drawRing(ctx: ctx, center: center, radius: radius * 0.25, opacity: 0.04)

        // ── Progress rings — one per goal, drawn before spokes ──────────────
        // Each ring sits at the dot's current radius. Opacity and glow radius
        // both scale with progress so the ring brightens as the dot nears center.
        for (i, goal) in goals.enumerated() {
            guard goal.progress > 0.04 else { continue }

            let lineLen    = radius * max(0.04, 1.0 - goal.progress)
            let isActive   = i == safeActive

            // More progress → tighter, brighter glow
            let glowStr: CGFloat = isActive
                ? CGFloat(goal.progress) * 1.0
                : CGFloat(goal.progress) * 0.55
            let glowBlur: CGFloat = 6 + (1.0 - CGFloat(goal.progress)) * 10   // shrinks toward center

            let ringRect = CGRect(x: center.x - lineLen, y: center.y - lineLen,
                                  width: lineLen * 2, height: lineLen * 2)

            // Outer soft halo
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: goal.color.opacity(glowStr),
                                        radius: glowBlur, x: 0, y: 0))
                layer.stroke(Path(ellipseIn: ringRect),
                             with: .color(goal.color.opacity(glowStr * 0.5)),
                             lineWidth: isActive ? 1.5 : 1.0)
            }
        }

        // ── Spokes, dots ────────────────────────────────────────────────────
        for (i, goal) in goals.enumerated() {
            let angle   = -(Double.pi / 2) + Double(i) * step + currentRotation
            let lineLen = radius * max(0.04, 1.0 - goal.progress)
            let endPt   = point(from: center, angle: angle, distance: lineLen)
            let farPt   = point(from: center, angle: angle, distance: radius)
            let isActive = i == safeActive

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

        // Center hub — tinted with active goal color, hinting it's tappable
        let hubR: CGFloat = min(radius * 0.075, 11)
        let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
        let activeColor = goals[safeActive].color
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: activeColor, radius: 10, x: 0, y: 0))
            layer.fill(Path(ellipseIn: hubRect), with: .color(activeColor.opacity(0.85)))
        }
        // Core dot — white on dark, dark on light
        let coreR: CGFloat = hubR * 0.4
        let coreRect = CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
        let coreDot: Color = colorScheme == .dark ? .white.opacity(0.9) : Color.primary.opacity(0.9)
        ctx.fill(Path(ellipseIn: coreRect), with: .color(coreDot))

        // Top indicator pip
        let pipR: CGFloat = max(2.5, radius * 0.022)
        let pipY  = center.y - radius - pipR * 2.5
        let pipRect = CGRect(x: center.x - pipR, y: pipY - pipR, width: pipR * 2, height: pipR * 2)
        let pipColor: Color = colorScheme == .dark ? .white.opacity(0.35) : Color.primary.opacity(0.35)
        ctx.fill(Path(ellipseIn: pipRect), with: .color(pipColor))
    }

    private func drawRing(ctx: GraphicsContext, center: CGPoint, radius: CGFloat, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        let ringColor: Color = colorScheme == .dark ? .white.opacity(opacity) : Color.primary.opacity(opacity)
        ctx.stroke(Path(ellipseIn: rect), with: .color(ringColor), lineWidth: 1)
    }

    private func point(from center: CGPoint, angle: Double, distance: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance)
    }

    // MARK: - Rotation Logic

    private func nearestGoal(rotation: Double) -> Int {
        guard !goals.isEmpty else { return 0 }
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
        guard !goals.isEmpty else { return }
        let step = 2.0 * Double.pi / Double(goals.count)
        var adj = (Double(activeIndex) * step + rotation).truncatingRemainder(dividingBy: 2 * .pi)
        if adj >  .pi { adj -= 2 * .pi }
        if adj < -.pi { adj += 2 * .pi }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            rotation -= adj
        }
    }
}
