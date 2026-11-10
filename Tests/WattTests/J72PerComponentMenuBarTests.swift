import AppKit
import Combine
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J72PerComponentMenuBarTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testSharedLabelUsesExactCompactCopyAndSelectionOrderWithoutSymbol() {
        let preferences = J72FixtureLaunch.makePreferences()
        let sample = PowerReading.samplePerComponent
        XCTAssertEqual(sample.mode, .perComponent)
        XCTAssertEqual(sample.source, .fixture)
        XCTAssertEqual(sample.capabilities.components, .available)
        XCTAssertEqual(sample.components.map(\.id), ["CPU", "GPU"])
        XCTAssertEqual(sample.components.map(\.watts), [9.8, 4.1])
        let label = MenuBarStatusLabel(reading: sample, preferences: preferences)
        XCTAssertEqual(label.text, "CPU 9.8 · GPU 4.1 W")
        XCTAssertEqual(label.accessibilityReading, "CPU 9.8 · GPU 4.1 watts")
        XCTAssertFalse(label.showsSymbol)
        preferences.selectedComponents = ["GPU", "CPU"]
        XCTAssertEqual(label.text, "GPU 4.1 · CPU 9.8 W")
        preferences.selectedComponents = ["GPU"]
        XCTAssertEqual(label.text, "GPU 4.1 W")
        preferences.precision = .whole
        XCTAssertEqual(label.text, "GPU 4 W")
        preferences.selectedComponents = []
        XCTAssertEqual(label.text, "—")
        XCTAssertEqual(label.accessibilityReading, "No reading yet")
        XCTAssertFalse(label.showsSymbol)
    }

    func testSelectionRejectsMoreThanTwoDuplicatesAndBlankIDsBeforePublishing() {
        let preferences = J72FixtureLaunch.makePreferences()
        preferences.selectedComponents = ["GPU", "CPU"]
        var published: [[String]] = []
        let observation = preferences.selectedComponentsPublisher.dropFirst().sink { published.append($0) }
        for invalid in [["CPU", "GPU", "Other"], ["CPU", "CPU"], [""], ["   "]] {
            XCTAssertFalse(PreferencesStore.validSelection(invalid))
            preferences.selectedComponents = invalid
            XCTAssertEqual(preferences.selectedComponents, ["GPU", "CPU"])
            XCTAssertEqual(preferences.persistenceFailure, .invalidData)
        }
        XCTAssertTrue(published.isEmpty)
        preferences.selectedComponents = ["CPU"]
        XCTAssertEqual(published, [["CPU"]])
        XCTAssertNil(preferences.persistenceFailure)
        withExtendedLifetime(observation) {}
    }

    func testUnavailableStaleAndInvalidSamplesFailClosedWithoutSymbol() {
        let preferences = J72FixtureLaunch.makePreferences()
        var rejected: [PowerReading] = [.unavailable, reading(freshness: .stale),
            reading(freshness: .unavailable), reading(source: .unavailable),
            reading(timestamp: Date(timeIntervalSince1970: .infinity))]
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            rejected.append(reading(capability: capability))
        }
        for watts in [Double.nan, .infinity, -.infinity, -1] {
            rejected.append(reading(components: [PowerComponent(name: "CPU", watts: watts),
                                                PowerComponent(name: "GPU", watts: 4.1)]))
        }
        rejected.append(reading(components: [PowerComponent(name: "CPU", watts: 9.8),
                                             PowerComponent(name: "CPU", watts: 4.1)]))
        rejected.append(reading(components: [PowerComponent(id: "", name: "CPU", watts: 9.8)]))
        for sample in rejected {
            let label = MenuBarStatusLabel(reading: sample, preferences: preferences)
            XCTAssertEqual(label.text, "—", "Rejected sample: \(sample)")
            XCTAssertEqual(label.accessibilityReading, "No reading yet")
            XCTAssertFalse(label.showsSymbol)
        }
        preferences.componentReadings = false
        XCTAssertEqual(MenuBarStatusLabel(reading: .samplePerComponent, preferences: preferences).text, "—")
    }

    func testPartiallyMissingComponentsRetainExistingUnavailableFormatting() {
        let preferences = J72FixtureLaunch.makePreferences()
        let partial = reading(components: [PowerComponent(name: "CPU", watts: 9.8)])
        XCTAssertEqual(MenuBarStatusLabel(reading: partial, preferences: preferences).text, "CPU 9.8 W · GPU —")
    }

    func testFreshPreferencesAndFrozenStoresAreIsolatedPerLaunch() async {
        let first = J72FixtureLaunch.makePreferences()
        let second = J72FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        XCTAssertEqual(first.displayMode, .components)
        XCTAssertEqual(first.selectedComponents, ["CPU", "GPU"])
        XCTAssertTrue(first.componentReadings)
        XCTAssertFalse(first.showSymbol)
        XCTAssertEqual(first.precision, .decimal)
        XCTAssertTrue(first.onboarding.completed)
        XCTAssertEqual(first.onboarding.checkpoint, .livePanel)
        XCTAssertNil(first.persistenceFailure)
        first.selectedComponents = ["GPU"]
        first.displayMode = .delta
        first.showSymbol = true
        first.componentReadings = false
        first.onboarding.completed = false
        XCTAssertEqual(second.selectedComponents, ["CPU", "GPU"])
        XCTAssertEqual(second.displayMode, .components)
        XCTAssertFalse(second.showSymbol)
        XCTAssertTrue(second.componentReadings)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        let store = J72FixtureLaunch.makeStore()
        let other = J72FixtureLaunch.makeStore()
        XCTAssertFalse(store === other)
        XCTAssertNotEqual(store.generation, other.generation)
        XCTAssertEqual(store.statusReading, .samplePerComponent)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh, "Wall-clock time cannot age the frozen fixture")
        XCTAssertEqual(store.statusReading, .samplePerComponent)
        let oldGeneration = store.generation
        store.disconnect()
        XCTAssertFalse(store.accept(.samplePerComponent, generation: oldGeneration))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(other.statusReading, .samplePerComponent)
    }

    func testComponentAgeBoundaryAndRecoveryUseStoreQualification() {
        let clock = FakeWattClock(now: PowerReading.samplePerComponent.timestamp)
        let store = PowerReadingStore(currentReading: .samplePerComponent, clock: clock)
        XCTAssertEqual(PowerReadingStore.componentsStatusMaximumAge, 5)
        clock.advance(by: 5)
        XCTAssertEqual(store.statusReading, .samplePerComponent)
        clock.advance(by: 0.01)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(store.currentReading, .samplePerComponent)
        let next = reading(timestamp: clock.now)
        XCTAssertTrue(store.accept(next, generation: store.generation))
        XCTAssertEqual(store.statusReading, next)
    }

    func testInvalidRefreshSuppressesOldStatusAndRejectsOldGenerations() {
        let clock = FakeWattClock(now: PowerReading.samplePerComponent.timestamp)
        let store = PowerReadingStore(currentReading: .samplePerComponent, clock: clock)
        let invalid = reading(components: [PowerComponent(name: "CPU", watts: .nan)])
        XCTAssertFalse(store.accept(invalid, generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .samplePerComponent)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertTrue(store.accept(.samplePerComponent, generation: store.generation))
        XCTAssertEqual(store.statusReading, .samplePerComponent)
        XCTAssertFalse(store.accept(reading(timestamp: clock.now.addingTimeInterval(1)), generation: store.generation))
        XCTAssertEqual(store.statusReading, .unavailable)
        let oldGeneration = store.generation
        store.restart()
        XCTAssertFalse(store.accept(.samplePerComponent, generation: oldGeneration))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertTrue(store.accept(.samplePerComponent, generation: store.generation))
        XCTAssertEqual(store.statusReading, .samplePerComponent)
    }

    func testSystemClockPublishesComponentExpiryWithoutAnotherSample() {
        let sample = reading(timestamp: Date().addingTimeInterval(-4.5))
        let store = PowerReadingStore(currentReading: sample)
        XCTAssertEqual(store.statusReading, sample)
        let expired = expectation(description: "Native status observes component sample expiry")
        let observation = store.objectWillChange.sink {
            XCTAssertEqual(store.statusReading, .unavailable)
            expired.fulfill()
        }
        wait(for: [expired], timeout: 2)
        XCTAssertEqual(store.currentReading, sample)
        withExtendedLifetime(observation) {}
    }

    func testOnlyExactBaseSelectorAndRegistryTargetAreAccepted() throws {
        let fixture = try ScenarioRegistry.resolve("J7.2")
        XCTAssertEqual(fixture.story.node, "J7.2")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let arguments = ["Watt", "--watt-fixture", "J7.2/base"]
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(arguments))
        XCTAssertEqual(try launch.smokeLaunchArguments(), Array(arguments.dropFirst()))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J72FixtureLaunch.matches(arguments: arguments))
        XCTAssertFalse(J72FixtureLaunch.requested)
        #else
        XCTAssertTrue(J72FixtureLaunch.matches(arguments: arguments))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: arguments))
        #endif
        for selector in ["J7.2", "J7.2/light", "J7.2/dark", "J7.2/unknown", "J7.2/base/extra", "J7.2/", "j7.2/base", "/base"] {
            let invalid = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J72FixtureLaunch.matches(arguments: invalid))
        }
        for invalid in [[], ["Watt", "--watt-fixture"], ["Watt", "--watt-fixture", "J7.1/base"],
                        arguments + ["--watt-fixture", "J7.2/base"]] {
            XCTAssertFalse(J72FixtureLaunch.matches(arguments: invalid))
        }
    }

    func testLightNativeHostAndSharedLabelDoNotPaintStatusChrome() throws {
        XCTAssertEqual(J72FixtureLaunch.appearanceName, .aqua)
        let label = MenuBarStatusLabel(reading: .samplePerComponent, preferences: J72FixtureLaunch.makePreferences())
        let host = NSHostingView(rootView: label)
        host.appearance = NSAppearance(named: J72FixtureLaunch.appearanceName)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .aqua)
        XCTAssertGreaterThan(host.fittingSize.width, 0)
        XCTAssertGreaterThan(host.fittingSize.height, 0)
        XCTAssertEqual(WattTypography.bodyEmphasized, Font.body.weight(.semibold))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Components/MenuBarStatusLabel.swift"), encoding: .utf8)
        for forbidden in ["LinearGradient", "RoundedRectangle", ".shadow(", ".background(",
                          ".position(", ".offset(", "Font.custom", ".font(.system(size:", "CPU 9.8 · GPU 4.1 W"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        XCTAssertTrue(source.contains("if showsSymbol"))
        XCTAssertTrue(source.contains("Image(systemName: symbolName)"))
        XCTAssertTrue(source.contains(".font(WattTypography.bodyEmphasized)"))
    }

    private func reading(components: [PowerComponent] = PowerReading.samplePerComponent.components,
                         capability: Capability = .available, freshness: ReadingFreshness = .fresh,
                         source: ReadingSource = .fixture,
                         timestamp: Date = PowerReading.samplePerComponent.timestamp) -> PowerReading {
        PowerReading(mode: .perComponent, watts: nil, components: components, timestamp: timestamp,
                     capabilities: .init(components: capability), freshness: freshness, source: source)
    }
    #endif
}
