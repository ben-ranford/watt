import AppKit
import XCTest
@testable import Watt

@MainActor
private final class ManualStrikeScheduler: FinishSetupStrikeScheduling {
    private var pending: [(delay: TimeInterval, order: Int, work: () -> Void)] = []
    private var order = 0
    private(set) var now: TimeInterval = 0

    var delays: [TimeInterval] { pending.map(\.delay).sorted() }

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        pending.append((delay, order, work))
        order += 1
    }

    /// Runs everything due by `time`, in time order.
    func run(until time: TimeInterval = .infinity) {
        while let next = pending.enumerated().filter({ $0.element.delay <= time })
            .min(by: { ($0.element.delay, $0.element.order) < ($1.element.delay, $1.element.order) }) {
            pending.remove(at: next.offset)
            now = next.element.delay
            next.element.work()
        }
    }
}

@MainActor
private final class RecordingStrike: FinishSetupStrikePlaying {
    var plays = 0
    var finish: (() -> Void)?
    func play(_ request: FinishSetupStrikeRequest, onDismiss: @escaping () -> Void) {
        plays += 1
        finish = onDismiss
    }
}

@MainActor
final class FinishSetupStrikeTests: XCTestCase {
    private typealias T = FinishSetupStrikeTimeline

    // MARK: Timeline and style

    func testTimelineFollowsThePrototypeOrderAndLength() {
        let beats = [T.anticipation, T.strike, T.impact, T.restrike, T.arc, T.pulse, T.dismiss, T.end]
        XCTAssertEqual(beats, beats.sorted())
        XCTAssertEqual(T.impact, T.strike + T.leader, accuracy: 0.0001)
        XCTAssertEqual(T.pulse, T.arc + T.arcTravel, accuracy: 0.0001, "The item pulses as the arc lands")
        XCTAssertTrue((0.15...0.25).contains(T.arcLife), "Arc to the menu bar lasts about 150 to 250 ms")
        XCTAssertGreaterThan(T.arc, T.impact, "The arc fires after the impact")
        XCTAssertLessThan(T.arc + T.arcLife, T.dismiss, "The arc finishes before the window closes")
        XCTAssertTrue((2.5...3.5).contains(T.end))
        XCTAssertLessThan(T.reducedDismiss, T.reducedEnd)
        XCTAssertLessThan(T.reducedEnd, 1)
    }

    func testBoltsUseTheThinnerApprovedStyle() {
        XCTAssertEqual(FinishSetupStrikeStyle.thickness, 0.65)
        XCTAssertEqual(FinishSetupStrikeStyle.mainBolt, 1.15 * 0.65, accuracy: 0.0001)
        XCTAssertLessThan(FinishSetupStrikeStyle.fork, FinishSetupStrikeStyle.mainBolt)
        XCTAssertLessThan(FinishSetupStrikeStyle.subFork, FinishSetupStrikeStyle.fork)
        XCTAssertLessThan(FinishSetupStrikeStyle.menuBarArc, FinishSetupStrikeStyle.mainBolt, "The menu-bar arc is thinner")
        XCTAssertLessThan(FinishSetupStrikeStyle.menuBarArcFork, FinishSetupStrikeStyle.menuBarArc)
    }

    // MARK: Geometry

    func testStrikeStartsAtTheTopOfTheScreenAndLandsOnDone() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let done = CGRect(x: 820, y: 300, width: 65, height: 24)
        let scene = FinishSetupStrikeScene(screenFrame: screen, doneButton: done, statusItem: nil, reduced: false)
        XCTAssertEqual(scene.button, CGRect(x: 820, y: 576, width: 65, height: 24), "Flipped into top-left coordinates")
        let center = CGPoint(x: scene.button.midX, y: scene.button.midY)
        for bolt in [scene.strike, scene.restrike] {
            XCTAssertEqual(bolt.points.first?.y, 0, "Starts at the very top edge")
            XCTAssertEqual(bolt.points.last, center, "Lands on the Done button")
            XCTAssertEqual(bolt.points.count, 257, "Eight rounds of midpoint displacement")
            XCTAssertGreaterThanOrEqual(bolt.forks.count, 6)
            XCTAssertTrue(bolt.forks.allSatisfy { (0...1).contains($0.start) })
        }
        XCTAssertNil(scene.arc)
        let again = FinishSetupStrikeScene(screenFrame: screen, doneButton: done, statusItem: nil, reduced: false)
        XCTAssertEqual(scene, again, "Seeded, so every play draws the same bolt")
    }

    func testMenuBarArcTravelsUpFromDoneToTheStatusItem() throws {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let done = CGRect(x: 820, y: 300, width: 65, height: 24)
        let item = CGRect(x: 1100, y: 876, width: 60, height: 24)
        let scene = FinishSetupStrikeScene(screenFrame: screen, doneButton: done, statusItem: item, reduced: false)
        let arc = try XCTUnwrap(scene.arc)
        let local = try XCTUnwrap(scene.statusItem)
        XCTAssertEqual(local.minY, 0)
        let start = try XCTUnwrap(arc.points.first)
        let end = try XCTUnwrap(arc.points.last)
        XCTAssertGreaterThan(start.y, end.y, "Travels upward")
        XCTAssertEqual(start.y, scene.button.minY + 2)
        XCTAssertEqual(end, CGPoint(x: local.midX, y: local.maxY - 3))
        XCTAssertEqual(arc.forks.count, 3)
    }

    func testMidpointDisplacementKeepsItsEndpoints() {
        let start = CGPoint(x: 10, y: 0), end = CGPoint(x: 200, y: 400)
        let points = LightningBolt.displaced(from: start, to: end, displacement: 100, depth: 4, seed: 5)
        XCTAssertEqual(points.count, 17)
        XCTAssertEqual(points.first, start)
        XCTAssertEqual(points.last, end)
        XCTAssertNotEqual(points, LightningBolt.displaced(from: start, to: end, displacement: 100, depth: 4, seed: 6))
    }

    // MARK: Status item visibility

    private func placement(item: CGRect = CGRect(x: 1100, y: 876, width: 60, height: 24),
                           window: Bool = true, visible: Bool = true, unoccluded: Bool = true,
                           visibleTop: CGFloat = 876, notch: Bool = false) -> StatusItemPlacement {
        StatusItemPlacement(hasWindow: window, windowIsVisible: visible, occlusionIsVisible: unoccluded,
                            itemFrame: item, screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: visibleTop),
                            auxiliaryTopLeft: notch ? CGRect(x: 0, y: 876, width: 620, height: 24) : nil,
                            auxiliaryTopRight: notch ? CGRect(x: 820, y: 876, width: 620, height: 24) : nil)
    }

    func testArcTargetsAVisibleStatusItem() {
        XCTAssertEqual(placement().target, CGRect(x: 1100, y: 876, width: 60, height: 24))
        XCTAssertNotNil(placement(notch: true).target, "Right of the notch is visible")
    }

    func testArcIsSkippedWhenTheStatusItemCannotBeSeen() {
        XCTAssertNil(placement(window: false).target, "No window")
        XCTAssertNil(placement(visible: false).target, "Window not on screen")
        XCTAssertNil(placement(unoccluded: false).target, "Occluded")
        XCTAssertNil(placement(item: CGRect(x: 660, y: 876, width: 60, height: 24), notch: true).target, "Behind the notch")
        XCTAssertNil(placement(item: CGRect(x: -80, y: 876, width: 60, height: 24)).target, "Pushed off screen")
        XCTAssertNil(placement(item: CGRect(x: 1100, y: 500, width: 60, height: 24)).target, "Not in the menu bar")
        XCTAssertNil(placement(visibleTop: 900).target, "Menu bar hidden")
        XCTAssertNil(placement(item: CGRect(x: 1100, y: 876, width: 0, height: 24)).target, "Zero width")
        XCTAssertNil(StatusItemPlacement.current(for: nil))
        XCTAssertNil(FinishSetupStrikeController.arcTarget(placement(), on: CGRect(x: 1440, y: 0, width: 1920, height: 1080)),
                     "Status item on another display")
    }

    func testDetachedStatusButtonHasNoTarget() throws {
        let placement = try XCTUnwrap(StatusItemPlacement.current(for: NSButton()))
        XCTAssertFalse(placement.hasWindow)
        XCTAssertNil(placement.target)
    }

    // MARK: Controller

    private func makeHost() -> NSWindow {
        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let window = NSWindow(contentRect: CGRect(x: screen.midX - 240, y: screen.midY - 160, width: 480, height: 320),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        return window
    }

    private func request(host: NSWindow?, placement: @escaping () -> StatusItemPlacement? = { nil }) -> FinishSetupStrikeRequest {
        let frame = host?.frame ?? (NSScreen.main?.frame ?? .zero)
        return FinishSetupStrikeRequest(doneButtonFrame: CGRect(x: frame.maxX - 97, y: frame.minY + 36, width: 65, height: 24),
                                        hostWindow: host, statusItemPlacement: placement)
    }

    private func overlayWindowsOnScreen() -> [NSWindow] {
        NSApplication.shared.windows.filter { $0.identifier == FinishSetupStrikeController.windowIdentifier && $0.isVisible }
    }

    func testIdleControllerHasNoOverlay() {
        let controller = FinishSetupStrikeController(scheduler: { ManualStrikeScheduler() })
        XCTAssertFalse(controller.hasPlayed)
        XCTAssertNil(controller.overlay)
        XCTAssertNil(controller.state)
    }

    func testFullStrikeShakesFadesDismissesOnceAndCleansUp() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Needs a display")
        let scheduler = ManualStrikeScheduler()
        var haptics = 0
        let controller = FinishSetupStrikeController(reduceMotion: { false }, scheduler: { scheduler }, haptics: { haptics += 1 })
        let host = makeHost()
        defer { host.close() }
        let resting = host.frame.origin
        var dismissals = 0
        controller.play(request(host: host)) { dismissals += 1 }

        XCTAssertEqual(controller.lastMode, .full)
        let overlay = try XCTUnwrap(controller.overlay)
        XCTAssertEqual(overlay.identifier, FinishSetupStrikeController.windowIdentifier)
        XCTAssertTrue(overlay.ignoresMouseEvents, "Clicks pass through")
        XCTAssertFalse(overlay.isOpaque)
        XCTAssertFalse(overlay.canBecomeKey)
        XCTAssertGreaterThan(overlay.level.rawValue, NSWindow.Level.statusBar.rawValue, "Above the menu bar")
        XCTAssertTrue(overlay.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertEqual(scheduler.delays.max(), T.end)
        XCTAssertEqual(dismissals, 0, "The window stays while the bolt plays")

        scheduler.run(until: T.impact + 0.1)
        XCTAssertEqual(haptics, 1)
        XCTAssertNotEqual(host.frame.origin, resting, "The window shakes on impact")
        scheduler.run(until: T.dismiss - 0.01)
        XCTAssertEqual(dismissals, 0)
        XCTAssertEqual(host.frame.origin, resting, "The shake settles back")
        scheduler.run(until: T.dismiss)
        XCTAssertEqual(dismissals, 1)
        XCTAssertNotNil(controller.overlay, "The pulse keeps playing after the window closes")
        scheduler.run()
        XCTAssertEqual(dismissals, 1)
        XCTAssertNil(controller.overlay, "Overlay released at the end")
        XCTAssertNil(controller.state)
        XCTAssertFalse(overlay.isVisible)
        XCTAssertNil(overlay.contentView)
        XCTAssertEqual(host.alphaValue, 1)
        XCTAssertEqual(host.frame.origin, resting)
        XCTAssertTrue(overlayWindowsOnScreen().isEmpty)
    }

    func testReduceMotionShowsAStaticGlowWithoutShakeOrHaptics() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Needs a display")
        let scheduler = ManualStrikeScheduler()
        var haptics = 0
        let controller = FinishSetupStrikeController(reduceMotion: { true }, scheduler: { scheduler }, haptics: { haptics += 1 })
        let host = makeHost()
        defer { host.close() }
        let resting = host.frame.origin
        var dismissals = 0
        controller.play(request(host: host)) { dismissals += 1 }

        XCTAssertEqual(controller.lastMode, .reduced)
        XCTAssertEqual(controller.state?.scene.reduced, true, "Static Canvas, no timeline")
        XCTAssertEqual(scheduler.delays, [T.reducedDismiss, T.reducedEnd], "No shake, fade, flash or arc steps")
        scheduler.run()
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(haptics, 0)
        XCTAssertEqual(host.frame.origin, resting)
        XCTAssertEqual(host.alphaValue, 1)
        XCTAssertNil(controller.overlay)
        XCTAssertTrue(overlayWindowsOnScreen().isEmpty)
    }

    func testPlaysOnlyOnce() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Needs a display")
        let scheduler = ManualStrikeScheduler()
        let controller = FinishSetupStrikeController(reduceMotion: { false }, scheduler: { scheduler }, haptics: {})
        var dismissals = 0
        controller.play(request(host: nil)) { dismissals += 1 }
        let scheduled = scheduler.delays.count
        let first = controller.overlay
        controller.play(request(host: nil)) { dismissals += 1 }
        XCTAssertEqual(controller.lastMode, .skipped)
        XCTAssertEqual(dismissals, 1, "A repeat dismisses straight away")
        XCTAssertEqual(scheduler.delays.count, scheduled, "Nothing new is scheduled")
        XCTAssertTrue(controller.overlay === first)
        scheduler.run()
        XCTAssertEqual(dismissals, 2)
        XCTAssertNil(controller.overlay)
    }

    func testMissingButtonFrameDismissesWithoutAnOverlay() {
        let scheduler = ManualStrikeScheduler()
        let controller = FinishSetupStrikeController(reduceMotion: { false }, scheduler: { scheduler })
        var dismissals = 0
        controller.play(FinishSetupStrikeRequest(doneButtonFrame: nil, hostWindow: nil, statusItemPlacement: { nil })) {
            dismissals += 1
        }
        XCTAssertEqual(controller.lastMode, .skipped)
        XCTAssertEqual(dismissals, 1)
        XCTAssertNil(controller.overlay)
        XCTAssertTrue(scheduler.delays.isEmpty)
    }

    func testHiddenStatusItemGetsNoArcOrPulse() throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "Needs a display")
        let scheduler = ManualStrikeScheduler()
        let controller = FinishSetupStrikeController(reduceMotion: { false }, scheduler: { scheduler }, haptics: {})
        controller.play(request(host: nil, placement: { nil })) {}
        XCTAssertNil(controller.state?.scene.arc)
        XCTAssertEqual(controller.state?.showsMenuBarArc, false)
        scheduler.run()
    }

    func testArcIsCancelledIfTheStatusItemDisappearsBeforeItFires() throws {
        let screen = try XCTUnwrap(NSScreen.main, "Needs a display")
        let visibleTop = screen.visibleFrame.maxY
        try XCTSkipIf(screen.frame.maxY - visibleTop < 2, "Menu bar is hidden on this display")
        var visible = true
        let item = CGRect(x: screen.frame.maxX - 200, y: visibleTop, width: 60, height: screen.frame.maxY - visibleTop)
        let placement: () -> StatusItemPlacement? = {
            StatusItemPlacement(hasWindow: true, windowIsVisible: visible, occlusionIsVisible: true, itemFrame: item,
                                screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
        }
        let scheduler = ManualStrikeScheduler()
        let controller = FinishSetupStrikeController(reduceMotion: { false }, scheduler: { scheduler }, haptics: {})
        let host = makeHost()
        defer { host.close() }
        controller.play(request(host: host, placement: placement)) {}
        let state = try XCTUnwrap(controller.state)
        XCTAssertNotNil(state.scene.arc)
        XCTAssertTrue(state.showsMenuBarArc)
        visible = false
        scheduler.run(until: T.arc)
        XCTAssertFalse(state.showsMenuBarArc, "Checked again right before the arc fires")
        scheduler.run()
    }

    // MARK: All set

    func testDoneSavesOnceThenClosesAndOpensTheCoachMarkAfterTheStrike() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .allSet, helperOptIn: true)
        let router = AppRouter()
        var events: [String] = []
        router.present = { destination in
            XCTAssertEqual(destination, .coachMark)
            events.append("coachMark")
        }
        let strike = RecordingStrike()
        let request = FinishSetupStrikeRequest(doneButtonFrame: nil, hostWindow: nil, statusItemPlacement: { nil })
        AllSetView.finish(preferences: preferences, router: router, strike: strike, request: request) { events.append("dismiss") }
        AllSetView.finish(preferences: preferences, router: router, strike: strike, request: request) { events.append("duplicate") }
        XCTAssertEqual(strike.plays, 1, "Plays once")
        XCTAssertTrue(PreferencesStore(storage: storage).onboarding.completed, "Saved before the strike")
        XCTAssertEqual(events, [], "Nothing closes until the strike says so")
        XCTAssertTrue(router.finishSetupStrikePlaying, "The window keeps showing That's it during the strike")
        strike.finish?()
        XCTAssertEqual(events, ["dismiss", "coachMark"])
        XCTAssertFalse(router.finishSetupStrikePlaying)
    }

    func testSetupWindowKeepsThatsItWhileTheStrikePlays() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let flow = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        XCTAssertTrue(flow.contains("preferences.onboarding.checkpoint == .allSet || router.finishSetupStrikePlaying"),
                      "Saving moves the checkpoint on; the window must not fall through to the unavailable step")
    }

    func testDefaultSchedulerFinishesTheStrikeAfterPlayReturns() async throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let done = CGRect(x: screen.frame.midX - 30, y: screen.frame.midY - 12, width: 60, height: 24)
        for reduced in [true, false] {
            // The real main-queue scheduler, not the manual one. Nothing else keeps it alive.
            let controller = FinishSetupStrikeController(reduceMotion: { reduced }, haptics: {})
            let dismissed = expectation(description: "dismissed reduced=\(reduced)")
            controller.play(FinishSetupStrikeRequest(doneButtonFrame: done, hostWindow: nil, statusItemPlacement: { nil })) {
                dismissed.fulfill()
            }
            XCTAssertNotNil(controller.overlay)
            await fulfillment(of: [dismissed], timeout: 5)
            let end = reduced ? T.reducedEnd : T.end
            try await Task.sleep(nanoseconds: UInt64((end + 0.5) * 1_000_000_000))
            XCTAssertNil(controller.overlay, "The overlay closes on its own, reduced=\(reduced)")
            XCTAssertNil(controller.state)
        }
    }

    func testFailedSaveDoesNotStrike() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding.checkpoint = .allSet
        storage.failWrites = true
        let strike = RecordingStrike()
        AllSetView.finish(preferences: preferences, router: AppRouter(), strike: strike,
                          request: FinishSetupStrikeRequest(doneButtonFrame: nil, hostWindow: nil, statusItemPlacement: { nil })) {
            XCTFail("Must not dismiss")
        }
        XCTAssertEqual(strike.plays, 0)
        XCTAssertFalse(preferences.onboarding.completed)
    }

    func testDoneButtonUsesTheStrikeAndKeepsNativeChrome() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let flow = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        let view = flow.components(separatedBy: "struct AllSetView")[1].components(separatedBy: "/// J1.5")[0]
        XCTAssertTrue(view.contains("strike: FinishSetupStrikeController.shared"))
        XCTAssertTrue(view.contains(".finishSetupStrikeAnchor(strikeAnchor)"))
        let effect = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Effects/FinishSetupStrike.swift"), encoding: .utf8)
        XCTAssertTrue(effect.contains("accessibilityDisplayShouldReduceMotion"))
        XCTAssertTrue(effect.contains("panel.ignoresMouseEvents = true"))
    }
}
