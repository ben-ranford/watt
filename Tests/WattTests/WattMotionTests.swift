import AppKit
import SwiftUI
import XCTest
@testable import Watt

/// Motion stays one-shot, inside 0.15–0.35s, and off while a surface is closed.
@MainActor
final class WattMotionTests: XCTestCase {
    func testDurationsStayInsideTheNativeRangeAndDoNotBounce() {
        for kind in WattMotion.Kind.allCases {
            for reduceMotion in [false, true] {
                let spec = WattMotion.spec(kind, reduceMotion: reduceMotion)
                if case .none = spec.curve {
                    XCTAssertNil(spec.animation)
                    XCTAssertEqual(spec.duration, 0)
                    continue
                }
                XCTAssertGreaterThanOrEqual(spec.duration, 0.15, kind.rawValue)
                XCTAssertLessThanOrEqual(spec.duration, 0.35, kind.rawValue)
                if case .spring(_, let damping) = spec.curve {
                    XCTAssertEqual(damping, 1, "Springs settle without bounce")
                }
                XCTAssertNotNil(spec.animation)
            }
        }
    }

    func testReduceMotionCrossfadesOrStaysStill() {
        for kind in WattMotion.Kind.allCases {
            let spec = WattMotion.spec(kind, reduceMotion: true)
            XCTAssertFalse(spec.animatesNumericText, kind.rawValue)
            XCTAssertFalse(spec.allowsMovement, kind.rawValue)
            switch kind {
            case .press:
                XCTAssertEqual(spec.curve, .none)
                XCTAssertNil(WattMotion.animation(kind, reduceMotion: true, enabled: true))
            case .numeric, .state, .reveal, .settle:
                XCTAssertEqual(spec.curve, .crossfade(WattMotion.crossfadeDuration))
                XCTAssertEqual(WattMotion.textMotion(reduceMotion: true, enabled: true, hasNumber: true), .opacity(.numeric))
            }
        }
    }

    func testOpenPanelRollsFiniteNumbersAndClosedPanelDoesNotAnimate() {
        XCTAssertEqual(WattMotion.textMotion(reduceMotion: false, enabled: true, hasNumber: true), .numericText)
        XCTAssertEqual(WattMotion.textMotion(reduceMotion: false, enabled: true, hasNumber: false), .opacity(.state))
        XCTAssertEqual(WattMotion.textMotion(reduceMotion: false, enabled: false, hasNumber: true), .instant)
        XCTAssertEqual(WattMotion.textMotion(reduceMotion: true, enabled: false, hasNumber: true), .instant)
        XCTAssertNil(WattMotion.animation(.numeric, reduceMotion: false, enabled: false))
        XCTAssertNil(WattMotion.animation(.settle, reduceMotion: false, enabled: false))
        XCTAssertNotNil(WattMotion.animation(.numeric, reduceMotion: false, enabled: true))
    }

    func testHiddenOrOccludedWindowsDoNotAllowMotion() {
        XCTAssertTrue(WattMotion.surfaceAllowsMotion(isVisible: true, isMiniaturized: false, occlusionVisible: true))
        XCTAssertFalse(WattMotion.surfaceAllowsMotion(isVisible: false, isMiniaturized: false, occlusionVisible: true))
        XCTAssertFalse(WattMotion.surfaceAllowsMotion(isVisible: true, isMiniaturized: true, occlusionVisible: true))
        XCTAssertFalse(WattMotion.surfaceAllowsMotion(isVisible: true, isMiniaturized: false, occlusionVisible: false))
    }

    func testStatusItemTextIsNeverAnimated() throws {
        XCTAssertFalse(WattMotion.animatesStatusItemText)
        let label = try source("Features/MenuBar/Components/MenuBarStatusLabel.swift")
        for forbidden in ["contentTransition", ".animation(", "withAnimation", "TimelineView",
                          "wattTextMotion", "WattMotion", "repeatForever"] {
            XCTAssertFalse(label.contains(forbidden), forbidden)
        }
        let app = try source("App/WattApp.swift")
        let update = try function("private func updateButton()", until: "private func startSampling()", in: app)
        XCTAssertTrue(update.contains("button.title = label.text ?? \"\""))
        for forbidden in ["animator()", "NSAnimationContext", "contentTransition", ".animation("] {
            XCTAssertFalse(update.contains(forbidden), forbidden)
        }
    }

    func testMotionSourceDoesNotScheduleWork() throws {
        let motion = try source("DesignSystem/Theme/WattMotion.swift")
        for forbidden in ["Timer(", "Timer.", "TimelineView", "repeatForever", "CADisplayLink",
                          "phaseAnimator", "keyframeAnimator", "Task.sleep", "asyncAfter",
                          "withAnimation"] {
            XCTAssertFalse(motion.contains(forbidden), forbidden)
        }
        XCTAssertTrue(motion.contains("NSWindow.didChangeOcclusionStateNotification"))
        XCTAssertTrue(motion.contains("NSWindow.willCloseNotification"))
        let panel = try source("Features/MenuBar/Views/StatusPanelView.swift")
        XCTAssertTrue(panel.contains("surfaceVisible"))
        XCTAssertTrue(panel.contains("wattObserveSurface"))
        XCTAssertTrue(panel.contains(".wattTextMotion(displayed: model.headlineValue, number: model.headlineNumber, enabled: motionEnabled)"))
        XCTAssertFalse(panel.contains(".background("))
        let shots = try source("Tests/WattTests/SiteScreenshotTests.swift")
        XCTAssertTrue(shots.contains(".environment(\\.wattMotionSuppressed, true)"))
    }

    func testStructureIgnoresWattChangesAndNumbersFollowTheHeadline() {
        let charging = PowerReading.sampleCharging
        let quieter = PowerReading(
            mode: charging.mode, watts: 3.5, batteryPercentage: charging.batteryPercentage,
            detail: charging.detail, components: charging.components, timestamp: charging.timestamp,
            batteryState: charging.batteryState, capabilities: charging.capabilities,
            freshness: charging.freshness, source: charging.source, chargerWatts: 40,
            systemWatts: 11, componentEstimate: charging.componentEstimate)
        XCTAssertEqual(StatusPanelModel(reading: charging).structure, StatusPanelModel(reading: quieter).structure)
        XCTAssertEqual(StatusPanelModel(reading: charging).headlineNumber, 42.1)
        XCTAssertEqual(StatusPanelModel(reading: quieter).headlineNumber, 3.5)
        XCTAssertEqual(StatusPanelModel(reading: charging).chargerNumber, 65)
        XCTAssertEqual(StatusPanelModel(reading: charging).systemNumber, 22.9)
        XCTAssertNil(StatusPanelModel(reading: .sampleOnBattery).chargerNumber)
        XCTAssertEqual(StatusPanelModel(reading: .sampleOnBattery).batteryNumber, -18.4)
        XCTAssertNil(StatusPanelModel(reading: .unavailable).headlineNumber)
        let components = StatusPanelModel(reading: charging).structure
        let without = PowerReading(
            mode: charging.mode, watts: charging.watts, batteryPercentage: charging.batteryPercentage,
            detail: charging.detail, components: [], timestamp: charging.timestamp,
            batteryState: charging.batteryState, capabilities: charging.capabilities,
            freshness: charging.freshness, source: charging.source, chargerWatts: charging.chargerWatts,
            systemWatts: charging.systemWatts)
        XCTAssertNotEqual(components, StatusPanelModel(reading: without).structure)
    }

    func testSuppressedMotionKeepsTheSettledPanelSize() {
        let settled = panelSize(suppressed: true)
        XCTAssertEqual(settled.width, 320)
        XCTAssertEqual(panelSize(suppressed: false).width, settled.width)
        let settings = settingsSize(suppressed: true)
        XCTAssertEqual(settings.width, settingsSize(suppressed: false).width)
        XCTAssertEqual(settings.width, WattSpacing.settingsWidth)
    }

    private func panelSize(suppressed: Bool) -> NSSize {
        let view = StatusPanelView(reading: .sampleCharging, chargerDescription: "96 W USB-C charger",
                                   onSettings: {}, onQuit: {})
            .environment(\.wattMotionSuppressed, suppressed)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 320, height: WattSpacing.panelHeight)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private func settingsSize(suppressed: Bool) -> NSSize {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter(updateService: FakeUpdateService())
        let view = SettingsRootView()
            .environmentObject(preferences)
            .environmentObject(router)
            .environmentObject(PowerReadingStore.preview)
            .environment(\.wattMotionSuppressed, suppressed)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: WattSpacing.settingsWidth, height: WattSpacing.settingsContentHeight)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func function(_ start: String, until end: String, in source: String) throws -> String {
        let lower = try XCTUnwrap(source.range(of: start))
        let upper = try XCTUnwrap(source.range(of: end, range: lower.upperBound..<source.endIndex))
        return String(source[lower.lowerBound..<upper.lowerBound])
    }
}
