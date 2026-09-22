import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J92HelperRemovedTests: XCTestCase {
    func testExactFixtureAndFailClosedSelectors() throws {
        let fixture = try ScenarioRegistry.resolve("J9.2")
        XCTAssertEqual(fixture.story.node, "32:5844")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let args = ["Watt", "--watt-fixture", "J9.2/base"]
        XCTAssertEqual(try FixtureLaunchSelection.parse(args)?.smokeLaunchArguments(), Array(args.dropFirst()))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J92FixtureLaunch.matches(arguments: args))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
        #else
        XCTAssertTrue(J92FixtureLaunch.matches(arguments: args))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
        #endif
        for value in ["J9.2", "J9.2/", "J9.2/dark", "J9.2//base", "J9.2/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
    }

    func testVerifiedRemovalPreservesPreferencesAndStatusItem() async {
        let preferences = J92FixtureLaunch.makePreferences()
        preferences.openAtLogin = true
        preferences.smoothReadings = false
        let router = AppRouter()
        await J92FixtureLaunch.prepare(router: router, preferences: preferences)
        XCTAssertTrue(router.settingsHelperSetup.wasRemoved)
        XCTAssertFalse(router.settingsHelperSetup.helperOn)
        XCTAssertFalse(router.settingsHelperSetup.helperSwitchedOff)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertEqual(preferences.displayMode, .delta)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertTrue(preferences.openAtLogin)
        XCTAssertFalse(preferences.smoothReadings)
        XCTAssertTrue(preferences.showSymbol)
        XCTAssertEqual(preferences.precision, .decimal)
        XCTAssertEqual(router.settingsHelperSetup.statusTitle, "Off")
        XCTAssertEqual(router.settingsHelperSetup.actionTitle, "Turn On…")
        let reading = J92FixtureLaunch.makeStore().currentReading
        XCTAssertEqual(MenuBarStatusLabel(reading: reading, preferences: preferences).text, "+42.1 W")
        XCTAssertTrue(StatusPanelModel(reading: reading, componentReadingsEnabled: preferences.componentReadings).components.isEmpty)
        await router.settingsHelperSetup.refreshStatus(preferences: preferences)
        XCTAssertTrue(router.settingsHelperSetup.wasRemoved)
        XCTAssertFalse(router.settingsHelperSetup.helperOn)
    }

    func testPendingRemovalCannotShowRemovedState() async {
        let router = AppRouter()
        let preferences = J92FixtureLaunch.makePreferences()
        await J91FixtureLaunch.prepare(router: router)
        var continuation: CheckedContinuation<RemovalOutcome, Never>?
        router.removeFromSettings = { _ in
            await withCheckedContinuation { continuation = $0 }
        }
        let task = Task { await router.removeVerifiedHelper(preferences: preferences) }
        while continuation == nil { await Task.yield() }
        XCTAssertFalse(router.settingsHelperSetup.wasRemoved)
        XCTAssertTrue(preferences.componentReadings)
        XCTAssertEqual(preferences.displayMode, .components)
        continuation?.resume(returning: .failed(.denied))
        _ = await task.value
        XCTAssertFalse(router.settingsHelperSetup.wasRemoved)
        XCTAssertTrue(preferences.componentReadings)
    }

    func testTurnOnUsesApprovalWithoutEnablingReadingsOnRegistration() async {
        let router = AppRouter()
        let preferences = J92FixtureLaunch.makePreferences()
        await J92FixtureLaunch.prepare(router: router, preferences: preferences)
        let service = ApprovalService()
        router.settingsHelperSetup.service = service
        await router.settingsHelperSetup.turnOn(preferences: preferences)
        XCTAssertEqual(service.registrations, 1)
        XCTAssertEqual(router.settingsHelperSetup.state, .requiresApproval)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertFalse(router.settingsHelperSetup.helperOn)
        service.status = .connected
        await router.settingsHelperSetup.refreshStatus(preferences: preferences)
        XCTAssertTrue(preferences.componentReadings)
        XCTAssertTrue(router.settingsHelperSetup.helperOn)
        XCTAssertFalse(router.settingsHelperSetup.wasRemoved)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertEqual(preferences.displayMode, .delta)
    }

    func testProductionAndReopenedSettingsRetainAllSectionsAfterRemoval() async throws {
        // Grouped Form rows are not reliably exposed by in-process NSHostingView AX.
        // These are source/state contracts, not runtime accessibility acceptance.
        let source = try settingsSource()
        XCTAssertTrue(source.contains("let showsRemovedExcerpt = (removalExcerpt || removedExcerpt) && router.settingsHelperSetup.wasRemoved"))
        let fullForm = try sourceSlice(source, from: "            } else {\n                Section {",
                                       to: "        .modifier(HelperNotApprovedPresentation")
        for section in ["Readings", "Notifications"] {
            XCTAssertTrue(fullForm.contains("Section(\"\(section)\")"), section)
        }
        XCTAssertTrue(fullForm.contains("if !helperExcerpt && !menuBarExcerpt {"))
        XCTAssertFalse(fullForm.contains("wasRemoved"))
        XCTAssertTrue(fullForm.contains("generalSection"))
        XCTAssertTrue(fullForm.contains("SettingsHelperRows(setup: router.settingsHelperSetup"))
        for identifier in ["settings.update", "settings.smoothReadings"] {
            XCTAssertTrue(fullForm.contains(identifier), identifier)
        }
        let general = try sourceSlice(source, from: "private var generalSection", to: "struct SettingsHelperRows")
        for token in ["Section(\"General\")", "settings.openAtLogin", "settings.automaticUpdates"] {
            XCTAssertTrue(general.contains(token), token)
        }
        let helper = try sourceSlice(source, from: "} else if setup.helperOn {", to: "            } label: {")
        XCTAssertTrue(helper.contains("settings.helper.remove"))
        let removedHelper = try sourceSlice(helper, from: "if setup.wasRemoved {", to: "} else {")
        XCTAssertTrue(removedHelper.contains("settings.helper.turnOn"))
        XCTAssertFalse(removedHelper.contains("settings.helper.remove"))
        let router = AppRouter()
        let preferences = J92FixtureLaunch.makePreferences()
        await J92FixtureLaunch.prepare(router: router, preferences: preferences)
        for _ in 0..<2 {
            let host = NSHostingView(rootView: SettingsRootView()
                .environmentObject(preferences).environmentObject(router)
                .environmentObject(J92FixtureLaunch.makeStore()))
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.width, WattSpacing.settingsWidth)
            XCTAssertEqual(host.fittingSize.height, WattSpacing.settingsContentHeight)
            XCTAssertFalse(SettingsRootView().removalExcerpt)
            XCTAssertFalse(SettingsRootView().removedExcerpt)
            XCTAssertFalse(router.settingsHelperSetup.helperOn)
            XCTAssertEqual(router.settingsHelperSetup.statusTitle, "Off")
            XCTAssertEqual(router.settingsHelperSetup.actionTitle, "Turn On…")
            XCTAssertTrue(router.settingsHelperSetup.wasRemoved)
            router.settingsHelperSetup.close()
            await router.settingsHelperSetup.refreshStatus(preferences: preferences)
        }
    }

    func testRemovedFixtureStillUsesReducedNativeForm() async throws {
        let source = try settingsSource()
        let excerpt = try sourceSlice(source, from: "} else if showsRemovedExcerpt {", to: "} else if removalExcerpt {")
        XCTAssertTrue(excerpt.contains("Section(\"Menu Bar\")"))
        XCTAssertTrue(excerpt.contains("settings.show"))
        XCTAssertTrue(excerpt.contains("SettingsHelperRows(setup: router.settingsHelperSetup"))
        for token in ["Section(\"Readings\")", "Section(\"Notifications\")", "generalSection"] {
            XCTAssertFalse(excerpt.contains(token), token)
        }
        let router = AppRouter()
        let preferences = J92FixtureLaunch.makePreferences()
        await J92FixtureLaunch.prepare(router: router, preferences: preferences)
        for view in [SettingsRootView(removedExcerpt: true), SettingsRootView(removalExcerpt: true)] {
            let host = NSHostingView(rootView: view
                .environmentObject(preferences).environmentObject(router)
                .environmentObject(J92FixtureLaunch.makeStore()))
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.width, WattSpacing.settingsExcerptWidth)
            XCTAssertGreaterThan(host.fittingSize.height, 0)
            XCTAssertTrue(router.settingsHelperSetup.wasRemoved)
            XCTAssertFalse(router.settingsHelperSetup.helperOn)
            XCTAssertEqual(router.settingsHelperSetup.actionTitle, "Turn On…")
        }
    }

    func testJ92RouteExplicitlySelectsRemovedExcerptOnlyInDebug() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/WattApp.swift"), encoding: .utf8)
        let selector = try sourceSlice(source, from: "private var settingsRemovedExcerpt: Bool {", to: "private var settingsRemovalExcerpt")
        XCTAssertTrue(selector.contains("#if DEBUG\n        J92FixtureLaunch.requested\n        #else\n        false\n        #endif"))
        let settings = try sourceSlice(source, from: "        Settings {", to: ".windowResizability(.contentSize)")
        XCTAssertTrue(settings.contains("removedExcerpt: settingsRemovedExcerpt"))
        XCTAssertTrue(settings.contains("removalExcerpt: settingsRemovalExcerpt"))
    }

    private func settingsSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"), encoding: .utf8)
    }

    private func sourceSlice(_ source: String, from start: String, to end: String) throws -> String {
        let startRange = try XCTUnwrap(source.range(of: start), "Missing contract boundary: \(start)")
        let endRange = try XCTUnwrap(source.range(of: end, range: startRange.upperBound..<source.endIndex),
                                    "Missing contract boundary: \(end)")
        return String(source[startRange.upperBound..<endRange.lowerBound])
    }

    func testNativeRemovedFormHostingAndStyling() async throws {
        let router = AppRouter()
        let preferences = J92FixtureLaunch.makePreferences()
        await J92FixtureLaunch.prepare(router: router, preferences: preferences)
        let host = NSHostingView(rootView: SettingsRootView(removedExcerpt: true)
            .environmentObject(preferences).environmentObject(router)
            .environmentObject(J92FixtureLaunch.makeStore()))
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(host.fittingSize.width, 0)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"), encoding: .utf8)
        for token in ["if showsRemovedExcerpt", "Section(\"Menu Bar\")",
                      "LabeledContent", ".formStyle(.grouped)", ".buttonStyle(.bordered)",
                      "await setup.turnOn(preferences: preferences)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "LinearGradient", "NSWindow(contentRect"] {
            XCTAssertFalse(source.contains(token), token)
        }
    }
}

@MainActor
private final class ApprovalService: HelperService {
    var status: HelperReconciliation = .absent
    var registrations = 0
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation { status }
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> {
        registrations += 1
        status = .pending
        return .success(.awaitingApproval)
    }
    func remove(receipt: OperationReceipt) async -> RemovalOutcome { .cancelled }
}
