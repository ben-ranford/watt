import AppKit
import Combine
import XCTest
import SwiftUI
@testable import Watt

@MainActor
final class AppRouterTests: XCTestCase {
    #if DEBUG
    func testCaptureRequiresExactOptIn() {
        XCTAssertFalse(NativeCaptureDelegate.captureRequested(arguments: ["Watt"]))
        XCTAssertFalse(NativeCaptureDelegate.captureRequested(arguments: ["Watt", "--watt-capture-status-panel=false"]))
        XCTAssertTrue(NativeCaptureDelegate.captureRequested(arguments: ["Watt", NativeCaptureDelegate.launchArgument]))
    }

    func testCaptureWindowHostsNativePanelWithoutShowingIt() {
        let window = NativeCaptureDelegate.makeWindow()
        defer { window.close() }
        XCTAssertEqual(window.title, NativeCaptureDelegate.windowTitle)
        XCTAssertEqual(window.contentView?.fittingSize.width ?? 0, 320, accuracy: 1)
        XCTAssertGreaterThan(window.contentView?.fittingSize.height ?? 0, 300)
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(window.appearance?.name, .aqua)
    }
    #endif

    func testLaunchPresentsOnlyIncompleteSetupAndIsIdempotent() {
        for completed in [false, true] {
            let router = AppRouter()
            var requests: [AppDestination] = []
            router.present = { requests.append($0) }

            router.launch(setupComplete: completed)
            XCTAssertEqual(requests, completed ? [] : [.onboarding])
            router.launch(setupComplete: completed)
            router.launch(setupComplete: !completed)
            XCTAssertEqual(requests, completed ? [] : [.onboarding])
        }
    }

    func testReopenUsesCurrentCompletionStateWithoutRepeatingLaunch() {
        for initiallyComplete in [false, true] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding.completed = initiallyComplete
            let router = AppRouter()
            var requests: [AppDestination] = []
            router.present = { requests.append($0) }
            router.launch(setupComplete: preferences.onboarding.completed)
            requests.removeAll()

            for completed in [false, true, false] {
                preferences.onboarding.completed = completed
                router.reopen(setupComplete: preferences.onboarding.completed)
                XCTAssertEqual(requests.last, completed ? .settings : .onboarding)
            }
            XCTAssertEqual(requests, [.onboarding, .settings, .onboarding])
        }
    }

    func testExplicitPresentationRequestsDoNotSuppressRepeatedIntents() {
        let router = AppRouter()
        var requests: [AppDestination] = []
        router.present = { requests.append($0) }
        let actions: [(AppDestination, () -> Void)] = [
            (.statusPanel, router.showStatusPanel), (.settings, router.showSettings),
            (.update, router.showUpdate), (.onboarding, router.beginOnboarding)
        ]
        for (destination, action) in actions {
            requests.removeAll()
            action()
            action()
            XCTAssertEqual(requests, [destination, destination])
        }
    }

    func testOnboardingPresentationPreservesPersistedProgress() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding.checkpoint = .approval
        preferences.onboarding.helperOptIn = true
        let progress = preferences.onboarding
        let router = AppRouter()
        var requests: [AppDestination] = []
        router.present = { requests.append($0) }

        router.beginOnboarding()
        router.reopen(setupComplete: preferences.onboarding.completed)

        XCTAssertEqual(requests, [.onboarding, .onboarding])
        XCTAssertEqual(preferences.onboarding, progress)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding, progress)
    }

    func testSettingsAndUpdateIntentsRemainIndependentOfStatusPanelVisibility() {
        for panelPresented in [false, true] {
            let router = AppRouter()
            router.statusPanelPresented = panelPresented
            var requests: [AppDestination] = []
            router.present = { requests.append($0) }

            router.showSettings()
            router.showUpdate()
            router.showSettings()
            router.showUpdate()

            XCTAssertEqual(requests, [.settings, .update, .settings, .update])
            XCTAssertEqual(router.statusPanelPresented, panelPresented)
        }
    }

    func testContextMenuStructureReflectsSetupCompletion() {
        for completed in [false, true] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding.completed = completed
            let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: preferences, componentsAvailable: { true })
            let expected = (completed ? [] : ["Finish Setup…"])
                + ["Show in Menu Bar", "Open Watt?", "Settings…"]
                + ["About Watt?", "Check for Updates…", "Quit Watt?"]
            XCTAssertEqual(menu.items.filter { !$0.isSeparatorItem }.map(\.title), expected)
            XCTAssertEqual(menu.items.filter(\.isSeparatorItem).count, completed ? 3 : 4)
            // Verify Quit is wired, but never terminate the test host.
            XCTAssertNotNil(menu.items.last?.action)
            XCTAssertNotNil(menu.items.last?.target)
        }
    }

    func testContextMenuPresentationActionsRequestTheirOwnDestinations() throws {
        for completed in [false, true] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding.completed = completed
            let router = AppRouter()
            var requests: [AppDestination] = []
            router.present = { requests.append($0) }
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
            for (title, destination) in [("Open Watt?", AppDestination.statusPanel),
                                         ("Settings…", .settings),
                                         ("Settings…", .settings)] {
                requests.removeAll()
                try invoke(title, in: menu)
                XCTAssertEqual(requests, [destination], title)
            }
            XCTAssertEqual(preferences.onboarding.completed, completed)
        }
    }

    func testFinishSetupPersistsPickerBeforeRequestingOnboardingWithoutCompleting() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding.checkpoint = .approval
        preferences.onboarding.helperOptIn = true
        let router = AppRouter()
        var requests: [AppDestination] = []
        router.present = {
            requests.append($0)
            XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .picker)
        }
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })

        try invoke("Finish Setup…", in: menu)

        XCTAssertEqual(requests, [.onboarding])
        XCTAssertEqual(preferences.onboarding.checkpoint, .picker)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertTrue(preferences.onboarding.helperOptIn)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding, preferences.onboarding)
    }

    func testEveryDisplayModeMenuActionPersistsAndRebuiltMenuChecksOnlySelection() throws {
        let modes: [(String, WattDisplayMode)] = [
            ("Delta", .delta), ("Charger", .charger), ("Draw", .draw),
            ("Components", .components), ("Icon", .iconOnly)
        ]
        for initial in WattDisplayMode.allCases {
            for (title, selected) in modes {
                let storage = InMemoryStorage()
                let preferences = PreferencesStore(storage: storage)
                preferences.displayMode = initial
                let router = AppRouter()
                var requests: [AppDestination] = []
                router.present = { requests.append($0) }
                let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
                let readings = try XCTUnwrap(menu.item(withTitle: "Show in Menu Bar")?.submenu)
                XCTAssertEqual(readings.items.filter { !$0.isSeparatorItem }.map(\.title), modes.map { $0.0 })
                XCTAssertEqual(readings.items.filter { !$0.isSeparatorItem }.map(\.state), modes.map { $0.1 == initial ? .on : .off })

                try invoke(title, in: readings)

                XCTAssertEqual(preferences.displayMode, selected)
                let restored = PreferencesStore(storage: storage)
                XCTAssertEqual(restored.displayMode, selected)
                XCTAssertTrue(requests.isEmpty)
                XCTAssertNil(preferences.persistenceFailure)
                let rebuilt = StatusItemContextMenu.makeMenu(router: router, preferences: restored, componentsAvailable: { true })
                let restoredReadings = try XCTUnwrap(rebuilt.item(withTitle: "Show in Menu Bar")?.submenu)
                XCTAssertEqual(restoredReadings.items.filter { !$0.isSeparatorItem }.map(\.state), modes.map { $0.1 == selected ? .on : .off })
            }
        }
    }

    // Dispatch the actual target/action without displaying menus or using UI automation.
    private func invoke(_ title: String, in menu: NSMenu) throws {
        let item = try XCTUnwrap(menu.item(withTitle: title))
        let action = try XCTUnwrap(item.action)
        let target = try XCTUnwrap(item.target as? NSObject)
        XCTAssertTrue(target.responds(to: action))
        target.perform(action, with: item)
    }

    func testSampleReadingMatchesChargingFixture() {
        let reading = PowerReading.sampleCharging

        XCTAssertEqual(reading.mode, .charging)
        XCTAssertEqual(reading.watts, 42.1)
        XCTAssertEqual(reading.batteryPercentage, 64)
        XCTAssertEqual(reading.components.map(\.name), ["CPU", "GPU", "Display", "Other"])
    }
}

// Kept in the existing native-target source until test source discovery is enabled.
@MainActor
final class DesignSystemTokenTests: XCTestCase {
    func testSpacingScalePreservesCompactDesktopRhythm() {
        XCTAssertEqual([WattSpacing.xxs, WattSpacing.xs, WattSpacing.sm,
                        WattSpacing.md, WattSpacing.lg, WattSpacing.xl],
                       [3, 4, 8, 12, 16, 20])
    }

    func testReferenceSettingsSpacingIsTenPointsTighter() {
        XCTAssertEqual(WattSpacing.lg - WattSpacing.referenceSettingsSectionSpacing, 10)
    }

    func testControlMetricsPreserveMinimumLayoutContracts() {
        XCTAssertEqual(WattSpacing.formRowHeight, 42)
        XCTAssertEqual(WattSpacing.buttonHeight, 24)
        XCTAssertEqual(WattSpacing.menuBarHeight, 24)
    }

    func testTypographyUsesSystemTextStylesAndSemanticEmphasis() {
        XCTAssertEqual(WattTypography.body, Font.body)
        XCTAssertEqual(WattTypography.bodyEmphasized, Font.body.weight(.semibold))
        XCTAssertEqual(WattTypography.headline, Font.body.weight(.bold))
        XCTAssertEqual(WattTypography.title, Font.title2.weight(.bold))
        XCTAssertEqual(WattTypography.largeTitle, Font.largeTitle.weight(.bold))
        XCTAssertEqual(WattTypography.subheadline, Font.subheadline)
        XCTAssertEqual(WattTypography.footnote, Font.footnote)
    }

    func testSemanticColorsResolveAgainstBothHostAppearances() throws {
        let tokens: [(Color, NSColor)] = [
            (WattColors.primaryLabel, .labelColor),
            (WattColors.secondaryLabel, .secondaryLabelColor),
            (WattColors.disabledLabel, .disabledControlTextColor),
            (WattColors.windowBackground, .windowBackgroundColor),
            (WattColors.rowFill, .quaternaryLabelColor),
            (WattColors.separator, .separatorColor),
            (WattColors.focusRing, .keyboardFocusIndicatorColor),
            (WattColors.success, .systemGreen),
            (WattColors.destructive, .systemRed)
        ]
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            appearance.performAsCurrentDrawingAppearance {
                for (token, semanticColor) in tokens {
                    XCTAssertEqual(NSColor(token).usingColorSpace(.sRGB),
                                   semanticColor.usingColorSpace(.sRGB), "\(name): \(semanticColor)")
                }
            }
        }
    }

    func testAccentRespectsSystemAccentChoice() {
        XCTAssertEqual(WattColors.accent, Color.accentColor)
    }

}

@MainActor
final class SharedControlTests: XCTestCase {
    func testActionButtonsMatchNativeMetricsAcrossStylesAndAppearances() {
        for scheme in [ColorScheme.light, .dark] {
            for style in [WattActionButton.Style.bordered, .prominent, .destructive] {
                let host = makeHost(WattActionButton(title: "Continue", style: style) {}, scheme: scheme)
                let native: AnyView
                switch style {
                case .bordered: native = AnyView(Button("Continue") {}.buttonStyle(.bordered))
                case .prominent: native = AnyView(Button("Continue") {}.buttonStyle(.borderedProminent))
                case .destructive: native = AnyView(Button("Continue", role: .destructive) {}.buttonStyle(.bordered))
                }
                XCTAssertEqual(host.fittingSize, makeHost(native.controlSize(.regular), scheme: scheme).fittingSize)
            }
        }
    }

    func testDisabledButtonsRetainLayoutAcrossStylesAndAppearances() {
        for scheme in [ColorScheme.light, .dark] {
            for style in [WattActionButton.Style.bordered, .prominent, .destructive] {
                let button = WattActionButton(title: "Continue", style: style) {}
                let enabled = makeHost(button, scheme: scheme)
                let disabled = makeHost(button.disabled(true), scheme: scheme)
                XCTAssertEqual(enabled.fittingSize, disabled.fittingSize, "\(scheme), \(style)")
            }
        }
    }

    func testFormRowMatchesNativeLabeledContent() {
        let host = makeHost(WattFormRow { Text("Reading") } trailing: { Text("Power") })
        let native = makeHost(LabeledContent { Text("Power") } label: { Text("Reading") })
        XCTAssertEqual(host.fittingSize, native.fittingSize)
    }

    func testReadingPickerRejectsUnavailableSelectionAndPreservesCallbacks() {
        var selection = WattDisplayMode.delta
        let picker = ReadingPicker(selection: Binding(get: { selection }, set: { selection = $0 }),
                                   unavailableModes: [.components])
        picker.availableSelection.wrappedValue = .charger
        XCTAssertEqual(selection, .charger)
        picker.availableSelection.wrappedValue = .components
        XCTAssertEqual(selection, .charger)
    }

    // Layout only: no pixels, visible windows, permission prompts, or UI automation.
    private func makeHost<V: View>(_ view: V, scheme: ColorScheme = .light) -> NSHostingView<some View> {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, scheme))
        host.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 100)
        host.layoutSubtreeIfNeeded()
        return host
    }

}

@MainActor
final class ReadingPickerTests: XCTestCase {
    func testDefaultInitializerPreservesAllModesAndDescriptions() {
        let picker = ReadingPicker(selection: .constant(.delta))
        XCTAssertEqual(picker.options.map(\.mode), WattDisplayMode.allCases)
        XCTAssertTrue(picker.unavailableModes.isEmpty)
        XCTAssertNil(picker.options.last?.description)
        XCTAssertEqual(picker.options.first?.description, "How fast the battery fills or drains.")
    }

    func testCallerControlsVisibleOptionsDescriptionsAndAvailability() {
        let options = [ReadingPicker.Option(mode: .charger, description: "Caller text")]
        let picker = ReadingPicker(selection: .constant(.charger), unavailableModes: [.charger], options: options)
        XCTAssertEqual(picker.options, options)
        XCTAssertEqual(picker.unavailableModes, [.charger])
    }

    #if DEBUG
    func testReferenceReadingHasExactlyFourEnabledOptions() {
        let picker = ReadingPicker(selection: .constant(.delta), options: WattReferenceSpecimen.readingOptions)
        XCTAssertEqual(picker.options.map(\.mode), [.delta, .charger, .draw, .components])
        XCTAssertTrue(picker.unavailableModes.isEmpty)
        for (option, expected) in zip(picker.options, ["+42.1 W", "65 W", "22.9 W", "CPU, GPU and the rest. Needs the helper — next step."]) {
            XCTAssertTrue(option.description?.contains(expected) == true)
        }
    }

    func testReferenceCaptureSizesAndAppearances() {
        for scheme in [ColorScheme.light, .dark] {
            for kind in WattReferenceSpecimen.Kind.allCases {
                let window = NativeCaptureDelegate.makeGalleryWindow(colorScheme: scheme, specimen: kind)
                XCTAssertFalse(window.isVisible)
                XCTAssertEqual(window.contentView?.fittingSize.width ?? 0, kind == .reading ? 480 : 580, accuracy: 1)
                XCTAssertEqual(window.appearance?.name, scheme == .dark ? .darkAqua : .aqua)
                window.close()
            }
        }
    }
    #endif
}

// MARK: - F03 contracts
// Kept in this source because the native Xcode target explicitly lists it.
// These tests use value types, fake clocks/services, and isolated memory storage only.
@MainActor
final class F03PowerContractTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func reading(watts: Double? = -12, timestamp: Date? = nil,
                         state: BatteryState = .discharging,
                         capabilities: PowerCapabilities = .init(battery: .available, charger: .disconnected),
                         freshness: ReadingFreshness = .fresh,
                         source: ReadingSource = .fixture) -> PowerReading {
        PowerReading(mode: .onBattery, watts: watts, timestamp: timestamp ?? epoch,
                     batteryState: state, capabilities: capabilities, freshness: freshness,
                     source: source, chargerWatts: 65, systemWatts: 20)
    }

    func testSignedFormattingAndUnsignedInput() {
        XCTAssertEqual(PowerFormatter.watts(42.1), "+42.1 W")
        XCTAssertEqual(PowerFormatter.watts(-12.34), "-12.3 W")
        XCTAssertEqual(PowerFormatter.watts(65, signed: false), "65.0 W")
    }

    func testUnavailableAndNonFiniteValuesAreNotZero() {
        for value: Double? in [nil, .nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
            XCTAssertEqual(PowerFormatter.watts(value), "—")
        }
        for value in [0.0, -0.0, 0.01, -0.01] {
            XCTAssertEqual(PowerFormatter.watts(value), "0.0 W")
        }
        XCTAssertNil(PowerReading.unavailable.value(for: .delta))
        XCTAssertEqual(reading(watts: 0).value(for: .delta), 0)
    }

    func testChargingHoldIsDistinctFromFullAtZeroWatts() throws {
        let hold = reading(watts: 0, state: .chargingHold)
        let full = reading(watts: 0, state: .full)
        try hold.validate()
        try full.validate()
        XCTAssertEqual(hold.batteryState, .chargingHold)
        XCTAssertEqual(full.batteryState, .full)
        XCTAssertNotEqual(hold, full)
    }

    func testComponentIdentitySurvivesRenamingAndNewSamples() {
        let first = PowerComponent(id: "cpu.package", name: "CPU", watts: 4)
        let second = PowerComponent(id: "cpu.package", name: "Processor", watts: 9)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.name, "CPU")
        XCTAssertEqual(first.watts, 4)
        XCTAssertEqual(PowerComponent(name: "GPU", watts: 1).id,
                       PowerComponent(name: "GPU", watts: 2).id)
    }

    func testValidationRejectsDuplicateAndEmptyComponentIDs() {
        for components in [[PowerComponent(id: "", name: "CPU", watts: 1)],
                           [PowerComponent(id: "cpu", name: "CPU", watts: 1),
                            PowerComponent(id: "cpu", name: "Other", watts: 2)]] {
            let sample = PowerReading(mode: .perComponent, watts: nil, components: components)
            XCTAssertThrowsError(try sample.validate()) { XCTAssertEqual($0 as? ServiceFailure, .invalidData) }
        }
    }

    func testValidationRejectsInvalidPhysicalReadings() {
        let invalid = [reading(watts: -1, state: .charging), reading(watts: 1, state: .discharging),
                       reading(watts: 0, state: .noBattery), reading(watts: .nan),
                       PowerReading(mode: .charging, watts: 1, batteryPercentage: 101),
                       PowerReading(mode: .chargerInput, watts: nil, chargerWatts: -1)]
        for sample in invalid {
            XCTAssertThrowsError(try sample.validate()) { XCTAssertEqual($0 as? ServiceFailure, .invalidData) }
        }
    }

    func testCapabilitiesGateValuesIndependentlyOfPresence() {
        for capability in [Capability.unsupported, .permissionRequired, .disconnected, .unknown] {
            let sample = reading(capabilities: .init(battery: capability, charger: capability,
                                                     systemDraw: capability, components: capability))
            for mode in WattDisplayMode.allCases { XCTAssertNil(sample.value(for: mode)) }
        }
        let available = reading(capabilities: .init(battery: .available, charger: .available,
                                                    systemDraw: .available, components: .available))
        XCTAssertEqual(available.value(for: .delta), -12)
        XCTAssertEqual(available.value(for: .charger), 65)
        XCTAssertEqual(available.value(for: .draw), 20)
    }

    func testUnpluggedChargerFallsBackToBatteryInsteadOfOldInputOrZero() {
        XCTAssertEqual(reading().value(for: .charger), -12)
        XCTAssertNil(reading(watts: nil).value(for: .charger))
    }

    func testFreshnessIncludesAgeBoundaryAndRejectsFutureOrInvalidAge() {
        let sample = reading()
        XCTAssertEqual(sample.freshness(at: epoch.addingTimeInterval(5), maximumAge: 5), .fresh)
        XCTAssertEqual(sample.freshness(at: epoch.addingTimeInterval(5.01), maximumAge: 5), .stale)
        XCTAssertEqual(sample.freshness(at: epoch.addingTimeInterval(-1), maximumAge: 5), .stale)
        for age in [-1.0, .nan, .infinity] {
            XCTAssertEqual(sample.freshness(at: epoch, maximumAge: age), .stale)
        }
        XCTAssertEqual(reading(freshness: .stale).freshness(at: epoch, maximumAge: 5), .stale)
    }

    func testUnavailableSourceOrFreshnessSuppressesValues() {
        for sample in [reading(source: .unavailable), reading(freshness: .unavailable)] {
            XCTAssertEqual(sample.freshness(at: epoch, maximumAge: 5), .unavailable)
            XCTAssertNil(sample.value(for: .delta))
            XCTAssertNil(sample.value(for: .charger))
        }
    }

    func testStoreRecoversFromStaleWithFreshSample() {
        let clock = FakeWattClock(now: epoch)
        let store = PowerReadingStore(currentReading: reading(), clock: clock)
        clock.advance(by: 6)
        XCTAssertEqual(store.freshness(maximumAge: 5), .stale)
        XCTAssertTrue(store.accept(reading(timestamp: clock.now), generation: store.generation))
        XCTAssertEqual(store.freshness(maximumAge: 5), .fresh)
    }

    func testRestartRejectsLateReplyEvenWithNewerTimestamp() {
        let clock = FakeWattClock(now: epoch)
        let store = PowerReadingStore(currentReading: reading(), clock: clock)
        let old = store.generation
        let current = store.restart()
        XCTAssertNotEqual(old, current)
        clock.advance(by: 1)
        XCTAssertFalse(store.accept(reading(timestamp: clock.now), generation: old))
        XCTAssertEqual(store.currentReading.timestamp, epoch)
        XCTAssertTrue(store.accept(reading(timestamp: clock.now), generation: current))
    }

    func testDisconnectInvalidatesOutstandingReplyAndNewGenerationRecovers() {
        let store = PowerReadingStore(currentReading: reading(), clock: FakeWattClock(now: epoch))
        let old = store.generation
        store.disconnect()
        XCTAssertEqual(store.currentReading, .unavailable)
        XCTAssertEqual(store.failure, .disconnected)
        XCTAssertFalse(store.accept(reading(), generation: old))
        XCTAssertTrue(store.accept(reading(), generation: store.generation))
        XCTAssertNil(store.failure)
    }

    func testStoreRejectsOutOfOrderFutureAndInvalidSamplesWithoutReplacingReading() {
        let original = reading()
        let store = PowerReadingStore(currentReading: original, clock: FakeWattClock(now: epoch))
        for sample in [reading(timestamp: epoch.addingTimeInterval(-1)),
                       reading(timestamp: epoch.addingTimeInterval(1)), reading(watts: .nan)] {
            XCTAssertFalse(store.accept(sample, generation: store.generation))
            XCTAssertEqual(store.currentReading, original)
        }
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertTrue(store.accept(original, generation: store.generation))
        XCTAssertNil(store.failure)
    }
}

@MainActor
final class F03PreferencesContractTests: XCTestCase {
    func testInjectedStoragePersistsPreferencesAndOnboardingAcrossInstances() {
        let storage = InMemoryStorage()
        let first = PreferencesStore(storage: storage)
        first.displayMode = .charger
        first.showSymbol = false
        first.selectedComponents = ["display"]
        first.onboarding = OnboardingState(checkpoint: .preview, completed: false, helperOptIn: true)
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.displayMode, .charger)
        XCTAssertFalse(restored.showSymbol)
        XCTAssertEqual(restored.selectedComponents, ["display"])
        XCTAssertEqual(restored.onboarding, first.onboarding)
        XCTAssertNil(restored.persistenceFailure)
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).displayMode, .delta)
    }

    func testDefaultAndPreviewStorageDoNotSharePreferences() {
        let first = PreferencesStore()
        first.displayMode = .draw
        XCTAssertEqual(PreferencesStore().displayMode, .delta)
        let preview = PreferencesStore.preview
        preview.displayMode = .components
        XCTAssertEqual(PreferencesStore.preview.displayMode, .delta)
    }

    func testSelectionRejectsThirdDuplicateAndBlankIDsWithoutPersistingThem() {
        let storage = InMemoryStorage()
        let store = PreferencesStore(storage: storage)
        store.selectedComponents = ["cpu", "gpu"]
        for invalid in [["cpu", "gpu", "display"], ["cpu", "cpu"], [""], ["   "]] {
            store.selectedComponents = invalid
            XCTAssertEqual(store.selectedComponents, ["cpu", "gpu"])
            XCTAssertEqual(store.persistenceFailure, .invalidData)
            XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["cpu", "gpu"])
        }
        for valid in [[], ["cpu"], ["cpu", "gpu"]] {
            store.selectedComponents = valid
            XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, valid)
            XCTAssertNil(store.persistenceFailure)
        }
    }

    func testStorageWriteFailureIsVisibleAndRetryPersists() {
        let storage = InMemoryStorage()
        let store = PreferencesStore(storage: storage)
        storage.failWrites = true
        store.displayMode = .draw
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .delta)
        storage.failWrites = false
        XCTAssertTrue(store.save())
        XCTAssertNil(store.persistenceFailure)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .draw)
    }

    func testUnreadableAndCorruptStoragePreserveSafeDefaults() {
        let storage = InMemoryStorage()
        storage.failReads = true
        XCTAssertEqual(PreferencesStore(storage: storage).persistenceFailure, .persistence)
        storage.failReads = false
        storage.values["preferences.v1"] = Data("not JSON".utf8)
        let store = PreferencesStore(storage: storage)
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertEqual(store.selectedComponents, ["CPU", "GPU"])
    }
}

@MainActor
final class F03ApprovalContractTests: XCTestCase {
    func testOriginsShareOneOperationAndReceiveCompletionOnlyOnce() throws {
        let store = HelperApprovalStore()
        let onboarding = try store.join(.onboarding, reconciled: .absent)
        let settings = try store.join(.settings, reconciled: .pending)
        XCTAssertTrue(onboarding.registrationRequired)
        XCTAssertFalse(settings.registrationRequired)
        XCTAssertEqual(onboarding.receipt, settings.receipt)
        XCTAssertEqual(onboarding.token.generation, settings.token.generation)
        let delivered = try store.receive(.connected, operationID: onboarding.receipt.id,
                                          generation: onboarding.token.generation)
        XCTAssertEqual(delivered, [onboarding.token, settings.token])
        XCTAssertEqual(store.effectiveState, .connected)
        XCTAssertTrue(try store.receive(.connected, operationID: onboarding.receipt.id,
                                        generation: onboarding.token.generation).isEmpty)
    }

    func testWithdrawingOneOriginDoesNotCancelOtherOrigin() throws {
        let store = HelperApprovalStore()
        let first = try store.join(.onboarding, reconciled: .absent)
        let second = try store.join(.settings, reconciled: .pending)
        try store.withdraw(.onboarding)
        XCTAssertFalse(store.canNavigate(first.token))
        XCTAssertTrue(store.canNavigate(second.token))
        XCTAssertTrue(store.checkpoint.desiredOn)
        XCTAssertEqual(try store.receive(.connected, operationID: second.receipt.id,
                                         generation: second.token.generation), [second.token])
        XCTAssertEqual(store.checkpoint.origins[.onboarding]?.failure, .cancelled)
    }

    func testClosingAndRejoiningReplacesPresentationButRetainsSharedOperation() throws {
        let store = HelperApprovalStore()
        let first = try store.join(.onboarding, reconciled: .absent)
        store.close(.onboarding)
        XCTAssertFalse(store.canNavigate(first.token))
        XCTAssertTrue(store.checkpoint.desiredOn)
        let rejoined = try store.join(.onboarding, reconciled: .pending)
        XCTAssertEqual(rejoined.receipt, first.receipt)
        XCTAssertEqual(rejoined.token.generation, first.token.generation)
        XCTAssertNotEqual(rejoined.token.presentationID, first.token.presentationID)
        XCTAssertFalse(rejoined.registrationRequired)
        XCTAssertEqual(try store.receive(.connected, operationID: first.receipt.id,
                                         generation: first.token.generation), [rejoined.token])
    }

    func testWithdrawAllAndRetryRejectsLateOperationAndGeneration() throws {
        let store = HelperApprovalStore()
        let old = try store.join(.onboarding, reconciled: .absent)
        try store.withdraw(.onboarding)
        XCTAssertNil(store.generation)
        XCTAssertFalse(store.checkpoint.desiredOn)
        let retry = try store.join(.onboarding, reconciled: .absent)
        XCTAssertNotEqual(retry.receipt.id, old.receipt.id)
        XCTAssertNotEqual(retry.token.generation, old.token.generation)
        for (id, generation) in [(old.receipt.id, old.token.generation),
                                  (old.receipt.id, retry.token.generation),
                                  (retry.receipt.id, old.token.generation)] {
            XCTAssertTrue(try store.receive(.connected, operationID: id, generation: generation).isEmpty)
            XCTAssertEqual(store.effectiveState, .absent)
        }
        XCTAssertTrue(store.canNavigate(retry.token))
    }

    func testUnknownReconciliationDoesNotRegisterAndInvalidatesOldPresentation() throws {
        let store = HelperApprovalStore()
        let old = try store.join(.settings, reconciled: .absent)
        XCTAssertThrowsError(try store.join(.settings, reconciled: .unknown)) {
            XCTAssertEqual($0 as? ServiceFailure, .unknownStatus)
        }
        XCTAssertFalse(store.canNavigate(old.token))
    }

    func testApprovalFailureClearsInterestAndPreservesReasonForEachOrigin() throws {
        for reason in [ServiceFailure.denied, .timedOut, .disconnected] {
            let store = HelperApprovalStore()
            let first = try store.join(.onboarding, reconciled: .absent)
            let second = try store.join(.settings, reconciled: .pending)
            XCTAssertEqual(try store.receive(.failed(reason), operationID: first.receipt.id,
                                             generation: first.token.generation), [first.token, second.token])
            XCTAssertEqual(store.effectiveState, .failed(reason))
            XCTAssertNil(store.generation)
            XCTAssertFalse(store.checkpoint.desiredOn)
            for origin in ApprovalOrigin.allCases {
                XCTAssertEqual(store.checkpoint.origins[origin], ApprovalInterest(interested: false, failure: reason))
            }
        }
    }

    func testRestartRestoresIntentButNotTokensOrEffectiveConnection() throws {
        let storage = InMemoryStorage()
        let first = HelperApprovalStore(storage: storage)
        let request = try first.join(.settings, reconciled: .absent)
        let restored = HelperApprovalStore(storage: storage)
        XCTAssertEqual(restored.checkpoint, first.checkpoint)
        XCTAssertEqual(restored.effectiveState, .unknown)
        XCTAssertNil(restored.generation)
        XCTAssertFalse(restored.canNavigate(request.token))
        let joined = try restored.join(.settings, reconciled: .pending)
        XCTAssertFalse(joined.registrationRequired)
        XCTAssertEqual(joined.receipt, request.receipt)
        XCTAssertNotEqual(joined.token.generation, request.token.generation)
    }

    func testFailedPersistenceDoesNotGrantRegistrationOrNavigation() throws {
        let storage = InMemoryStorage()
        let store = HelperApprovalStore(storage: storage)
        storage.failWrites = true
        XCTAssertThrowsError(try store.join(.settings, reconciled: .absent)) {
            XCTAssertEqual($0 as? ServiceFailure, .persistence)
        }
        XCTAssertFalse(store.checkpoint.desiredOn)
        XCTAssertNil(store.generation)
        storage.failWrites = false
        let request = try store.join(.settings, reconciled: .absent)
        storage.failWrites = true
        XCTAssertThrowsError(try store.withdraw(.settings))
        XCTAssertFalse(store.canNavigate(request.token))
        XCTAssertEqual(store.persistenceFailure, .persistence)
    }
}

@MainActor
final class F03UpdateContractTests: XCTestCase {
    private let receipt = OperationReceipt(createdAt: Date(timeIntervalSince1970: 1_700_000_000))

    private func advanceToStaged(_ store: UpdateStore, file: StaticString = #filePath, line: UInt = #line) {
        for state in [UpdateState.checking, .available(version: "2.0"), .downloading(progress: 0),
                      .downloading(progress: 1), .staged(receipt)] {
            XCTAssertTrue(store.accept(state, generation: store.generation), file: file, line: line)
        }
    }

    func testValidUpdateLifecyclePersistsCompletion() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        advanceToStaged(store)
        for state in [UpdateState.installing(receipt), .awaitingRelaunch(receipt), .completed(receipt)] {
            XCTAssertTrue(store.accept(state, generation: store.generation))
            XCTAssertEqual(store.state, state)
        }
        XCTAssertEqual(UpdateStore(storage: storage).state, .completed(receipt))
    }

    func testInvalidTransitionsProgressAndMismatchedReceiptsAreRejected() {
        let store = UpdateStore()
        XCTAssertFalse(store.accept(.completed(receipt), generation: store.generation))
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertTrue(store.accept(.available(version: "2"), generation: store.generation))
        XCTAssertTrue(store.accept(.downloading(progress: 0.5), generation: store.generation))
        for progress in [-1.0, 1.01, .nan, .infinity, 0.4] {
            XCTAssertFalse(store.accept(.downloading(progress: progress), generation: store.generation))
            XCTAssertEqual(store.state, .downloading(progress: 0.5))
        }
        XCTAssertTrue(store.accept(.staged(receipt), generation: store.generation))
        let other = OperationReceipt(createdAt: receipt.createdAt)
        XCTAssertFalse(store.accept(.installing(other), generation: store.generation))
        XCTAssertEqual(store.state, .staged(receipt))
    }

    func testCancelPreInstallInvalidatesLateRepliesAndRetainsReceipt() {
        let store = UpdateStore()
        advanceToStaged(store)
        let old = store.generation
        XCTAssertTrue(store.cancel())
        XCTAssertNotEqual(store.generation, old)
        XCTAssertEqual(store.state, .failed(.cancelled, receipt))
        XCTAssertFalse(store.accept(.installing(receipt), generation: old))
        XCTAssertEqual(store.state, .failed(.cancelled, receipt))
    }

    func testCheckingCancellationCanRestartWithNewGeneration() {
        let store = UpdateStore()
        let old = store.generation
        XCTAssertTrue(store.accept(.checking, generation: old))
        XCTAssertTrue(store.cancel())
        XCTAssertEqual(store.state, .failed(.cancelled, nil))
        XCTAssertFalse(store.accept(.available(version: "late"), generation: old))
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
    }

    func testInstallingAndAwaitingRelaunchCannotBeLocallyCancelled() {
        let store = UpdateStore()
        advanceToStaged(store)
        for state in [UpdateState.installing(receipt), .awaitingRelaunch(receipt)] {
            XCTAssertTrue(store.accept(state, generation: store.generation))
            let generation = store.generation
            XCTAssertFalse(store.cancel())
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(store.generation, generation)
        }
    }

    func testInterruptedTransactionsRestoreReceiptAndRequireRecovery() throws {
        for interrupted in [UpdateState.staged(receipt), .installing(receipt), .awaitingRelaunch(receipt)] {
            let storage = InMemoryStorage()
            try storage.write(JSONEncoder().encode(interrupted), key: "update.v1")
            let store = UpdateStore(storage: storage)
            XCTAssertEqual(store.state, .failed(.interruptedUpdate, receipt))
            XCTAssertFalse(store.accept(.checking, generation: store.generation))
            let old = store.generation
            let recovered = store.renewGeneration()
            XCTAssertFalse(store.accept(.completed(receipt), generation: old))
            XCTAssertTrue(store.accept(.completed(receipt), generation: recovered))
        }
    }

    func testInterruptedPreTransactionWorkRestartsWithoutReceipt() throws {
        for interrupted in [UpdateState.checking, .downloading(progress: 0.5)] {
            let storage = InMemoryStorage()
            try storage.write(JSONEncoder().encode(interrupted), key: "update.v1")
            let store = UpdateStore(storage: storage)
            XCTAssertEqual(store.state, .failed(.interruptedUpdate, nil))
            XCTAssertTrue(store.accept(.checking, generation: store.renewGeneration()))
        }
    }

    func testPersistenceFailureDoesNotAdvanceUpdateState() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        storage.failWrites = true
        XCTAssertFalse(store.accept(.checking, generation: store.generation))
        XCTAssertEqual(store.state, .idle)
        XCTAssertEqual(store.persistenceFailure, .persistence)
        storage.failWrites = false
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertNil(store.persistenceFailure)
    }
}

@MainActor
final class F03FakeServiceContractTests: XCTestCase {
    private let receipt = OperationReceipt(createdAt: Date(timeIntervalSince1970: 1_700_000_000))

    private func assertFailure<T>(_ outcome: ServiceOutcome<T>, _ expected: ServiceFailure,
                                  file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let actual) = outcome else {
            return XCTFail("Expected failure \(expected)", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertUpdate(_ outcome: ServiceOutcome<UpdateState>, _ expected: UpdateState,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard case .success(let actual) = outcome else {
            return XCTFail("Expected update state \(expected)", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    func testTelemetryExplicitDisconnectedAndTimeoutOutcomes() async {
        for reason in [ServiceFailure.disconnected, .timedOut] {
            let service = FakeTelemetryService(outcome: .failure(reason))
            assertFailure(await service.sample(), reason)
        }
    }

    func testHelperExplicitDeniedTimeoutAndDisconnectedOutcomes() async {
        let service = FakeHelperService()
        for reason in [ServiceFailure.denied, .timedOut, .disconnected] {
            service.registrationOutcome = .failure(reason)
            assertFailure(await service.register(receipt: receipt), reason)
        }
        XCTAssertEqual(service.registeredReceipts, [receipt.id])
    }

    func testUpdateExplicitNetworkAndInterruptedOutcomesDoNotCreateTransaction() async {
        let service = FakeUpdateService()
        service.availableVersion = .failure(.network)
        assertFailure(await service.check(), .network)
        for reason in [ServiceFailure.network, .interruptedUpdate] {
            service.failure = reason
            assertFailure(await service.download(version: "2", receipt: receipt), reason)
            assertFailure(await service.install(receipt: receipt), reason)
            assertFailure(await service.recover(receipt: receipt), reason)
            XCTAssertTrue(service.transactions.isEmpty)
        }
        service.failure = nil
        assertFailure(await service.recover(receipt: receipt), .interruptedUpdate)
        assertFailure(await service.install(receipt: receipt), .invalidData)
    }

    func testUpdateFakeIsIdempotentAndRecoversAcknowledgedInstall() async {
        let service = FakeUpdateService()
        assertUpdate(await service.download(version: "2", receipt: receipt), .staged(receipt))
        assertUpdate(await service.download(version: "2", receipt: receipt), .staged(receipt))
        assertUpdate(await service.install(receipt: receipt), .awaitingRelaunch(receipt))
        assertUpdate(await service.install(receipt: receipt), .awaitingRelaunch(receipt))
        assertUpdate(await service.recover(receipt: receipt), .awaitingRelaunch(receipt))
        assertFailure(await service.cancel(receipt: receipt), .interruptedUpdate)
        XCTAssertEqual(service.transactions.count, 1)
    }

    func testUpdateFakeCancelStagedTransactionDoesNotInstall() async {
        let service = FakeUpdateService()
        assertUpdate(await service.download(version: "2", receipt: receipt), .staged(receipt))
        assertUpdate(await service.cancel(receipt: receipt), .failed(.cancelled, receipt))
        assertFailure(await service.install(receipt: receipt), .invalidData)
        assertUpdate(await service.recover(receipt: receipt), .failed(.cancelled, receipt))
    }

    func testRemovalFailuresAndInterruptionsNeverClaimVerifiedAbsence() async {
        let helper = FakeHelperService()
        let uninstall = FakeUninstallCoordinator()
        for outcome in [RemovalOutcome.failed(.denied), .failed(.timedOut), .failed(.disconnected),
                        .failed(.interruptedRemoval), .interrupted(receipt), .cancelled] {
            helper.removalOutcome = outcome
            uninstall.outcome = outcome
            let helperResult = await helper.remove(receipt: receipt)
            let removalResult = await uninstall.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(helperResult, outcome)
            XCTAssertEqual(removalResult, outcome)
            XCTAssertTrue(uninstall.completed.isEmpty)
            let reconciled = await uninstall.reconcile(receipt: receipt)
            XCTAssertEqual(reconciled, .interrupted(receipt))
        }
    }

    func testVerifiedRemovalIsIdempotentAndReconcilesAsAbsent() async {
        let service = FakeUninstallCoordinator()
        let first = await service.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(first, .verifiedAbsent)
        service.outcome = .failed(.interruptedRemoval)
        let repeated = await service.removeOwnedResources(receipt: receipt)
        let reconciled = await service.reconcile(receipt: receipt)
        XCTAssertEqual(repeated, .verifiedAbsent)
        XCTAssertEqual(reconciled, .verifiedAbsent)
        XCTAssertEqual(service.completed, [receipt.id])
    }

    func testNotificationDenialUsesFakeWithoutRequestingOSPermission() async {
        let service = FakeNotificationBridge()
        service.requestedPermission = .denied
        let result = await service.requestAuthorization()
        guard case .success(let authorization) = result else { return XCTFail("Expected explicit authorization") }
        XCTAssertEqual(authorization, .denied)
        assertFailure(await service.deliver(identifier: "charged", title: "Charged", body: ""), .denied)
        XCTAssertTrue(service.deliveredIDs.isEmpty)
    }
}

// MARK: - F03 verifier regressions and cancellation matrix

extension F03PowerContractTests {
    func testFutureInitialSampleIsUnavailableAndCurrentSampleRecovers() {
        let clock = FakeWattClock(now: epoch)
        let store = PowerReadingStore(currentReading: reading(timestamp: epoch.addingTimeInterval(1)), clock: clock)
        XCTAssertEqual(store.currentReading, .unavailable)
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.freshness(maximumAge: 5), .unavailable)
        XCTAssertNil(store.currentReading.value(for: .delta))
        clock.advance(by: 2)
        let current = reading(timestamp: clock.now)
        XCTAssertTrue(store.accept(current, generation: store.generation))
        XCTAssertEqual(store.currentReading, current)
        XCTAssertEqual(store.freshness(maximumAge: 5), .fresh)
        XCTAssertNil(store.failure)
    }
}

extension F03PreferencesContractTests {
    func testInvalidSelectionNeverReachesPublisherOrPersistentStorage() {
        let storage = InMemoryStorage()
        let store = PreferencesStore(storage: storage)
        var observed: [[String]] = []
        let subscription = store.selectedComponentsPublisher.sink { observed.append($0) }
        defer { subscription.cancel() }
        store.selectedComponents = ["cpu", "gpu"]
        for invalid in [["cpu", "gpu", "display"], ["cpu", "cpu"], [""], ["   "]] {
            store.selectedComponents = invalid
            XCTAssertEqual(observed, [["CPU", "GPU"], ["cpu", "gpu"]])
            XCTAssertEqual(store.selectedComponents, ["cpu", "gpu"])
            XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["cpu", "gpu"])
            XCTAssertEqual(store.persistenceFailure, .invalidData)
        }
        store.selectedComponents = []
        store.selectedComponents = ["display"]
        XCTAssertEqual(observed, [["CPU", "GPU"], ["cpu", "gpu"], [], ["display"]])
        XCTAssertTrue(observed.allSatisfy { $0.count <= 2 && Set($0).count == $0.count && !$0.contains("") })
        XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["display"])
        XCTAssertNil(store.persistenceFailure)
    }
}

extension F03ApprovalContractTests {
    func testFailedWithdrawalPreservesOtherOriginEligibilityInBothJoinAndWithdrawalOrders() throws {
        for firstOrigin in ApprovalOrigin.allCases {
            for withdrawn in ApprovalOrigin.allCases {
                let other: ApprovalOrigin = firstOrigin == .onboarding ? .settings : .onboarding
                let storage = InMemoryStorage()
                let store = HelperApprovalStore(storage: storage)
                let first = try store.join(firstOrigin, reconciled: .absent)
                let second = try store.join(other, reconciled: .pending)
                let survivor = firstOrigin == withdrawn ? second : first
                let cancelled = firstOrigin == withdrawn ? first : second
                let checkpoint = store.checkpoint
                storage.failWrites = true
                XCTAssertThrowsError(try store.withdraw(withdrawn)) {
                    XCTAssertEqual($0 as? ServiceFailure, .persistence)
                }
                XCTAssertEqual(store.persistenceFailure, .persistence)
                XCTAssertEqual(store.checkpoint, checkpoint)
                XCTAssertEqual(HelperApprovalStore(storage: storage).checkpoint, checkpoint)
                XCTAssertFalse(store.canNavigate(cancelled.token))
                XCTAssertTrue(store.canNavigate(survivor.token))
                XCTAssertEqual(store.generation, survivor.token.generation)
                XCTAssertEqual(try store.receive(.connected, operationID: survivor.receipt.id,
                                                 generation: survivor.token.generation), [survivor.token])
                XCTAssertEqual(store.effectiveState, .connected)
            }
        }
    }

    func testBothWithdrawalOrdersRetireSharedWaitOnlyAfterLastInterest() throws {
        for firstOrigin in ApprovalOrigin.allCases {
            for withdrawn in ApprovalOrigin.allCases {
                let other: ApprovalOrigin = firstOrigin == .onboarding ? .settings : .onboarding
                let store = HelperApprovalStore()
                let first = try store.join(firstOrigin, reconciled: .absent)
                let second = try store.join(other, reconciled: .pending)
                let survivor = firstOrigin == withdrawn ? second : first
                try store.withdraw(withdrawn)
                XCTAssertTrue(store.checkpoint.desiredOn)
                XCTAssertTrue(store.canNavigate(survivor.token))
                try store.withdraw(survivor.token.origin)
                XCTAssertFalse(store.checkpoint.desiredOn)
                XCTAssertNil(store.generation)
                XCTAssertFalse(store.canNavigate(first.token))
                XCTAssertFalse(store.canNavigate(second.token))
                XCTAssertTrue(try store.receive(.connected, operationID: first.receipt.id,
                                                generation: first.token.generation).isEmpty)
                XCTAssertEqual(store.effectiveState, .awaitingApproval)
            }
        }
    }

    func testCompletionRetiresGenerationAndRejectsEveryLateStatusBeforeFreshAbsentRetry() throws {
        for origin in ApprovalOrigin.allCases {
            let store = HelperApprovalStore()
            let request = try store.join(origin, reconciled: .absent)
            XCTAssertEqual(try store.receive(.connected, operationID: request.receipt.id,
                                             generation: request.token.generation), [request.token])
            XCTAssertNil(store.generation)
            XCTAssertFalse(store.canNavigate(request.token))
            for late in [HelperReconciliation.pending, .absent, .unknown, .failed(.denied), .connected] {
                XCTAssertTrue(try store.receive(late, operationID: request.receipt.id,
                                                generation: request.token.generation).isEmpty)
                XCTAssertEqual(store.effectiveState, .connected)
            }
            let retry = try store.join(origin, reconciled: .absent)
            XCTAssertTrue(retry.registrationRequired)
            XCTAssertNotEqual(retry.receipt.id, request.receipt.id)
            XCTAssertNotEqual(retry.token.generation, request.token.generation)
            XCTAssertTrue(try store.receive(.connected, operationID: request.receipt.id,
                                            generation: request.token.generation).isEmpty)
            XCTAssertEqual(store.effectiveState, .absent)
            XCTAssertEqual(try store.receive(.connected, operationID: retry.receipt.id,
                                             generation: retry.token.generation), [retry.token])
        }
    }

    func testSuccessBeforeWithdrawalDoesNotRevokeEffectiveConnectionOrRedeliver() throws {
        for withdrawn in ApprovalOrigin.allCases {
            let store = HelperApprovalStore()
            let first = try store.join(.onboarding, reconciled: .absent)
            let second = try store.join(.settings, reconciled: .pending)
            XCTAssertEqual(try store.receive(.connected, operationID: first.receipt.id,
                                             generation: first.token.generation), [first.token, second.token])
            try store.withdraw(withdrawn)
            XCTAssertEqual(store.effectiveState, .connected)
            XCTAssertTrue(store.checkpoint.desiredOn)
            XCTAssertNil(store.generation)
            XCTAssertTrue(try store.receive(.failed(.cancelled), operationID: first.receipt.id,
                                            generation: first.token.generation).isEmpty)
            XCTAssertEqual(store.effectiveState, .connected)
        }
    }

    func testActiveRejoinReplacesOnlyItsPresentationForEitherOrigin() throws {
        for origin in ApprovalOrigin.allCases {
            let other: ApprovalOrigin = origin == .onboarding ? .settings : .onboarding
            let store = HelperApprovalStore()
            let old = try store.join(origin, reconciled: .absent)
            let peer = try store.join(other, reconciled: .pending)
            let rejoined = try store.join(origin, reconciled: .pending)
            XCTAssertEqual(rejoined.receipt, old.receipt)
            XCTAssertEqual(rejoined.token.generation, old.token.generation)
            XCTAssertFalse(rejoined.registrationRequired)
            XCTAssertNotEqual(rejoined.token.presentationID, old.token.presentationID)
            XCTAssertFalse(store.canNavigate(old.token))
            XCTAssertTrue(store.canNavigate(peer.token))
            let delivered = try store.receive(.connected, operationID: old.receipt.id,
                                              generation: old.token.generation)
            XCTAssertEqual(delivered.count, 2)
            XCTAssertTrue(delivered.contains(peer.token))
            XCTAssertTrue(delivered.contains(rejoined.token))
            XCTAssertFalse(delivered.contains(old.token))
        }
    }

    func testFailedTerminalPersistenceStillRejectsLateRepliesAndAllowsReconciledRetry() throws {
        let storage = InMemoryStorage()
        let store = HelperApprovalStore(storage: storage)
        let old = try store.join(.settings, reconciled: .absent)
        storage.failWrites = true
        XCTAssertThrowsError(try store.receive(.failed(.timedOut), operationID: old.receipt.id,
                                               generation: old.token.generation)) {
            XCTAssertEqual($0 as? ServiceFailure, .persistence)
        }
        XCTAssertNil(store.generation)
        XCTAssertFalse(store.canNavigate(old.token))
        XCTAssertTrue(try store.receive(.connected, operationID: old.receipt.id,
                                        generation: old.token.generation).isEmpty)
        XCTAssertEqual(store.effectiveState, .failed(.timedOut))
        storage.failWrites = false
        let retry = try store.join(.settings, reconciled: .absent)
        XCTAssertTrue(retry.registrationRequired)
        XCTAssertNotEqual(retry.receipt, old.receipt)
        XCTAssertTrue(store.canNavigate(retry.token))
        XCTAssertNil(store.persistenceFailure)
    }
}

extension F03UpdateContractTests {
    func testCancelledStagedDiscardRequiresExactReceiptAndCurrentGenerationBeforeRetry() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        advanceToStaged(store)
        let stale = store.generation
        XCTAssertTrue(store.cancel())
        let current = store.generation
        let incorrect = OperationReceipt(createdAt: receipt.createdAt)
        let forged = OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1))
        XCTAssertFalse(store.accept(.checking, generation: current))
        for (candidate, generation) in [(receipt, stale), (incorrect, current), (forged, current)] {
            XCTAssertFalse(store.acknowledgeDiscard(candidate, generation: generation))
            XCTAssertEqual(store.state, .failed(.cancelled, receipt))
            XCTAssertEqual(store.generation, current)
        }
        XCTAssertTrue(store.acknowledgeDiscard(receipt, generation: current))
        XCTAssertEqual(store.state, .idle)
        XCTAssertEqual(UpdateStore(storage: storage).state, .idle)
        XCTAssertNotEqual(store.generation, current)
        XCTAssertFalse(store.acknowledgeDiscard(receipt, generation: current))
        XCTAssertFalse(store.accept(.staged(receipt), generation: stale))
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
    }

    func testDiscardPersistenceFailureRetainsReceiptAndAcknowledgementCanBeRetried() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        advanceToStaged(store)
        XCTAssertTrue(store.cancel())
        let generation = store.generation
        storage.failWrites = true
        XCTAssertFalse(store.acknowledgeDiscard(receipt, generation: generation))
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertEqual(store.state, .failed(.cancelled, receipt))
        XCTAssertEqual(UpdateStore(storage: storage).state, store.state)
        XCTAssertEqual(store.generation, generation)
        storage.failWrites = false
        XCTAssertTrue(store.acknowledgeDiscard(receipt, generation: generation))
        XCTAssertNil(store.persistenceFailure)
        XCTAssertEqual(UpdateStore(storage: storage).state, .idle)
    }

    func testCancellationWriteFailureInvalidatesLateWorkWithoutClaimingSuccess() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        advanceToStaged(store)
        let old = store.generation
        storage.failWrites = true
        XCTAssertFalse(store.cancel())
        XCTAssertEqual(store.state, .staged(receipt))
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertNotEqual(store.generation, old)
        XCTAssertFalse(store.accept(.installing(receipt), generation: old))
        storage.failWrites = false
        XCTAssertTrue(store.cancel())
        XCTAssertEqual(store.state, .failed(.cancelled, receipt))
        XCTAssertNil(store.persistenceFailure)
    }

    func testAvailableAndDownloadingCancellationRejectLateStagingAndAllowRetry() {
        for downloading in [false, true] {
            let store = UpdateStore()
            let old = store.generation
            XCTAssertTrue(store.accept(.checking, generation: old))
            XCTAssertTrue(store.accept(.available(version: "2"), generation: old))
            if downloading { XCTAssertTrue(store.accept(.downloading(progress: 0.5), generation: old)) }
            XCTAssertTrue(store.cancel())
            XCTAssertEqual(store.state, .failed(.cancelled, nil))
            XCTAssertFalse(store.accept(.staged(receipt), generation: old))
            XCTAssertTrue(store.accept(.checking, generation: store.generation))
        }
    }
}

extension F03FakeServiceContractTests {
    func testDiscardedUpdateReceiptCannotBeReusedAndFreshReceiptCanRetry() async {
        let service = FakeUpdateService()
        assertUpdate(await service.download(version: "2", receipt: receipt), .staged(receipt))
        assertUpdate(await service.cancel(receipt: receipt), .failed(.cancelled, receipt))
        let forged = OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1))
        assertFailure(await service.discard(receipt: forged), .invalidData)
        for _ in 0..<2 {
            guard case .success(let acknowledged) = await service.discard(receipt: receipt) else {
                return XCTFail("Expected idempotent discard acknowledgement")
            }
            XCTAssertEqual(acknowledged, receipt)
        }
        XCTAssertTrue(service.transactions.isEmpty)
        assertFailure(await service.download(version: "2", receipt: receipt), .invalidData)
        assertFailure(await service.install(receipt: receipt), .invalidData)
        assertFailure(await service.recover(receipt: receipt), .interruptedUpdate)
        assertFailure(await service.cancel(receipt: receipt), .invalidData)
        let fresh = OperationReceipt(createdAt: receipt.createdAt)
        assertUpdate(await service.download(version: "2", receipt: fresh), .staged(fresh))
        assertUpdate(await service.install(receipt: fresh), .awaitingRelaunch(fresh))
    }

    func testDiscardFailureRetainsStagedTransactionAndInstalledUpdateCannotBeDiscarded() async {
        let service = FakeUpdateService()
        assertUpdate(await service.download(version: "2", receipt: receipt), .staged(receipt))
        for failure in [ServiceFailure.network, .interruptedUpdate] {
            service.failure = failure
            assertFailure(await service.discard(receipt: receipt), failure)
            assertFailure(await service.cancel(receipt: receipt), failure)
            XCTAssertEqual(service.transactions[receipt.id], .staged(receipt))
        }
        service.failure = nil
        assertUpdate(await service.install(receipt: receipt), .awaitingRelaunch(receipt))
        assertFailure(await service.discard(receipt: receipt), .interruptedUpdate)
        assertUpdate(await service.recover(receipt: receipt), .awaitingRelaunch(receipt))
    }

    func testHelperFakeFailuresReachOnlyStillInterestedOriginInEitherOrder() async throws {
        for withdrawn in ApprovalOrigin.allCases {
            for reason in [ServiceFailure.denied, .timedOut, .disconnected] {
                let service = FakeHelperService()
                service.registrationOutcome = .failure(reason)
                let store = HelperApprovalStore()
                let other: ApprovalOrigin = withdrawn == .onboarding ? .settings : .onboarding
                let first = try store.join(withdrawn, reconciled: .absent)
                let survivor = try store.join(other, reconciled: .pending)
                try store.withdraw(withdrawn)
                guard case .failure(let actual) = await service.register(receipt: first.receipt) else {
                    return XCTFail("Expected configured registration failure")
                }
                XCTAssertEqual(actual, reason)
                XCTAssertEqual(try store.receive(.failed(actual), operationID: first.receipt.id,
                                                 generation: first.token.generation), [survivor.token])
                XCTAssertEqual(store.checkpoint.origins[withdrawn]?.failure, .cancelled)
                XCTAssertEqual(store.checkpoint.origins[other]?.failure, reason)
                XCTAssertNil(store.generation)
                XCTAssertFalse(store.checkpoint.desiredOn)
            }
        }
    }

    func testCancelledTasksDoNotBeginFakeWorkOrRevokeVerifiedRemoval() async {
        let helper = FakeHelperService()
        let update = FakeUpdateService()
        let removal = FakeUninstallCoordinator()
        let completed = await removal.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(completed, .verifiedAbsent)
        let helperCompleted = await helper.remove(receipt: receipt)
        XCTAssertEqual(helperCompleted, .verifiedAbsent)
        let fresh = OperationReceipt(createdAt: receipt.createdAt)
        // Main-actor task cannot start before this synchronous turn cancels it; no sleeps/races.
        let task = Task { @MainActor in
            self.assertFailure(await FakeTelemetryService().sample(), .cancelled)
            self.assertFailure(await helper.register(receipt: fresh), .cancelled)
            self.assertFailure(await update.check(), .cancelled)
            self.assertFailure(await update.download(version: "2", receipt: fresh), .cancelled)
            self.assertFailure(await update.install(receipt: fresh), .cancelled)
            self.assertFailure(await update.recover(receipt: fresh), .cancelled)
            self.assertFailure(await update.cancel(receipt: fresh), .cancelled)
            self.assertFailure(await update.discard(receipt: fresh), .cancelled)
            let helperFresh = await helper.remove(receipt: fresh)
            let removalFresh = await removal.removeOwnedResources(receipt: fresh)
            XCTAssertEqual(helperFresh, .cancelled)
            XCTAssertEqual(removalFresh, .cancelled)
            let helperPrior = await helper.remove(receipt: self.receipt)
            let removalPrior = await removal.removeOwnedResources(receipt: self.receipt)
            XCTAssertEqual(helperPrior, .verifiedAbsent)
            XCTAssertEqual(removalPrior, .verifiedAbsent)
        }
        task.cancel()
        await task.value
        XCTAssertTrue(helper.registeredReceipts.isEmpty)
        XCTAssertTrue(update.transactions.isEmpty)
        XCTAssertEqual(removal.completed, [receipt.id])
    }
}

@MainActor
private final class P02Driver: HelperLifecycleDriver {
    var current: HelperRegistrationStatus = .absent
    var candidate = HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 1)
    var registrations = 0
    var removals = 0
    var updates = 0
    var removalFails = false
    var updateFails = false
    var applied = false
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { applied }
    func status() async throws -> HelperRegistrationStatus { current }
    func verifyCandidate() throws -> HelperPeer { candidate }
    func register(receipt: OperationReceipt) async throws { registrations += 1; current = .requiresApproval }
    func update(receipt: OperationReceipt) async throws {
        updates += 1
        if updateFails { throw ServiceFailure.interruptedUpdate }
    }
    func unregister(receipt: OperationReceipt) async throws {
        removals += 1
        if removalFails { throw ServiceFailure.interruptedRemoval }
        current = .absent
    }
}

@MainActor
private final class P02Transport: HelperIPCTransport {
    var peer = HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 1)
    var sent: [HelperMessage] = []
    var corrupt = false
    var sendFailure: ServiceFailure?
    var onSend: (() -> Void)?
    var hold = false
    var pending: CheckedContinuation<HelperMessage, any Error>?
    var didSuspend: (() -> Void)?
    func connect() async throws -> HelperPeer { peer }
    func invalidate() {}
    func send(_ request: HelperMessage) async throws -> HelperMessage {
        sent.append(request)
        if let sendFailure { throw sendFailure }
        onSend?()
        if hold {
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                didSuspend?()
            }
        }
        return corrupt ? HelperMessage(requestID: UUID(), generation: request.generation,
                                       receiptID: request.receiptID, command: request.command) : request
    }
}

@MainActor
final class P02HelperLifecycleTests: XCTestCase {
    private func fixture() -> (P02Driver, P02Transport, HelperLifecycleAdapter) {
        let driver = P02Driver(), transport = P02Transport()
        return (driver, transport, HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: driver.candidate))
    }
    private var receipt: OperationReceipt { OperationReceipt(createdAt: Date(timeIntervalSince1970: 100)) }

    func testRegistrationApprovalAuthenticationAndIPC() async {
        let (driver, transport, adapter) = fixture()
        let operation = receipt
        _ = await adapter.register(receipt: operation)
        _ = await adapter.register(receipt: operation)
        XCTAssertEqual(driver.registrations, 1)
        XCTAssertEqual(adapter.state, .awaitingApproval)
        XCTAssertTrue(transport.sent.isEmpty)
        driver.current = .enabled
        guard case .connected = await adapter.reconcile(receipt: operation) else { return XCTFail("authenticated approval") }
        guard case .success(let reply) = await adapter.request(.ping) else { return XCTFail("IPC") }
        XCTAssertEqual(reply.generation, adapter.generation)
        XCTAssertEqual(transport.sent.count, 2)
    }

    func testCandidateAndPeerMismatchNeverSendIPC() async {
        let (driver, transport, adapter) = fixture()
        driver.candidate = HelperPeer(identifier: "evil", team: "TEST", protocolVersion: 1)
        guard case .failure(.untrustedIdentity) = await adapter.register(receipt: receipt) else { return XCTFail("candidate") }
        XCTAssertEqual(driver.registrations, 0)
        driver.current = .enabled
        transport.peer = driver.candidate
        guard case .failed(.untrustedIdentity) = await adapter.reconcile(receipt: nil) else { return XCTFail("peer") }
        XCTAssertTrue(transport.sent.isEmpty)
        transport.peer = HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 2)
        guard case .failed(.incompatibleVersion) = await adapter.reconcile(receipt: nil) else { return XCTFail("version") }
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testUnknownDisabledAndMalformedReplyFailClosed() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .unknown
        guard case .failure(.unknownStatus) = await adapter.register(receipt: receipt) else { return XCTFail("unknown") }
        XCTAssertEqual(driver.registrations, 0)
        driver.current = .disabled
        guard case .failed(.denied) = await adapter.reconcile(receipt: nil) else { return XCTFail("disabled") }
        driver.current = .enabled; transport.corrupt = true
        guard case .failed(.invalidData) = await adapter.reconcile(receipt: nil) else { return XCTFail("correlation") }
        XCTAssertNotEqual(adapter.state, .connected)
    }

    func testStaleGenerationCannotConnectAndReconnectAuthenticatesAgain() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .enabled
        transport.onSend = { adapter.disconnect() }
        guard case .failed(.disconnected) = await adapter.reconcile(receipt: nil) else { return XCTFail("stale") }
        XCTAssertEqual(adapter.state, .disconnected)
        transport.onSend = nil
        guard case .connected = await adapter.reconcile(receipt: nil) else { return XCTFail("reconnect") }
        XCTAssertEqual(transport.sent.count, 2)
    }

    func testLateReconnectDuringRemovalCannotResurrect() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .enabled; transport.hold = true
        let suspended = expectation(description: "request suspended")
        transport.didSuspend = { suspended.fulfill() }
        let task = Task { await adapter.reconcile(receipt: nil) }
        await fulfillment(of: [suspended], timeout: 2)
        let removalReceipt = receipt
        let result = await adapter.remove(receipt: removalReceipt)
        XCTAssertEqual(result, .interrupted(removalReceipt))
        transport.pending?.resume(returning: transport.sent[0]); transport.pending = nil
        guard case .failed(.disconnected) = await task.value else { return XCTFail("late reply") }
        XCTAssertEqual(adapter.state, .disconnected)
        transport.hold = false
        let recovered = await adapter.remove(receipt: removalReceipt)
        XCTAssertEqual(recovered, .verifiedAbsent)
        XCTAssertEqual(adapter.state, .absent)
    }

    func testTaskCancellationRejectsLateReply() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .enabled; transport.hold = true
        let suspended = expectation(description: "request suspended")
        transport.didSuspend = { suspended.fulfill() }
        let task = Task { await adapter.reconcile(receipt: nil) }
        await fulfillment(of: [suspended], timeout: 2)
        task.cancel()
        transport.pending?.resume(returning: transport.sent[0]); transport.pending = nil
        guard case .failed(.cancelled) = await task.value else { return XCTFail("cancelled reply") }
        XCTAssertNotEqual(adapter.state, .connected)
    }

    func testOriginCancellationRejoinPreservesOtherOriginAndNoDuplicateRegistration() async throws {
        let (driver, _, adapter) = fixture()
        let storage = InMemoryStorage()
        let store = HelperApprovalStore(storage: storage, clock: FakeWattClock())
        let first = try store.join(.onboarding, reconciled: await adapter.reconcile(receipt: nil))
        _ = await adapter.register(receipt: first.receipt)
        let second = try store.join(.settings, reconciled: await adapter.reconcile(receipt: first.receipt))
        try store.withdraw(.onboarding)
        XCTAssertFalse(store.canNavigate(first.token))
        XCTAssertTrue(store.canNavigate(second.token))
        let rejoined = try store.join(.onboarding, reconciled: await adapter.reconcile(receipt: first.receipt))
        XCTAssertFalse(rejoined.registrationRequired)
        driver.current = .enabled
        let status = await adapter.reconcile(receipt: first.receipt)
        let delivered = try store.receive(status, operationID: rejoined.receipt.id, generation: rejoined.token.generation)
        XCTAssertEqual(Set(delivered.map(\.origin)), Set([.onboarding, .settings]))
        XCTAssertFalse(delivered.contains(first.token))
        XCTAssertTrue(try store.receive(status, operationID: rejoined.receipt.id, generation: rejoined.token.generation).isEmpty)
        XCTAssertEqual(driver.registrations, 1)
        XCTAssertNil(storage.values["preferences.v1"])
    }

    func testAllOriginsWithdrawLateApprovalOnlyUpdatesEffectiveState() async throws {
        let (driver, _, adapter) = fixture()
        let store = HelperApprovalStore(clock: FakeWattClock())
        let first = try store.join(.onboarding, reconciled: .absent)
        _ = await adapter.register(receipt: first.receipt)
        try store.withdraw(.onboarding)
        driver.current = .enabled
        let status = await adapter.reconcile(receipt: first.receipt)
        XCTAssertTrue(try store.receive(status, operationID: first.receipt.id, generation: first.token.generation).isEmpty)
        store.reconcileEffective(status)
        XCTAssertEqual(store.effectiveState, .connected)
        XCTAssertFalse(store.checkpoint.desiredOn)
        let retry = try store.join(.onboarding, reconciled: status)
        XCTAssertNotEqual(first.token.generation, retry.token.generation)
        XCTAssertFalse(retry.registrationRequired)
        XCTAssertEqual(driver.registrations, 1)
    }

    func testRemoveAndUpdateRecoverWithoutDuplicateUpdate() async {
        let (driver, _, adapter) = fixture()
        driver.current = .enabled; driver.updateFails = true
        let updateReceipt = receipt
        guard case .failure(.interruptedUpdate) = await adapter.update(receipt: updateReceipt) else { return XCTFail("interrupted update") }
        driver.updateFails = false
        guard case .failure(.interruptedUpdate) = await adapter.update(receipt: updateReceipt) else { return XCTFail("connection is not update proof") }
        driver.applied = true
        guard case .success(.connected) = await adapter.update(receipt: updateReceipt) else { return XCTFail("update recovery") }
        XCTAssertEqual(driver.updates, 1)
        driver.removalFails = true
        let removalReceipt = receipt
        let failed = await adapter.remove(receipt: removalReceipt)
        XCTAssertEqual(failed, .failed(.interruptedRemoval))
        driver.removalFails = false
        let recovered = await adapter.remove(receipt: removalReceipt)
        XCTAssertEqual(recovered, .verifiedAbsent)
        let repeated = await adapter.remove(receipt: removalReceipt)
        XCTAssertEqual(repeated, .verifiedAbsent)
        XCTAssertEqual(driver.removals, 2)
    }
}

extension P02HelperLifecycleTests {
    func testSuccessfulUpdateRequiresReceiptProofAndAuthenticatedReconnect() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .enabled; driver.applied = true
        guard case .success(.connected) = await adapter.update(receipt: receipt) else { return XCTFail("update") }
        XCTAssertEqual(driver.updates, 1)
        XCTAssertEqual(transport.sent.map(\.command), [.ping, .prepareUpdate, .ping])
    }

    func testLateIPCReplyWithWrongGenerationFailsClosed() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .enabled
        _ = await adapter.reconcile(receipt: nil)
        transport.hold = true
        let suspended = expectation(description: "IPC suspended")
        transport.didSuspend = { suspended.fulfill() }
        let task = Task { await adapter.request(.ping) }
        await fulfillment(of: [suspended], timeout: 2)
        let request = transport.sent.last!
        transport.pending?.resume(returning: HelperMessage(requestID: request.requestID, generation: UUID(),
                                                            receiptID: request.receiptID, command: request.command))
        transport.pending = nil
        guard case .failure(.invalidData) = await task.value else { return XCTFail("generation mismatch") }
        XCTAssertNotEqual(adapter.state, .connected)
    }

    func testUnknownRemovalDoesNotMutateAndPreCancelledRegistrationDoesNotInstall() async {
        let (driver, _, adapter) = fixture()
        driver.current = .unknown
        let result = await adapter.remove(receipt: receipt)
        XCTAssertEqual(result, .failed(.unknownStatus))
        XCTAssertEqual(driver.removals, 0)
        let task = Task { await adapter.register(receipt: receipt) }
        task.cancel()
        guard case .failure(.cancelled) = await task.value else { return XCTFail("pre-cancel") }
        XCTAssertEqual(driver.registrations, 0)
    }
}


extension P02HelperLifecycleTests {
    func testTimeoutAndDisconnectAreRetryableWithoutRegistration() async {
        let (driver, transport, adapter) = fixture()
        driver.current = .enabled
        for reason in [ServiceFailure.timedOut, .disconnected] {
            transport.sendFailure = reason
            guard case .failed(let actual) = await adapter.reconcile(receipt: nil) else { return XCTFail("failure") }
            XCTAssertEqual(actual, reason)
            XCTAssertNotEqual(adapter.state, .connected)
        }
        transport.sendFailure = nil
        guard case .connected = await adapter.reconcile(receipt: nil) else { return XCTFail("retry") }
        XCTAssertEqual(driver.registrations, 0)
    }
}

// MARK: - P03 notification/login deterministic adapter coverage
@MainActor
private final class P03NotificationDriver: NotificationSystemDriver {
    var current: NotificationPermission = .notDetermined
    var requested: NotificationPermission = .authorized
    var requests = 0
    var identifiers: [String] = []
    var failure: ServiceFailure?
    var onPermission: (() async -> Void)?
    func permission() async -> NotificationPermission {
        await onPermission?()
        return current
    }
    func requestPermission() async throws {
        requests += 1
        if let failure { throw failure }
        current = requested
    }
    func enqueue(identifier: String, title: String, body: String) async throws {
        if let failure { throw failure }
        identifiers.append(identifier)
    }
}
@MainActor
private final class P03LoginDriver: LoginRegistrationDriver {
    var status: LoginRegistrationStatus = .notRegistered
    var registeredStatus: LoginRegistrationStatus = .enabled
    var removedStatus: LoginRegistrationStatus = .notRegistered
    var registers = 0
    var removes = 0
    var failure: ServiceFailure?
    func register() throws {
        registers += 1
        if let failure { throw failure }
        status = registeredStatus
    }
    func unregister() throws {
        removes += 1
        if let failure { throw failure }
        status = removedStatus
    }
}
@MainActor
final class P03NotificationLoginTests: XCTestCase {
    private func assertSuccess<T: Equatable>(_ outcome: ServiceOutcome<T>, _ value: T,
                                              file: StaticString = #filePath, line: UInt = #line) {
        if case .success(let actual) = outcome { XCTAssertEqual(actual, value, file: file, line: line) }
        else { XCTFail("Expected success", file: file, line: line) }
    }
    private func assertFailure<T>(_ outcome: ServiceOutcome<T>, _ failure: ServiceFailure,
                                 file: StaticString = #filePath, line: UInt = #line) {
        if case .failure(let actual) = outcome { XCTAssertEqual(actual, failure, file: file, line: line) }
        else { XCTFail("Expected failure", file: file, line: line) }
    }
    func testJ63J64CompletePreferencePermissionMatrix() async {
        for event in PowerNotificationEvent.allCases {
            for enabled in [false, true] {
                for permission in NotificationPermission.allCases {
                    let preferences = PreferencesStore()
                    preferences.fullyChargedNotification = enabled
                    preferences.chargerNotification = enabled
                    let driver = P03NotificationDriver()
                    driver.current = permission
                    let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
                    let result = await effects.handle(event, episodeID: "episode")
                    let expected: NotificationEffect = !enabled ? .preferenceOff :
                        permission == .authorized ? .accepted :
                        permission == .notDetermined ? .requestPermission : .openNotificationSettings
                    XCTAssertEqual(result, expected)
                    XCTAssertEqual(driver.identifiers.count, expected == .accepted ? 1 : 0)
                    XCTAssertEqual(driver.requests, 0)
                    XCTAssertEqual(preferences.fullyChargedNotification, enabled)
                    XCTAssertEqual(preferences.chargerNotification, enabled)
                    XCTAssertFalse(preferences.onboarding.helperOptIn)
                }
            }
        }
    }
    func testPermissionRequestIsExplicitAndDenialNeverReprompts() async {
        let driver = P03NotificationDriver()
        driver.requested = .denied
        let bridge = SystemNotificationBridge(driver: driver)
        let initial = await bridge.authorization()
        XCTAssertEqual(initial, .notDetermined)
        XCTAssertEqual(driver.requests, 0)
        assertSuccess(await bridge.requestAuthorization(), .denied)
        assertSuccess(await bridge.requestAuthorization(), .denied)
        XCTAssertEqual(driver.requests, 1)
        driver.current = .authorized // user changed System Settings
        assertSuccess(await bridge.requestAuthorization(), .authorized)
        XCTAssertEqual(driver.requests, 1)
    }
    func testAuthorizationFailureAndRecovery() async {
        let driver = P03NotificationDriver()
        let bridge = SystemNotificationBridge(driver: driver)
        driver.failure = .denied
        assertFailure(await bridge.requestAuthorization(), .unknownStatus)
        driver.failure = nil
        assertSuccess(await bridge.requestAuthorization(), .authorized)
        XCTAssertEqual(driver.requests, 2)
    }
    func testNotificationEpisodeIdempotenceAndFailureRetry() async {
        let driver = P03NotificationDriver()
        driver.current = .authorized
        let bridge = SystemNotificationBridge(driver: driver)
        driver.failure = .network
        assertFailure(await bridge.deliver(identifier: "episode", title: "", body: ""), .unknownStatus)
        driver.failure = nil
        assertSuccess(await bridge.deliver(identifier: "episode", title: "", body: ""), true)
        assertSuccess(await bridge.deliver(identifier: "episode", title: "", body: ""), false)
        assertFailure(await bridge.deliver(identifier: "  ", title: "", body: ""), .invalidData)
        driver.current = .denied
        assertFailure(await bridge.deliver(identifier: "next", title: "", body: ""), .denied)
        XCTAssertEqual(driver.identifiers, ["episode"])
    }
    func testIndependentEventIDsAndPreferenceChanges() async {
        let driver = P03NotificationDriver()
        driver.current = .authorized
        let preferences = PreferencesStore()
        preferences.fullyChargedNotification = true
        let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
        let full = await effects.handle(.fullyCharged, episodeID: "1")
        let charger = await effects.handle(.insufficientCharger, episodeID: "1")
        let duplicate = await effects.handle(.fullyCharged, episodeID: "1")
        XCTAssertEqual(full, .accepted); XCTAssertEqual(charger, .accepted); XCTAssertEqual(duplicate, .duplicate)
        XCTAssertEqual(Set(driver.identifiers).count, 2)
        preferences.fullyChargedNotification = false
        let off = await effects.handle(.fullyCharged, episodeID: "2")
        XCTAssertEqual(off, .preferenceOff)
    }
    func testPreferenceDisabledDuringStatusReadSuppressesDelivery() async {
        let driver = P03NotificationDriver()
        driver.current = .authorized
        let preferences = PreferencesStore()
        driver.onPermission = { preferences.chargerNotification = false }
        let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
        let result = await effects.handle(.insufficientCharger, episodeID: "1")
        XCTAssertEqual(result, .preferenceOff)
        XCTAssertTrue(driver.identifiers.isEmpty)
    }
    func testConcurrentDeliverySameIDDoesNotEnqueueTwice() async {
        let driver = P03NotificationDriver()
        driver.current = .authorized
        var continuation: CheckedContinuation<Void, Never>?
        let suspended = expectation(description: "permission suspended")
        driver.onPermission = {
            await withCheckedContinuation { continuation = $0; suspended.fulfill() }
        }
        let bridge = SystemNotificationBridge(driver: driver)
        let first = Task { await bridge.deliver(identifier: "1", title: "", body: "") }
        await fulfillment(of: [suspended], timeout: 2)
        assertSuccess(await bridge.deliver(identifier: "1", title: "", body: ""), false)
        continuation?.resume()
        assertSuccess(await first.value, true)
        XCTAssertEqual(driver.identifiers, ["1"])
    }
    func testLoginRegisterReconcileRemoveIdempotenceAndRestart() async {
        let driver = P03LoginDriver()
        let service = SystemLoginItemService(driver: driver)
        assertSuccess(await service.setEnabled(true), true)
        assertSuccess(await service.setEnabled(true), true)
        XCTAssertTrue(service.reconcile(desiredEnabled: true).matchesPreference)
        let restarted = SystemLoginItemService(driver: driver)
        assertSuccess(await restarted.setEnabled(true), true)
        XCTAssertEqual(driver.registers, 1)
        assertSuccess(await restarted.remove(), false)
        assertSuccess(await restarted.remove(), false)
        XCTAssertEqual(driver.removes, 1)
        XCTAssertTrue(restarted.reconcile(desiredEnabled: false).matchesPreference)
    }
    func testLoginPreferenceStatusMatrixIsReadOnly() async {
        for desired in [false, true] {
            for status in LoginRegistrationStatus.allCases {
                let driver = P03LoginDriver(); driver.status = status
                let service = SystemLoginItemService(driver: driver)
                let result = service.reconcile(desiredEnabled: desired)
                XCTAssertEqual(result.effectiveEnabled, status == .enabled)
                XCTAssertEqual(result.needsSystemSettings, desired && status == .requiresApproval)
                XCTAssertEqual(result.matchesPreference, desired ? status == .enabled : status == .notRegistered)
                XCTAssertEqual(driver.registers + driver.removes, 0)
            }
        }
    }
    func testLoginPendingApprovalDoesNotRegisterAgainAndCanRemove() async {
        let driver = P03LoginDriver(); driver.registeredStatus = .requiresApproval
        let service = SystemLoginItemService(driver: driver)
        assertSuccess(await service.setEnabled(true), false)
        assertSuccess(await service.setEnabled(true), false)
        XCTAssertEqual(driver.registers, 1)
        XCTAssertTrue(service.reconcile(desiredEnabled: true).needsSystemSettings)
        assertSuccess(await service.effectiveEnabled(), false)
        assertSuccess(await service.remove(), false)
        XCTAssertEqual(driver.removes, 1)
        driver.status = .enabled // externally approved state is freshly read
        assertSuccess(await service.effectiveEnabled(), true)
    }
    func testLoginUnknownAndMissingFailClosed() async {
        for status in [LoginRegistrationStatus.unknown, .notFound] {
            let driver = P03LoginDriver(); driver.status = status
            let service = SystemLoginItemService(driver: driver)
            assertFailure(await service.setEnabled(true), .unknownStatus)
            assertFailure(await service.remove(), .unknownStatus)
            assertFailure(await service.effectiveEnabled(), .unknownStatus)
            XCTAssertEqual(driver.registers + driver.removes, 0)
        }
    }
    func testLoginFailureNeverPersistsEffectiveSuccessOrBlindlyRetries() async {
        let driver = P03LoginDriver(); driver.failure = .denied
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.openAtLogin = true
        let service = SystemLoginItemService(driver: driver)
        assertFailure(await service.apply(preferences), .denied)
        assertFailure(await service.apply(preferences), .unknownStatus)
        XCTAssertEqual(driver.registers, 1)
        XCTAssertTrue(PreferencesStore(storage: storage).openAtLogin)
        XCTAssertFalse(service.reconcile(desiredEnabled: true).effectiveEnabled)
        driver.status = .enabled
        assertSuccess(await service.apply(preferences), true)
        storage.failWrites = true
        preferences.openAtLogin = false
        assertFailure(await service.apply(preferences), .persistence)
        XCTAssertEqual(driver.removes, 0)
    }
    func testLoginUnverifiedRemovalDoesNotClaimAbsence() async {
        let driver = P03LoginDriver(); driver.status = .enabled; driver.removedStatus = .enabled
        let service = SystemLoginItemService(driver: driver)
        assertFailure(await service.remove(), .unknownStatus)
        assertFailure(await service.remove(), .unknownStatus)
        XCTAssertEqual(driver.removes, 1)
        XCTAssertFalse(service.reconcile(desiredEnabled: false).matchesPreference)
        driver.status = .notRegistered
        assertSuccess(await service.remove(), false)
    }
    func testPreCancelledTasksPerformNoEffects() async {
        let notifications = P03NotificationDriver()
        let login = P03LoginDriver()
        let bridge = SystemNotificationBridge(driver: notifications)
        let service = SystemLoginItemService(driver: login)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            assertFailure(await bridge.requestAuthorization(), .cancelled)
            assertFailure(await bridge.deliver(identifier: "1", title: "", body: ""), .cancelled)
            assertFailure(await service.setEnabled(true), .cancelled)
        }
        await task.value
        XCTAssertEqual(notifications.requests + notifications.identifiers.count + login.registers, 0)
    }
    func testNativeStatusMappingsWithoutInstantiatingSystemServices() {
        XCTAssertEqual(NativeNotificationDriver.map(.notDetermined), .notDetermined)
        XCTAssertEqual(NativeNotificationDriver.map(.denied), .denied)
        XCTAssertEqual(NativeNotificationDriver.map(.authorized), .authorized)
        XCTAssertEqual(NativeNotificationDriver.map(.provisional), .provisional)
        XCTAssertEqual(NativeLoginRegistrationDriver.map(.notRegistered), .notRegistered)
        XCTAssertEqual(NativeLoginRegistrationDriver.map(.enabled), .enabled)
        XCTAssertEqual(NativeLoginRegistrationDriver.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(NativeLoginRegistrationDriver.map(.notFound), .notFound)
    }
}

@MainActor
final class J11WelcomeTests: XCTestCase {
    func testContinuePersistsPickerWithoutCompletingSetupOrChangingDefaults() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        OnboardingFlowView.continueWelcome(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .picker)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertEqual(preferences.displayMode, .delta)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .picker)
        preferences.onboarding.checkpoint = .helperOffer
        OnboardingFlowView.continueWelcome(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .helperOffer)
    }

    func testExactCopy() {
        XCTAssertEqual(WelcomeView.title, "Know your watts")
        XCTAssertEqual(WelcomeView.message, "Watt? sits in your menu bar and shows what your Mac draws and what it’s charging with. Nothing more.")
    }

    #if DEBUG
    func testFixtureWindowUsesNativeLightTitlelessChrome() {
        let window = J11FixtureLaunch.makeWindow()
        defer { window.close() }
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertNotNil(window.standardWindowButton(.closeButton))
        XCTAssertEqual(window.contentView?.bounds.width, 480)
        XCTAssertFalse(window.isVisible)
    }
    #endif
}

@MainActor
final class J12ReadingTests: XCTestCase {
    func testNavigationIgnoresEveryNonPickerCheckpoint() {
        for checkpoint in [OnboardingCheckpoint.welcome, .helperOffer, .approval, .preview, .allSet, .coachMark] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding.checkpoint = checkpoint
            ChooseMenuReadingView.back(preferences: preferences)
            XCTAssertEqual(preferences.onboarding.checkpoint, checkpoint)
            ChooseMenuReadingView.advance(preferences: preferences)
            XCTAssertEqual(preferences.onboarding.checkpoint, checkpoint)
        }
    }

    func testPickerFitsReferenceWindowWithoutCustomChrome() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(AppRouter())
            .environmentObject(preferences)
            .environmentObject(PowerReadingStore.preview))
        host.frame = NSRect(x: 0, y: 0, width: 480, height: 346)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, 480)
        XCTAssertLessThanOrEqual(host.fittingSize.height, 346)
        XCTAssertGreaterThan(host.fittingSize.height, 250)
    }

    func testFourEnabledOptionsAndExactFixtureCopy() {
        let options = ChooseMenuReadingView.options(reading: .sampleCharging)
        XCTAssertEqual(options.map(\.mode), [.delta, .charger, .draw, .components])
        XCTAssertEqual(options.map(\.description), [
            "How fast the battery fills or drains. +42.1 W",
            "What the charger is giving. 65 W",
            "What your Mac uses right now. 22.9 W",
            "CPU, GPU and the rest. Needs the helper — next step."
        ])
        XCTAssertEqual(ChooseMenuReadingView.title, "Pick one number for the menu bar")
        XCTAssertEqual(ChooseMenuReadingView.message, "Change it any time. Right-click Watt? or open Settings.")
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).displayMode, .delta)
    }

    func testSelectionAndNavigationPersistWithoutHelperApprovalOrCompletion() {
        for mode in [WattDisplayMode.delta, .charger, .draw, .components] {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding.checkpoint = .picker
            let picker = ReadingPicker(selection: Binding(
                get: { preferences.displayMode }, set: { preferences.displayMode = $0 }),
                options: ChooseMenuReadingView.options(reading: .sampleCharging))
            XCTAssertTrue(picker.unavailableModes.isEmpty)
            picker.availableSelection.wrappedValue = mode
            XCTAssertEqual(PreferencesStore(storage: storage).displayMode, mode)
            ChooseMenuReadingView.back(preferences: preferences)
            XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .welcome)
            OnboardingFlowView.continueWelcome(preferences: preferences)
            XCTAssertEqual(preferences.displayMode, mode)
            ChooseMenuReadingView.advance(preferences: preferences)
            let restored = PreferencesStore(storage: storage)
            XCTAssertEqual(restored.onboarding.checkpoint, .helperOffer)
            XCTAssertEqual(restored.displayMode, mode)
            XCTAssertFalse(restored.onboarding.completed)
            XCTAssertFalse(restored.onboarding.helperOptIn)
            ChooseMenuReadingView.back(preferences: preferences)
            ChooseMenuReadingView.advance(preferences: preferences)
            XCTAssertEqual(preferences.onboarding.checkpoint, .helperOffer)
        }
    }

    func testUnavailableTelemetryDoesNotInventValues() {
        let options = ChooseMenuReadingView.options(reading: .unavailable)
        for option in options.prefix(3) {
            XCTAssertTrue(option.description?.hasSuffix("—") == true)
        }
    }

    #if DEBUG
    func testNativeLightTitlelessFixtureAndIsolation() {
        let window = J12FixtureLaunch.makeWindow()
        defer { window.close() }
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertNotNil(window.standardWindowButton(.closeButton))
        XCTAssertEqual(window.contentView?.bounds.width, 480)
        XCTAssertEqual(window.contentView?.bounds.height, 346)
        XCTAssertFalse(window.isVisible)
    }
    #endif
}
