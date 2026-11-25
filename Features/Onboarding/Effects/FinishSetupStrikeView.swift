import SwiftUI

/// Draws the Finish Setup strike. Lives only inside the overlay panel, which
/// is created when the strike starts and released when it ends.
struct FinishSetupStrikeView: View {
    @ObservedObject var state: FinishSetupStrikeState

    var body: some View {
        let scene = state.scene
        let start = state.start
        let showsArc = state.showsMenuBarArc
        if scene.reduced {
            Canvas { context, _ in
                FinishSetupStrikeRenderer.drawReduced(in: context, scene: scene, showsStatusItem: showsArc)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                Canvas { context, _ in
                    FinishSetupStrikeRenderer.draw(in: context, scene: scene, showsArc: showsArc,
                                                   time: timeline.date.timeIntervalSince(start))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

enum FinishSetupStrikeRenderer {
    private typealias T = FinishSetupStrikeTimeline
    private typealias S = FinishSetupStrikeStyle

    static let bloom = Color(red: 60 / 255, green: 120 / 255, blue: 1)
    static let bloomGlow = Color(red: 80 / 255, green: 160 / 255, blue: 1)
    static let cyan = Color(red: 120 / 255, green: 220 / 255, blue: 1)
    static let cyanGlow = Color(red: 126 / 255, green: 232 / 255, blue: 1)
    static let yellow = Color(red: 1, green: 240 / 255, blue: 90 / 255)
    static let amber = Color(red: 1, green: 214 / 255, blue: 90 / 255)
    static let night = Color(red: 5 / 255, green: 6 / 255, blue: 26 / 255)
    static let debris = Color(red: 39 / 255, green: 48 / 255, blue: 77 / 255)
    static let sparkTints = [Color(red: 1, green: 246 / 255, blue: 160 / 255), Color(red: 159 / 255, green: 233 / 255, blue: 1), .white]

    // MARK: Full strike

    static func draw(in context: GraphicsContext, scene: FinishSetupStrikeScene, showsArc: Bool, time t: TimeInterval) {
        let full = CGRect(origin: .zero, size: scene.size)
        let center = CGPoint(x: scene.button.midX, y: scene.button.midY)
        let frame = Int(t * 60)
        let sinceStrike = t - T.strike
        let sinceImpact = sinceStrike - T.leader
        let sinceRestrike = t - T.restrike

        // Dim, with a black impact frame right after the white flash.
        var dim = 0.0
        if t >= T.anticipation && t < T.strike { dim = 0.45 * ease((t - T.anticipation) / 0.3) }
        else if t >= T.strike && t < T.dismiss { dim = lerp(0.45, 0, ease(sinceStrike / 0.9)) }
        if sinceImpact >= 2.0 / 60 && sinceImpact < 4.0 / 60 {
            context.fill(Path(full), with: .color(.black.opacity(0.94)))
        } else if dim > 0 {
            context.fill(Path(full), with: .color(night.opacity(dim)))
        }

        if t >= T.anticipation && t < T.strike + 0.02 { drawTopCrackle(context, scene: scene, elapsed: t - T.anticipation) }

        if sinceStrike >= 0 {
            let reach = clamp(sinceStrike / T.leader)
            if sinceStrike < 0.38 {
                let flicker = frame % 5 == 3 ? 0.35 : 1
                let fade = sinceStrike < 0.22 ? 1 : 1 - (sinceStrike - 0.22) / 0.16
                drawStrike(context, scene.strike, reach: reach, alpha: flicker * fade, seed: UInt32(frame / 2),
                           jitter: sinceStrike < T.leader ? 0 : 3)
            }
            if sinceRestrike >= 0 && sinceRestrike < 0.22 {
                drawStrike(context, scene.restrike, reach: clamp(sinceRestrike / 0.04), alpha: 1 - sinceRestrike / 0.22,
                           seed: UInt32(frame), jitter: 4)
            }
            drawSpeedLines(context, center: center, elapsed: sinceImpact, seed: UInt32(max(frame, 0) / 2))
            drawShockwave(context, center: center, elapsed: sinceImpact)
            drawParticles(context, scene: scene, center: center, elapsed: sinceImpact)
            if sinceRestrike >= 0 { drawShockwave(context, center: center, elapsed: sinceRestrike * 1.3) }
            if sinceImpact >= 0 {
                let k = clamp(sinceImpact / 1.2)
                var glow = context
                glow.blendMode = .plusLighter
                let radius = 160 * (1 - k * 0.5)
                glow.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                          with: .radialGradient(Gradient(stops: [
                              .init(color: .white.opacity(0.95 * (1 - k)), location: 0),
                              .init(color: yellow.opacity(0.6 * (1 - k)), location: 0.25),
                              .init(color: bloom.opacity(0), location: 1)
                          ]), center: center, startRadius: 0, endRadius: radius))
            }
            if sinceImpact > 0.25 && t < T.dismiss + 0.15 {
                let alpha = sinceImpact < 0.4 ? 1 : clamp(1 - (t - (T.dismiss - 0.35)) / 0.5)
                drawLingeringArcs(context, button: scene.button, time: t, alpha: alpha)
            }
        }

        if showsArc, let arc = scene.arc, let item = scene.statusItem {
            drawMenuBarArc(context, arc: arc, item: item, time: t, frame: frame)
            drawPulse(context, item: item, elapsed: t - T.pulse)
        }

        // White flash on top for two frames, and one for the restrike.
        if sinceImpact >= 0 && sinceImpact < 2.0 / 60 {
            context.fill(Path(full), with: .color(.white))
        } else if sinceRestrike >= 0 && sinceRestrike < 1.0 / 60 {
            context.fill(Path(full), with: .color(.white.opacity(0.85)))
        }
    }

    // MARK: Reduce Motion

    /// No bolt, flash, shake or movement: a warm glow on Done and, when the
    /// status item is visible, a steady highlight on it.
    static func drawReduced(in context: GraphicsContext, scene: FinishSetupStrikeScene, showsStatusItem: Bool) {
        let center = CGPoint(x: scene.button.midX, y: scene.button.midY)
        var glow = context
        glow.blendMode = .plusLighter
        let radius: CGFloat = 90
        glow.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                  with: .radialGradient(Gradient(stops: [
                      .init(color: amber.opacity(0.55), location: 0),
                      .init(color: amber.opacity(0), location: 1)
                  ]), center: center, startRadius: 0, endRadius: radius))
        if showsStatusItem, let item = scene.statusItem { drawHalo(context, item: item, strength: 1) }
    }

    // MARK: Pieces

    static func drawStrike(_ context: GraphicsContext, _ bolt: LightningBolt, reach: Double, alpha: Double,
                           seed: UInt32, jitter amount: CGFloat) {
        for fork in bolt.forks where reach >= Double(fork.start) {
            let local = clamp((reach - Double(fork.start)) * 3)
            if fork.isSubFork {
                drawBolt(context, fork.points, reach: local, scale: S.subFork, alpha: alpha * 0.85)
            } else {
                drawBolt(context, jittered(fork.points, amount: amount * 0.7, seed: seed &+ 3), reach: local,
                         scale: S.fork, alpha: alpha * 0.95)
            }
        }
        drawBolt(context, jittered(bolt.points, amount: amount, seed: seed), reach: reach, scale: S.mainBolt, alpha: alpha)
    }

    /// Blue bloom, cyan glow, yellow rim, then a solid white core.
    static func drawBolt(_ context: GraphicsContext, _ points: [CGPoint], reach: Double, scale s: CGFloat, alpha: Double) {
        guard alpha > 0, points.count > 1 else { return }
        let path = polyline(points, reach: reach)
        func layer(_ width: CGFloat, _ color: Color, _ glow: Color, _ radius: CGFloat) {
            var layer = context
            layer.opacity = alpha
            layer.blendMode = .plusLighter
            layer.addFilter(.shadow(color: glow, radius: radius))
            layer.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .miter))
        }
        layer(26 * s, bloom.opacity(0.55), bloomGlow, 20 * s)
        layer(13 * s, cyan.opacity(0.9), cyanGlow, 9 * s)
        layer(7.5 * s, yellow.opacity(0.95), yellow, 4 * s)
        var core = context
        core.opacity = alpha
        core.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round, lineJoin: .miter))
    }

    static func drawTopCrackle(_ context: GraphicsContext, scene: FinishSetupStrikeScene, elapsed: TimeInterval) {
        let band = CGRect(x: 0, y: 0, width: scene.size.width, height: 90)
        context.fill(Path(band), with: .linearGradient(Gradient(colors: [
            Color(red: 120 / 255, green: 190 / 255, blue: 1).opacity(0.45 * clamp(elapsed / 0.3)),
            Color(red: 120 / 255, green: 190 / 255, blue: 1).opacity(0)
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 90)))
        let frame = Int(elapsed * 30)
        for (index, x) in scene.sparkColumns.enumerated() where (frame + index) % 3 == 0 {
            var random = StrikeRandom(seed: UInt32(frame * 977 + index))
            let length = 20 + random.next() * 60
            let end = CGPoint(x: x + (random.next() - 0.5) * length, y: 10 + random.next() * length)
            let points = LightningBolt.displaced(from: CGPoint(x: x, y: 0), to: end, displacement: length * 0.6, depth: 4,
                                                 seed: UInt32(frame * 53 + index))
            drawBolt(context, points, reach: 1, scale: 0.28, alpha: 0.9)
        }
        if elapsed > 0.18 {
            let reach = clamp((elapsed - 0.18) / 0.17) * 0.35
            drawBolt(context, jittered(scene.strike.points, amount: 10, seed: UInt32(frame)), reach: reach,
                     scale: S.preLeader, alpha: 0.33)
        }
    }

    static func drawSpeedLines(_ context: GraphicsContext, center: CGPoint, elapsed: TimeInterval, seed: UInt32) {
        guard elapsed >= 0, elapsed <= 0.45 else { return }
        var random = StrikeRandom(seed: seed &+ 1)
        let fade = 1 - elapsed / 0.45
        for index in 0..<90 {
            let angle = random.next() * .pi * 2
            let inner = 110 + random.next() * 160 + CGFloat(elapsed) * 300
            let spread = (2 + random.next() * 9) * CGFloat(fade) / 1400
            var wedge = Path()
            wedge.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            wedge.addLine(to: CGPoint(x: center.x + cos(angle + spread) * 1500, y: center.y + sin(angle + spread) * 1500))
            wedge.addLine(to: CGPoint(x: center.x + cos(angle - spread) * 1500, y: center.y + sin(angle - spread) * 1500))
            wedge.closeSubpath()
            let color = index % 3 == 0 ? Color(red: 1, green: 250 / 255, blue: 200 / 255).opacity(0.85 * fade)
                                       : Color.white.opacity(0.7 * fade)
            context.fill(wedge, with: .color(color))
        }
    }

    static func drawShockwave(_ context: GraphicsContext, center: CGPoint, elapsed: TimeInterval) {
        guard elapsed >= 0, elapsed <= 0.7 else { return }
        var rings = context
        rings.blendMode = .plusLighter
        let specs: [(delay: Double, radius: CGFloat, color: Color, width: CGFloat)] = [
            (0, 420, .white, 14), (0.06, 300, cyan, 8), (0.12, 200, yellow, 5)
        ]
        for spec in specs {
            let k = (elapsed - spec.delay) / (0.6 - spec.delay)
            guard k >= 0, k <= 1 else { continue }
            let radius = CGFloat(ease(k)) * spec.radius
            var ring = rings
            ring.addFilter(.shadow(color: spec.color, radius: 10))
            ring.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.55,
                                               width: radius * 2, height: radius * 1.1)),
                        with: .color(spec.color.opacity(1 - k)), lineWidth: spec.width * CGFloat(1 - k) + 1)
        }
        let k = elapsed / 0.25
        guard k < 1 else { return }
        var star = Path()
        let points = 24
        let outer = 180 * CGFloat(ease(k)) + 40
        for index in 0..<points {
            let angle = CGFloat(index) / CGFloat(points) * .pi * 2 + 0.2
            let radius = index % 2 == 1 ? 30 : outer * (index % 4 == 0 ? 1 : 0.65)
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius * 0.8)
            if index == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        rings.fill(star, with: .color(.white.opacity(1 - k)))
    }

    static func drawParticles(_ context: GraphicsContext, scene: FinishSetupStrikeScene, center: CGPoint, elapsed: TimeInterval) {
        guard elapsed >= 0, elapsed <= 1.3 else { return }
        let dt = CGFloat(elapsed)
        for particle in scene.particles {
            let k = dt / particle.life
            guard k <= 1 else { continue }
            let distance = particle.speed * dt * (1 - 0.45 * k)
            let point = CGPoint(x: center.x + cos(particle.angle) * distance,
                                y: center.y + sin(particle.angle) * distance + 600 * dt * dt)
            if particle.isSpark {
                let vx = cos(particle.angle) * particle.speed * (1 - 0.9 * k)
                let vy = sin(particle.angle) * particle.speed * (1 - 0.9 * k) + 1200 * dt
                var spark = context
                spark.blendMode = .plusLighter
                spark.opacity = Double(1 - k)
                spark.addFilter(.shadow(color: cyanGlow, radius: 4))
                var streak = Path()
                streak.move(to: point)
                streak.addLine(to: CGPoint(x: point.x - vx * 0.025, y: point.y - vy * 0.025))
                spark.stroke(streak, with: .color(sparkTints[particle.tint % sparkTints.count]), lineWidth: particle.size * 0.8)
            } else {
                var chip = context
                chip.opacity = Double(1 - k)
                chip.translateBy(x: point.x, y: point.y)
                chip.rotate(by: .radians(Double(particle.rotation + dt * 12)))
                chip.fill(Path(CGRect(x: -particle.size, y: -particle.size * 0.6, width: particle.size * 2, height: particle.size * 1.2)),
                          with: .color(k < 0.3 ? .white : debris))
            }
        }
    }

    static func drawLingeringArcs(_ context: GraphicsContext, button: CGRect, time: TimeInterval, alpha: Double) {
        guard alpha > 0 else { return }
        let frame = Int(time * 24)
        var random = StrikeRandom(seed: UInt32(frame * 13 + 7))
        for index in 0..<4 {
            guard random.next() <= 0.75 else { continue }
            let x = button.minX + random.next() * button.width
            let y = random.next() < 0.5 ? button.minY : button.maxY
            let angle = random.next() * .pi * 2
            let length = 18 + random.next() * 40
            let points = LightningBolt.displaced(from: CGPoint(x: x, y: y),
                                                 to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length),
                                                 displacement: length * 0.6, depth: 4, seed: UInt32(frame * 101 + index))
            drawBolt(context, points, reach: 1, scale: 0.32, alpha: alpha * Double(0.6 + 0.4 * random.next()))
        }
    }

    static func drawMenuBarArc(_ context: GraphicsContext, arc: LightningBolt, item: CGRect, time: TimeInterval, frame: Int) {
        let elapsed = time - T.arc
        guard elapsed >= 0, elapsed <= T.arcLife else { return }
        let reach = clamp(elapsed / T.arcTravel)
        let hold = T.arcTravel + 0.04
        let fade = elapsed < hold ? 1 : 1 - (elapsed - hold) / (T.arcLife - hold)
        let alpha = fade * (frame % 4 == 2 ? 0.45 : 1)
        for fork in arc.forks where reach >= Double(fork.start) {
            drawBolt(context, fork.points, reach: clamp((reach - Double(fork.start)) * 4), scale: S.menuBarArcFork, alpha: alpha * 0.9)
        }
        drawBolt(context, jittered(arc.points, amount: elapsed < T.arcTravel ? 0 : 3, seed: UInt32(frame)),
                 reach: reach, scale: S.menuBarArc, alpha: alpha)
        guard reach >= 1 else { return }
        let k = clamp((elapsed - T.arcTravel) / 0.13)
        let end = CGPoint(x: item.midX, y: item.maxY - 3)
        let radius = 70 * (1 - k * 0.4)
        var glow = context
        glow.blendMode = .plusLighter
        glow.fill(Path(ellipseIn: CGRect(x: end.x - radius, y: end.y - radius, width: radius * 2, height: radius * 2)),
                  with: .radialGradient(Gradient(stops: [
                      .init(color: .white.opacity(0.95 * (1 - k)), location: 0),
                      .init(color: amber.opacity(0.6 * (1 - k)), location: 0.3),
                      .init(color: bloom.opacity(0), location: 1)
                  ]), center: end, startRadius: 0, endRadius: radius))
    }

    static func drawPulse(_ context: GraphicsContext, item: CGRect, elapsed: TimeInterval) {
        guard elapsed > 0 else { return }
        let k = elapsed / T.pulseLength
        guard k < 1 else { return }
        drawHalo(context, item: item, strength: sin(.pi * k))
    }

    /// A warm halo around the status item. The item stays readable under it.
    static func drawHalo(_ context: GraphicsContext, item: CGRect, strength: Double) {
        guard strength > 0 else { return }
        let shape = Path(roundedRect: item.insetBy(dx: -3, dy: -1), cornerRadius: 6)
        var halo = context
        halo.opacity = strength
        halo.addFilter(.shadow(color: amber, radius: 9))
        halo.fill(shape, with: .color(amber.opacity(0.28)))
        halo.stroke(shape, with: .color(amber), lineWidth: 1.5)
    }

    // MARK: Helpers

    static func polyline(_ points: [CGPoint], reach: Double) -> Path {
        let count = max(2, min(points.count, Int(Double(points.count) * reach)))
        var path = Path()
        path.move(to: points[0])
        for point in points[1..<count] { path.addLine(to: point) }
        return path
    }

    static func jittered(_ points: [CGPoint], amount: CGFloat, seed: UInt32) -> [CGPoint] {
        guard amount > 0, points.count > 2 else { return points }
        var random = StrikeRandom(seed: seed &+ 11)
        return points.enumerated().map { index, point in
            guard index > 0, index < points.count - 1 else { return point }
            return CGPoint(x: point.x + (random.next() - 0.5) * amount, y: point.y + (random.next() - 0.5) * amount * 0.5)
        }
    }

    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    static func ease(_ value: Double) -> Double { 1 - pow(1 - clamp(value), 3) }
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}
