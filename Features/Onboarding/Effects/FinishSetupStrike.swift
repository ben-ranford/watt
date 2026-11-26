import AppKit
import SwiftUI

// J1.6 Finish Setup lightning strike.
//
// Clicking Done on the last onboarding step fires a lightning bolt from the
// top of the screen onto the button, then a thinner arc up to the Watt?
// status item (only when that item is really visible). The effect lives in a
// borderless, click-through overlay panel that exists only while it plays,
// so there is no cost while idle. Reduce Motion shows a static glow instead.
// Design reference: the Finish Setup lightning page in the Watt Figma file, boards L1 to L6.

/// Seconds from the Done click. Matches the reviewed prototype.
enum FinishSetupStrikeTimeline {
    static let anticipation: TimeInterval = 0.08
    static let strike: TimeInterval = 0.42
    static let leader: TimeInterval = 0.06
    static let impact: TimeInterval = strike + leader
    static let restrike: TimeInterval = 0.64
    static let shake: TimeInterval = 0.55
    static let arc: TimeInterval = 1.08
    static let arcTravel: TimeInterval = 0.09
    static let arcLife: TimeInterval = 0.22
    static let pulse: TimeInterval = arc + arcTravel
    static let pulseLength: TimeInterval = 0.75
    static let windowFade: TimeInterval = 0.25
    static let dismiss: TimeInterval = 1.53
    static let end: TimeInterval = 2.68
    /// Reduce Motion: a static glow, then the window closes as usual.
    static let reducedDismiss: TimeInterval = 0.3
    static let reducedEnd: TimeInterval = 0.9
}

/// Line-width scales. 0.65 is the thinner bolt approved after review.
enum FinishSetupStrikeStyle {
    static let thickness: CGFloat = 0.65
    static let mainBolt: CGFloat = 1.15 * thickness
    static let fork: CGFloat = 0.55 * thickness
    static let subFork: CGFloat = 0.35 * thickness
    static let preLeader: CGFloat = 0.35 * thickness
    static let menuBarArc: CGFloat = 0.6 * thickness
    static let menuBarArcFork: CGFloat = 0.32 * thickness
    static let shakeAmplitude = CGSize(width: 10, height: 8)
}

/// xorshift32, so every bolt is reproducible from its seed.
struct StrikeRandom {
    private var state: UInt32
    init(seed: UInt32) { state = seed == 0 ? 1 : seed }
    mutating func next() -> CGFloat {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return CGFloat(state) / 4_294_967_296
    }
}

struct LightningBolt: Equatable, Sendable {
    struct Fork: Equatable, Sendable {
        var points: [CGPoint]
        /// Where on the main bolt the fork starts, 0...1.
        var start: CGFloat
        var isSubFork: Bool
    }

    var points: [CGPoint]
    var forks: [Fork]

    /// Midpoint displacement: split each segment, push the midpoint sideways
    /// by a shrinking random amount. Gives the jagged hand-drawn look.
    static func displaced(from start: CGPoint, to end: CGPoint, displacement: CGFloat,
                          depth: Int, seed: UInt32) -> [CGPoint] {
        var random = StrikeRandom(seed: seed)
        var points = [start]
        subdivide(start, end, displacement, depth, &random, &points)
        return points
    }

    private static func subdivide(_ a: CGPoint, _ b: CGPoint, _ displacement: CGFloat, _ depth: Int,
                                  _ random: inout StrikeRandom, _ out: inout [CGPoint]) {
        guard depth > 0 else { out.append(b); return }
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 1)
        let offset = (random.next() - 0.5) * displacement
        let mid = CGPoint(x: (a.x + b.x) / 2 - dy / length * offset, y: (a.y + b.y) / 2 + dx / length * offset)
        subdivide(a, mid, displacement * 0.55, depth - 1, &random, &out)
        subdivide(mid, b, displacement * 0.55, depth - 1, &random, &out)
    }

    /// The main strike. Coordinates are top-left origin, y grows downward.
    /// `upward` points the forks up for the arc to the menu bar.
    static func make(seed: UInt32, from start: CGPoint, to end: CGPoint, roughness: CGFloat,
                     depth: Int, forkCount: Int, upward: Bool) -> LightningBolt {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let main = displaced(from: start, to: end, displacement: distance * roughness, depth: depth, seed: seed)
        var random = StrikeRandom(seed: seed &* 7919)
        var forks: [Fork] = []
        let heading: CGFloat = upward ? -.pi / 2 : .pi / 2
        for index in 0..<forkCount {
            let at = Int((0.12 + 0.72 * random.next()) * CGFloat(main.count - 1))
            let origin = main[at]
            let side: CGFloat = random.next() < 0.5 ? -1 : 1
            let length = (upward ? 40 + random.next() * 70 : 80 + random.next() * 200 * (1 - CGFloat(at) / CGFloat(main.count) * 0.6))
            let angle = heading + side * (0.35 + random.next() * 0.7)
            let tip = CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
            let fork = displaced(from: origin, to: tip, displacement: length * 0.55, depth: 5,
                                 seed: seed &* 31 &+ UInt32(index))
            let start = CGFloat(at) / CGFloat(main.count)
            forks.append(Fork(points: fork, start: start, isSubFork: false))
            if !upward, random.next() < 0.6 {
                let pivot = fork[Int(CGFloat(fork.count - 1) * (0.3 + 0.4 * random.next()))]
                let subAngle = angle + side * (0.4 + random.next() * 0.5)
                let subLength = length * 0.45
                let subTip = CGPoint(x: pivot.x + cos(subAngle) * subLength, y: pivot.y + sin(subAngle) * subLength)
                forks.append(Fork(points: displaced(from: pivot, to: subTip, displacement: subLength * 0.5, depth: 4,
                                                    seed: seed &* 97 &+ UInt32(index)),
                                  start: start, isSubFork: true))
            }
        }
        return LightningBolt(points: main, forks: forks)
    }
}

/// Where the Watt? status item is, and whether a person can see it.
struct StatusItemPlacement: Equatable, Sendable {
    var hasWindow: Bool
    var windowIsVisible: Bool
    var occlusionIsVisible: Bool
    var itemFrame: CGRect
    var screenFrame: CGRect
    var visibleFrame: CGRect
    var auxiliaryTopLeft: CGRect?
    var auxiliaryTopRight: CGRect?

    /// The item frame in screen coordinates, or nil when the arc must be
    /// skipped: no window, not on screen, occluded, outside the visible
    /// menu-bar strip (hidden menu bar, overflow), or behind the notch.
    var target: CGRect? {
        guard hasWindow, windowIsVisible, occlusionIsVisible,
              itemFrame.width > 1, itemFrame.height > 1 else { return nil }
        let strip = CGRect(x: screenFrame.minX, y: visibleFrame.maxY,
                           width: screenFrame.width, height: screenFrame.maxY - visibleFrame.maxY)
        guard strip.height > 1, strip.insetBy(dx: -1, dy: -1).contains(itemFrame) else { return nil }
        if let left = auxiliaryTopLeft, let right = auxiliaryTopRight {
            guard left.insetBy(dx: -1, dy: -1).contains(itemFrame)
                    || right.insetBy(dx: -1, dy: -1).contains(itemFrame) else { return nil }
        }
        return itemFrame
    }

    @MainActor
    static func current(for button: NSView?) -> StatusItemPlacement? {
        guard let button else { return nil }
        guard let window = button.window, let screen = window.screen else {
            return StatusItemPlacement(hasWindow: button.window != nil, windowIsVisible: false, occlusionIsVisible: false,
                                       itemFrame: .zero, screenFrame: .zero, visibleFrame: .zero)
        }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        return StatusItemPlacement(hasWindow: true, windowIsVisible: window.isVisible,
                                   occlusionIsVisible: window.occlusionState.contains(.visible),
                                   itemFrame: frame, screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                   auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                                   auxiliaryTopRight: screen.auxiliaryTopRightArea)
    }
}

/// Everything the renderer needs, in the overlay's top-left coordinates.
struct FinishSetupStrikeScene: Equatable, Sendable {
    struct Particle: Equatable, Sendable {
        var angle: CGFloat, speed: CGFloat, life: CGFloat, size: CGFloat, rotation: CGFloat
        var isSpark: Bool, tint: Int
    }

    var size: CGSize
    var button: CGRect
    var statusItem: CGRect?
    var reduced: Bool
    var strike: LightningBolt
    var restrike: LightningBolt
    var arc: LightningBolt?
    var particles: [Particle]
    var sparkColumns: [CGFloat]

    init(screenFrame: CGRect, doneButton: CGRect, statusItem: CGRect?, reduced: Bool) {
        let localButton = Self.local(doneButton, in: screenFrame)
        let localItem = statusItem.map { Self.local($0, in: screenFrame) }
        size = screenFrame.size
        button = localButton
        self.statusItem = localItem
        self.reduced = reduced
        let center = CGPoint(x: localButton.midX, y: localButton.midY)
        var random = StrikeRandom(seed: 7)
        strike = LightningBolt.make(seed: 7, from: CGPoint(x: center.x - 90 + random.next() * 60, y: 0), to: center,
                                    roughness: 0.55, depth: 8, forkCount: 6, upward: false)
        restrike = LightningBolt.make(seed: 23, from: CGPoint(x: center.x - 60 + random.next() * 60, y: 0), to: center,
                                      roughness: 0.55, depth: 8, forkCount: 6, upward: false)
        arc = localItem.map { item in
            LightningBolt.make(seed: 311, from: CGPoint(x: localButton.midX + 6, y: localButton.minY + 2),
                               to: CGPoint(x: item.midX, y: item.maxY - 3),
                               roughness: 0.33, depth: 7, forkCount: 3, upward: true)
        }
        var particleRandom = StrikeRandom(seed: 424_242)
        particles = (0..<150).map { _ in
            var angle = -.pi * particleRandom.next()
            if particleRandom.next() < 0.25 { angle += .pi * particleRandom.next() }
            return Particle(angle: angle, speed: 250 + particleRandom.next() * 900, life: 0.35 + particleRandom.next() * 0.75,
                            size: 1.5 + particleRandom.next() * 3.5, rotation: particleRandom.next() * 6,
                            isSpark: particleRandom.next() < 0.7, tint: Int(particleRandom.next() * 3))
        }
        var columnRandom = StrikeRandom(seed: 99)
        sparkColumns = (0..<40).map { _ in columnRandom.next() * screenFrame.width }
    }

    /// Screen coordinates (bottom-left origin) to overlay coordinates.
    static func local(_ rect: CGRect, in screen: CGRect) -> CGRect {
        CGRect(x: rect.minX - screen.minX, y: screen.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

enum FinishSetupStrikeMode: Equatable { case full, reduced, skipped }

struct FinishSetupStrikeRequest {
    /// The Done button in screen coordinates.
    var doneButtonFrame: CGRect?
    weak var hostWindow: NSWindow?
    /// Read at play time and again just before the arc fires.
    var statusItemPlacement: () -> StatusItemPlacement?
}

@MainActor
protocol FinishSetupStrikePlaying: AnyObject {
    func play(_ request: FinishSetupStrikeRequest, onDismiss: @escaping () -> Void)
}

@MainActor
protocol FinishSetupStrikeScheduling: AnyObject {
    /// `delay` is measured from the start of the strike.
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}

@MainActor
final class MainQueueStrikeScheduler: FinishSetupStrikeScheduling {
    private var work: [Int: () -> Void] = [:]
    private var nextID = 0
    private let start = DispatchTime.now()

    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        work[id] = block
        let deadline = start + delay
        Task { @MainActor [weak self] in
            let now = DispatchTime.now()
            if deadline > now { try? await Task.sleep(nanoseconds: deadline.uptimeNanoseconds - now.uptimeNanoseconds) }
            self?.work.removeValue(forKey: id)?()
        }
    }
}

/// Live values the overlay view reads while it plays.
@MainActor
final class FinishSetupStrikeState: ObservableObject {
    let scene: FinishSetupStrikeScene
    let start: Date
    /// Cleared if the status item stops being visible before the arc fires.
    @Published var showsMenuBarArc: Bool

    init(scene: FinishSetupStrikeScene, start: Date = Date()) {
        self.scene = scene
        self.start = start
        showsMenuBarArc = scene.arc != nil
    }
}

@MainActor
final class FinishSetupStrikeController: FinishSetupStrikePlaying {
    static let shared = FinishSetupStrikeController()
    static let windowIdentifier = NSUserInterfaceItemIdentifier("watt.finishSetupStrike")

    private(set) var hasPlayed = false
    private(set) var lastMode: FinishSetupStrikeMode?
    private(set) var overlay: NSPanel?
    private(set) var state: FinishSetupStrikeState?
    private let reduceMotion: () -> Bool
    private let makeScheduler: () -> any FinishSetupStrikeScheduling
    private let haptics: () -> Void
    private weak var shakenWindow: NSWindow?
    private var restingOrigin: CGPoint?
    private weak var fadedWindow: NSWindow?

    /// Defaults read Reduce Motion, use the main queue and the trackpad.
    init(reduceMotion: (() -> Bool)? = nil,
         scheduler: (() -> any FinishSetupStrikeScheduling)? = nil,
         haptics: (() -> Void)? = nil) {
        self.reduceMotion = reduceMotion ?? { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        makeScheduler = scheduler ?? { MainQueueStrikeScheduler() }
        self.haptics = haptics ?? { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
    }

    /// Plays once per launch. Any later call, or a request without a
    /// button frame, dismisses straight away so setup never gets stuck.
    func play(_ request: FinishSetupStrikeRequest, onDismiss: @escaping () -> Void) {
        guard !hasPlayed else { lastMode = .skipped; onDismiss(); return }
        hasPlayed = true
        guard let done = request.doneButtonFrame,
              let screen = Self.screen(containing: done) ?? request.hostWindow?.screen else {
            lastMode = .skipped
            onDismiss()
            return
        }
        let reduced = reduceMotion()
        lastMode = reduced ? .reduced : .full
        let target = Self.arcTarget(request.statusItemPlacement(), on: screen.frame)
        let state = FinishSetupStrikeState(scene: FinishSetupStrikeScene(screenFrame: screen.frame, doneButton: done,
                                                                         statusItem: target, reduced: reduced))
        self.state = state
        let panel = Self.makeOverlay(frame: screen.frame, state: state)
        overlay = panel
        panel.orderFrontRegardless()
        let scheduler = makeScheduler()
        typealias T = FinishSetupStrikeTimeline
        if reduced {
            scheduler.schedule(after: T.reducedDismiss) { onDismiss() }
            scheduler.schedule(after: T.reducedEnd) { [weak self] in self?.tearDown() }
            return
        }
        scheduler.schedule(after: T.impact) { [weak self] in self?.haptics() }
        if let window = request.hostWindow { scheduleShake(window, scheduler: scheduler) }
        scheduler.schedule(after: T.arc) { [weak state] in
            guard let state, state.showsMenuBarArc else { return }
            if Self.arcTarget(request.statusItemPlacement(), on: screen.frame) == nil { state.showsMenuBarArc = false }
        }
        if let window = request.hostWindow { scheduleFade(window, scheduler: scheduler) }
        scheduler.schedule(after: T.dismiss) { onDismiss() }
        scheduler.schedule(after: T.end) { [weak self] in self?.tearDown() }
    }

    /// Closes and releases the overlay and puts the host window back.
    func tearDown() {
        if let window = shakenWindow, let origin = restingOrigin { window.setFrameOrigin(origin) }
        shakenWindow = nil
        restingOrigin = nil
        fadedWindow?.alphaValue = 1
        fadedWindow = nil
        overlay?.orderOut(nil)
        overlay?.contentView = nil
        overlay?.close()
        overlay = nil
        state = nil
    }

    /// Fades the onboarding window out in steps so it closes softly.
    private func scheduleFade(_ window: NSWindow, scheduler: any FinishSetupStrikeScheduling) {
        typealias T = FinishSetupStrikeTimeline
        let steps = Int(T.windowFade * 60)
        for step in 1...steps {
            let alpha = 1 - CGFloat(step) / CGFloat(steps)
            scheduler.schedule(after: T.dismiss - T.windowFade + Double(step) / 60) { [weak self, weak window] in
                guard let self, let window else { return }
                fadedWindow = window
                window.alphaValue = alpha
            }
        }
    }

    static func arcTarget(_ placement: StatusItemPlacement?, on screen: CGRect) -> CGRect? {
        guard let placement, placement.screenFrame == screen else { return nil }
        return placement.target
    }

    private func scheduleShake(_ window: NSWindow, scheduler: any FinishSetupStrikeScheduling) {
        typealias T = FinishSetupStrikeTimeline
        shakenWindow = window
        restingOrigin = window.frame.origin
        let steps = Int(T.shake * 60)
        var random = StrikeRandom(seed: 31)
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let falloff = pow(1 - progress, 2)
            let offset = step == steps ? CGSize.zero : CGSize(
                width: (random.next() - 0.5) * 2 * FinishSetupStrikeStyle.shakeAmplitude.width * falloff,
                height: (random.next() - 0.5) * 2 * FinishSetupStrikeStyle.shakeAmplitude.height * falloff)
            scheduler.schedule(after: T.impact + Double(step) / 60) { [weak self, weak window] in
                guard let self, let window, let origin = restingOrigin, shakenWindow === window else { return }
                window.setFrameOrigin(CGPoint(x: origin.x + offset.width, y: origin.y + offset.height))
            }
        }
    }

    private static func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }
    }

    private static func makeOverlay(frame: CGRect, state: FinishSetupStrikeState) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.identifier = windowIdentifier
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.setAccessibilityElement(false)
        let host = NSHostingView(rootView: FinishSetupStrikeView(state: state))
        host.setAccessibilityElement(false)
        panel.contentView = host
        panel.setFrame(frame, display: false)
        return panel
    }
}

/// Remembers the Done button's AppKit view so the strike can aim at it.
@MainActor
final class FinishSetupStrikeAnchor {
    fileprivate weak var view: NSView?

    var screenFrame: CGRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    func request(router: AppRouter) -> FinishSetupStrikeRequest {
        FinishSetupStrikeRequest(doneButtonFrame: screenFrame, hostWindow: view?.window,
                                 statusItemPlacement: { [weak router] in
                                     StatusItemPlacement.current(for: router?.statusItemButton())
                                 })
    }
}

private final class FinishSetupStrikeAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func isAccessibilityElement() -> Bool { false }
}

private struct FinishSetupStrikeAnchorRepresentable: NSViewRepresentable {
    let anchor: FinishSetupStrikeAnchor

    func makeNSView(context: Context) -> NSView {
        let view = FinishSetupStrikeAnchorView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { anchor.view = nsView }
}

extension View {
    /// Marks the view the Finish Setup strike lands on. Invisible, never hit-tested.
    func finishSetupStrikeAnchor(_ anchor: FinishSetupStrikeAnchor) -> some View {
        background(FinishSetupStrikeAnchorRepresentable(anchor: anchor))
    }
}
