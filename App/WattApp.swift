import AppKit
import Combine
import SwiftUI

@main
struct WattApp: App {
    @NSApplicationDelegateAdaptor(WattApplicationDelegate.self) private var applicationDelegate
    @StateObject private var router: AppRouter
    @StateObject private var powerStore: PowerReadingStore
    @StateObject private var preferences: PreferencesStore

    private static var isHarnessLaunch: Bool {
        ProcessInfo.processInfo.arguments.dropFirst().contains { $0.hasPrefix("--watt-") }
    }

    init() {
        #if DEBUG
        if let rejection = WattFixtureLaunchGate.rejection(arguments: ProcessInfo.processInfo.arguments) {
            FileHandle.standardError.write(Data((rejection + "\n").utf8))
            // Exit before constructing stores or allowing SwiftUI to evaluate any scene.
            exit(EXIT_FAILURE)
        }
        #endif
        #if DEBUG && !SWIFT_PACKAGE
        // Controlled empty-state launch: exit before stores, scenes or status items exist.
        if J123FixtureLaunch.requested { exit(EXIT_SUCCESS) }
        #endif
        #if DEBUG && !SWIFT_PACKAGE
        if J125FixtureLaunch.requested || J124FixtureLaunch.requested || (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested) || J108FixtureLaunch.requested || J107FixtureLaunch.requested || J106FixtureLaunch.requested || J105FixtureLaunch.requested || J104FixtureLaunch.requested || J103FixtureLaunch.requested || J102FixtureLaunch.requested || J93FixtureLaunch.requested || J92FixtureLaunch.requested || J91FixtureLaunch.requested || J83FixtureLaunch.requested || J112FixtureLaunch.requested || J82FixtureLaunch.requested || J81FixtureLaunch.requested || J74FixtureLaunch.requested || J73FixtureLaunch.requested || J72FixtureLaunch.requested || J71FixtureLaunch.requested || J65FixtureLaunch.requested || J64FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J61FixtureLaunch.requested || J111FixtureLaunch.requested || J53FixtureLaunch.requested || J52FixtureLaunch.requested || J51FixtureLaunch.requested || J43FixtureLaunch.requested || J42FixtureLaunch.requested || J41FixtureLaunch.requested || J33FixtureLaunch.requested || J32FixtureLaunch.requested || J31FixtureLaunch.requested || J25FixtureLaunch.requested || J24FixtureLaunch.requested || J23FixtureLaunch.requested || J22FixtureLaunch.requested || J21FixtureLaunch.requested || J18FixtureLaunch.requested || J17FixtureLaunch.requested || J16FixtureLaunch.requested || J15FixtureLaunch.requested || J14FixtureLaunch.requested || J13FixtureLaunch.requested || J12FixtureLaunch.requested || J11FixtureLaunch.requested || C05FixtureLaunch.requested || C01FixtureLaunch.requested || C02FixtureLaunch.requested || C03FixtureLaunch.requested || C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
            let appRouter = AppRouter()
            appRouter.onUninstalled = { NSApplication.shared.terminate(nil) }
            _router = StateObject(wrappedValue: appRouter)
            _powerStore = StateObject(wrappedValue: (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested)
                ? J121FixtureLaunch.makeStore()
                : J108FixtureLaunch.requested
                ? J61FixtureLaunch.makeStore()
                : J93FixtureLaunch.requested
                ? J93FixtureLaunch.makeStore()
                : J125FixtureLaunch.requested
                ? J125FixtureLaunch.makeStore()
                : J92FixtureLaunch.requested
                ? J92FixtureLaunch.makeStore()
                : J91FixtureLaunch.requested
                ? J91FixtureLaunch.makeStore()
                : J83FixtureLaunch.requested
                ? J83FixtureLaunch.makeStore()
                : J82FixtureLaunch.requested
                ? J82FixtureLaunch.makeStore()
                : J81FixtureLaunch.requested
                ? J81FixtureLaunch.makeStore()
                : J74FixtureLaunch.requested
                ? J74FixtureLaunch.makeStore()
                : J73FixtureLaunch.requested
                ? J73FixtureLaunch.makeStore()
                : J72FixtureLaunch.requested
                ? J72FixtureLaunch.makeStore()
                : J71FixtureLaunch.requested
                ? J71FixtureLaunch.makeStore()
                : J65FixtureLaunch.requested
                ? J65FixtureLaunch.makeStore()
                : J64FixtureLaunch.requested
                ? J64FixtureLaunch.makeStore()
                : J63FixtureLaunch.requested
                ? J63FixtureLaunch.makeStore()
                : J62FixtureLaunch.requested
                ? J62FixtureLaunch.makeStore()
                : J61FixtureLaunch.requested
                ? J61FixtureLaunch.makeStore()
                : J112FixtureLaunch.requested
                ? J112FixtureLaunch.makeStore()
                : J111FixtureLaunch.requested
                ? J111FixtureLaunch.makeStore()
                : J43FixtureLaunch.requested
                ? J43FixtureLaunch.makeStore()
                : C049FixtureLaunch.requested
                ? C049FixtureLaunch.makeStore()
                : C048FixtureLaunch.requested
                ? C048FixtureLaunch.makeStore()
                : C047FixtureLaunch.requested
                ? C047FixtureLaunch.makeStore()
                : C046FixtureLaunch.requested
                ? C046FixtureLaunch.makeStore()
                : C045FixtureLaunch.requested
                ? C045FixtureLaunch.makeStore()
                : C044FixtureLaunch.requested
                ? C044FixtureLaunch.makeStore()
                : C043FixtureLaunch.requested
                ? C043FixtureLaunch.makeStore()
                : (C042FixtureLaunch.requested || C0412FixtureLaunch.requested)
                ? C042FixtureLaunch.makeStore()
                : C02FixtureLaunch.requested
                    ? PowerReadingStore(currentReading: .sampleOnBattery, clock: FakeWattClock(now: PowerReading.sampleOnBattery.timestamp))
                    : PowerReadingStore.preview)
            let fixturePreferences = (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested)
                ? J121FixtureLaunch.makePreferences()
                : J108FixtureLaunch.requested
                ? J61FixtureLaunch.makePreferences()
                : J93FixtureLaunch.requested
                ? J93FixtureLaunch.makePreferences()
                : J125FixtureLaunch.requested
                ? J125FixtureLaunch.makePreferences()
                : J92FixtureLaunch.requested
                ? J92FixtureLaunch.makePreferences()
                : J91FixtureLaunch.requested
                ? J91FixtureLaunch.makePreferences()
                : J83FixtureLaunch.requested
                ? J83FixtureLaunch.makePreferences()
                : J82FixtureLaunch.requested
                ? J82FixtureLaunch.makePreferences()
                : J81FixtureLaunch.requested
                ? J81FixtureLaunch.makePreferences()
                : J74FixtureLaunch.requested
                ? J74FixtureLaunch.makePreferences()
                : J73FixtureLaunch.requested
                ? J73FixtureLaunch.makePreferences()
                : J72FixtureLaunch.requested
                ? J72FixtureLaunch.makePreferences()
                : J71FixtureLaunch.requested
                ? J71FixtureLaunch.makePreferences()
                : J65FixtureLaunch.requested
                ? J65FixtureLaunch.makePreferences()
                : J64FixtureLaunch.requested
                ? J64FixtureLaunch.makePreferences(variant: J64FixtureLaunch.variant)
                : J63FixtureLaunch.requested
                ? J63FixtureLaunch.makePreferences()
                : J62FixtureLaunch.requested
                ? J62FixtureLaunch.makePreferences()
                : J61FixtureLaunch.requested
                ? J61FixtureLaunch.makePreferences()
                : J112FixtureLaunch.requested
                ? J112FixtureLaunch.makePreferences()
                : J111FixtureLaunch.requested
                ? J111FixtureLaunch.makePreferences()
                : PreferencesStore(storage: InMemoryStorage())
            if J65FixtureLaunch.requested || J64FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J111FixtureLaunch.requested || J61FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J61FixtureLaunch.appearanceName)
            }
            if J112FixtureLaunch.requested || J113FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J112FixtureLaunch.appearanceName)
            }
            if J82FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J82FixtureLaunch.appearanceName)
            }
            if J92FixtureLaunch.requested || J91FixtureLaunch.requested || J83FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J83FixtureLaunch.appearanceName)
            }
            if J81FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J81FixtureLaunch.appearanceName)
            }
            if J74FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J74FixtureLaunch.appearanceName)
            }
            if J73FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J73FixtureLaunch.appearanceName)
            }
            if J72FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J72FixtureLaunch.appearanceName)
            }
            if J71FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J71FixtureLaunch.appearanceName)
            }
            if J51FixtureLaunch.requested { J51FixtureLaunch.prepare(preferences: fixturePreferences) }
            if J52FixtureLaunch.requested { J52FixtureLaunch.prepare(preferences: fixturePreferences) }
            if J53FixtureLaunch.requested { J53FixtureLaunch.prepare(preferences: fixturePreferences) }
            if J32FixtureLaunch.requested || J21FixtureLaunch.requested || J22FixtureLaunch.requested {
                fixturePreferences.componentReadings = false
                fixturePreferences.onboarding = .init(checkpoint: .livePanel, completed: true)
            }
            if J43FixtureLaunch.requested {
                J43FixtureLaunch.prepare(preferences: fixturePreferences)
            }
            if J18FixtureLaunch.requested {
                fixturePreferences.onboarding = .init(checkpoint: .livePanel, completed: true)
            }
            if J17FixtureLaunch.requested {
                fixturePreferences.onboarding = .init(checkpoint: .coachMark, completed: true)
            }
            if C05FixtureLaunch.requested { fixturePreferences.onboarding.completed = true }
            if C03FixtureLaunch.requested || C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
                fixturePreferences.onboarding.completed = true
                fixturePreferences.displayMode = C048FixtureLaunch.requested ? .iconOnly : C047FixtureLaunch.requested ? .components : C046FixtureLaunch.requested ? .draw : (C044FixtureLaunch.requested || C045FixtureLaunch.requested) ? .charger : .delta
                fixturePreferences.showSymbol = !C047FixtureLaunch.requested
                C03FixtureLaunch.preferences = fixturePreferences
            }
            _preferences = StateObject(wrappedValue: fixturePreferences)
            return
        }
        #endif
        let appRouter = AppRouter()
        appRouter.onUninstalled = { NSApplication.shared.terminate(nil) }
        _router = StateObject(wrappedValue: appRouter)
        let appPowerStore = PowerReadingStore(currentReading: .unavailable,
            telemetry: SystemPowerSourceTelemetryService())
        let appPreferences = PreferencesStore(storage: UserDefaultsStorage(defaults: .standard))
        _powerStore = StateObject(wrappedValue: appPowerStore)
        _preferences = StateObject(wrappedValue: appPreferences)
        // MenuBarExtra is the preferred SwiftUI path, but it is not materialising
        // an item on some macOS hosts (including the local verification host). Keep
        // the user-facing app usable with the public AppKit status-item API while
        // retaining MenuBarExtra for all fixture launches.
        if !Self.isHarnessLaunch {
            applicationDelegate.installFallbackStatusItem(router: appRouter,
                                                          powerStore: appPowerStore,
                                                          preferences: appPreferences)
        }
    }

    private var menuBarExtraInserted: Binding<Bool> {
        #if DEBUG
        if J124FixtureLaunch.requested { return .constant(false) }
        if J42FixtureLaunch.requested || J41FixtureLaunch.requested || J33FixtureLaunch.requested || J31FixtureLaunch.requested || J25FixtureLaunch.requested || J24FixtureLaunch.requested || J23FixtureLaunch.requested || J17FixtureLaunch.requested || J16FixtureLaunch.requested || J15FixtureLaunch.requested || J14FixtureLaunch.requested || J13FixtureLaunch.requested || J12FixtureLaunch.requested || J11FixtureLaunch.requested || C05FixtureLaunch.requested { return .constant(false) }
        if C041FixtureLaunch.captureRequested || C042FixtureLaunch.captureRequested || C043FixtureLaunch.captureRequested || C044FixtureLaunch.captureRequested || C045FixtureLaunch.captureRequested || C046FixtureLaunch.captureRequested || C047FixtureLaunch.captureRequested || C048FixtureLaunch.captureRequested || C049FixtureLaunch.captureRequested || C0410FixtureLaunch.captureRequested || C0411FixtureLaunch.captureRequested || C0412FixtureLaunch.captureRequested { return .constant(false) }
        #endif
        // The normal launch uses the explicit AppKit status item fallback. SwiftUI
        // MenuBarExtra remains the production fixture path and is still exercised
        // by the visual/native evidence harnesses.
        return .constant(Self.isHarnessLaunch)
    }

    private var statusLabel: MenuBarStatusLabel {
        MenuBarStatusLabel(reading: powerStore.statusReading, preferences: preferences,
                           helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
    }

    private var settingsMenuBarExcerpt: Bool {
        #if DEBUG
        J73FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsRelaunchExcerpt: Bool {
        #if DEBUG
        J83FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsConfirmUninstallExcerpt: Bool {
        #if DEBUG
        J122FixtureLaunch.requested || J113FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsUninstallExcerpt: Bool {
        #if DEBUG
        (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested)
        #else
        false
        #endif
    }

    private var settingsRemovedExcerpt: Bool {
        #if DEBUG
        J92FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsRemovalExcerpt: Bool {
        #if DEBUG
        J91FixtureLaunch.requested || J125FixtureLaunch.requested
        #else
        false
        #endif
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarExtraInserted) {
            MenuBarRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
        } label: {
            statusLabel
                .task { await powerStore.runSampling() }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                    guard powerStore.observesSystemWake else { return }
                    powerStore.handleWake()
                    Task { await powerStore.refresh() }
                }
                .onReceive(powerStore.$currentReading) { reading in
                    router.settingsHelperSetup.confirmRecoveredComponents(reading)
                }
                .background {
                    ScenePresentationBridge(router: router, preferences: preferences, powerStore: powerStore,
                                            applicationDelegate: applicationDelegate)
                }
        }
        .menuBarExtraStyle(.window)

        Window("", id: "onboarding") {
            OnboardingFlowView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
                .frame(minWidth: WattSpacing.onboardingWidth, idealWidth: WattSpacing.onboardingWidth)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Window("Software Update", id: "software-update") {
            UpdateRootView(softwareUpdate: true)
                .environmentObject(router)
        }
        .windowResizability(.contentSize)

        Window("Watt? Update", id: "update") {
            UpdateRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
                .frame(minWidth: 360, idealWidth: 420, minHeight: 180)
        }

        Settings {
            SettingsRootView(menuBarExcerpt: settingsMenuBarExcerpt,
                             relaunchExcerpt: settingsRelaunchExcerpt, removalExcerpt: settingsRemovalExcerpt,
                             removedExcerpt: settingsRemovedExcerpt,
                             uninstallExcerpt: settingsUninstallExcerpt,
                             confirmUninstallExcerpt: settingsConfirmUninstallExcerpt)
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
        }
        .windowResizability(.contentSize)
    }
}

#if DEBUG
@MainActor
enum C01FixtureLaunch {
    static weak var router: AppRouter?
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C01"
        }
        return false
        #endif
    }
}

@MainActor
enum C02FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C02"
        }
        return false
        #endif
    }
}

@MainActor
enum C03FixtureLaunch {
    static weak var preferences: PreferencesStore?
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C03"
        }
        return false
        #endif
    }
}

@MainActor
enum C041FixtureLaunch {
    // Exact Figma frame and app-owned component geometry, in points.
    static let captureSize = NSSize(width: 560, height: 44)
    static let itemRect = NSRect(x: 205, y: 5, width: 96, height: 24)

    /// Explicit pixels and point size avoid inheriting the screen's Retina scale.
    static func captureBitmap1x() -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(captureSize.width),
            pixelsHigh: Int(captureSize.height), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        bitmap.size = captureSize
        return bitmap
    }

    static var captureRequested: Bool {
        requested && ProcessInfo.processInfo.arguments.contains("--watt-c041-capture-directory")
    }
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C04.1"
        }
        return false
        #endif
    }
}

@MainActor
enum C042FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 204, y: 5, width: 97, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleOnBattery,
                          clock: FakeWattClock(now: PowerReading.sampleOnBattery.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.2"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c042-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C043FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 220, y: 5, width: 81, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleChargedOnAdapter,
                          clock: FakeWattClock(now: PowerReading.sampleChargedOnAdapter.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.3"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c043-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C044FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 221, y: 5, width: 80, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleChargerInput,
                          clock: FakeWattClock(now: PowerReading.sampleChargerInput.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.4"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c044-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C045FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 213, y: 5, width: 88, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleUnpluggedCharger,
                          clock: FakeWattClock(now: PowerReading.sampleUnpluggedCharger.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.5"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c045-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C046FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 221, y: 5, width: 80, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleDesktopSystemDraw,
                          clock: FakeWattClock(now: PowerReading.sampleDesktopSystemDraw.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.6"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c046-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C047FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 153, y: 5, width: 148, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .samplePerComponent,
                          clock: FakeWattClock(now: PowerReading.samplePerComponent.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.7"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c047-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C048FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 260, y: 5, width: 41, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleCharging,
                          clock: FakeWattClock(now: PowerReading.sampleCharging.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.8"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c048-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C049FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 230, y: 5, width: 71, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .unavailable,
                          clock: FakeWattClock(now: PowerReading.unavailable.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.9"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c049-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C0410FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = C041FixtureLaunch.itemRect
    static func makeStore() -> PowerReadingStore { PowerReadingStore.preview }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.10"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c0410-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C0411FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = C041FixtureLaunch.itemRect
    static func makeStore() -> PowerReadingStore { PowerReadingStore.preview }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.11"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c0411-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C0412FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = C042FixtureLaunch.itemRect
    static func makeStore() -> PowerReadingStore { C042FixtureLaunch.makeStore() }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.12"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c0412-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

/// DEBUG capture counterpart of MenuBarExtra's system-owned selection lifecycle.
/// Public NSStatusBarButton highlighting only; never draws selected chrome.
@MainActor
final class C0410PanelSelection: NSObject, NSPopoverDelegate {
    let router: AppRouter
    let popover = NSPopover()
    private weak var button: NSStatusBarButton?

    init(button: NSStatusBarButton, router: AppRouter, preferences: PreferencesStore,
         store: PowerReadingStore) {
        self.button = button
        self.router = router
        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarRootView()
            .environmentObject(router).environmentObject(store).environmentObject(preferences))
        button.target = self
        button.action = #selector(togglePanel)
    }

    @objc func togglePanel() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        synchronizeSelection()
        // NSButton ends click tracking after dispatching its action and clears the
        // pressed highlight. Reapply native selection only if the panel stays open.
        DispatchQueue.main.async { [weak self] in self?.synchronizeSelection() }
    }

    func popoverDidClose(_ notification: Notification) { synchronizeSelection() }

    private func synchronizeSelection() {
        applySelection(isPresented: popover.isShown)
    }

    // Deterministic lifecycle seam; production capture supplies actual popover state.
    func applySelection(isPresented: Bool) {
        router.statusPanelPresented = isPresented
        button?.highlight(isPresented)
    }
}

/// Pure preflight: no store, application, window or service access.
enum WattFixtureLaunchGate {
    static func rejection(arguments: [String]) -> String? {
        #if SWIFT_PACKAGE
        // The package executable deliberately has no dependency on the fixture target.
        guard arguments.contains(where: { $0.hasPrefix("--watt-fixture") }) else { return nil }
        return "Watt fixture launch rejected: \(arguments.dropFirst().joined(separator: " ")). "
            + "Fixture selection requires the native Debug target; gallery smoke uses standalone GalleryHost."
        #else
        do {
            guard let selection = try FixtureLaunchSelection.parse(arguments) else { return nil }
            switch selection {
            case .story:
                _ = try selection.smokeLaunchArguments()
                return nil
            case .gallery(let gallery):
                return "Watt fixture launch rejected: \(gallery.rawValue) must use standalone GalleryHost, not WattApp."
            }
        } catch {
            return "Watt fixture launch rejected: \(arguments.dropFirst().joined(separator: " ")): \(error)"
        }
        #endif
    }
}

/// Opt-in rendering harness only; absent from Release and inert on ordinary launches.
@MainActor
final class NativeCaptureDelegate: NSObject, NSApplicationDelegate {
    static let launchArgument = "--watt-capture-status-panel"
    static let windowTitle = "Watt F01 StatusPanel Capture"
    private var captureWindow: NSWindow?
    private var chargingStatusItem: NSStatusItem?
    private var chargingCaptureAnchor: StatusAnchorView?

    static func captureRequested(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func makeWindow(c01: Bool = false, c02: Bool = false) -> NSWindow {
        let panel = StatusPanelView(
            reading: c02 ? .sampleOnBattery : .sampleCharging,
            chargerDescription: c01 ? "96 W USB-C charger" : nil,
            onSettings: { C01FixtureLaunch.router?.showSettings() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.colorScheme, c01 ? .dark : .light)
        .frame(width: WattSpacing.panelWidth, height: c01 || c02 ? WattSpacing.panelHeight : nil)
        let hostingView = NSHostingView(rootView: panel)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.title = c02 ? "Watt C02 StatusPanel Capture" : c01 ? "Watt C01 StatusPanel Capture" : windowTitle
        window.appearance = NSAppearance(named: c01 ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        return window
    }

    static func makeGalleryWindow(colorScheme: ColorScheme, specimen: WattReferenceSpecimen.Kind? = nil) -> NSWindow {
        let content = specimen.map { AnyView(WattReferenceSpecimen(kind: $0, colorScheme: colorScheme)) }
            ?? AnyView(WattComponentGallery(colorScheme: colorScheme))
        let host = NSHostingView(rootView: content)
        let window = GalleryCaptureWindow(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.title = "Watt F02 Gallery " + (specimen.map { $0.rawValue + "-" } ?? "") + (colorScheme == .dark ? "dark" : "light")
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if J124FixtureLaunch.requested { J124FixtureLaunch.launch(); return }
        if J108FixtureLaunch.requested {
            captureWindow = J108FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J107FixtureLaunch.requested {
            captureWindow = J107FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J106FixtureLaunch.requested {
            captureWindow = J106FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J105FixtureLaunch.requested {
            captureWindow = J105FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J104FixtureLaunch.requested {
            captureWindow = J104FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J103FixtureLaunch.requested {
            captureWindow = J103FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if J102FixtureLaunch.requested {
            captureWindow = J102FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let arguments = ProcessInfo.processInfo.arguments
        if J17FixtureLaunch.requested {
            J17FixtureLaunch.launch()
            return
        }
        if J16FixtureLaunch.requested {
            captureWindow = J16FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let window = captureWindow { J16FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J15FixtureLaunch.requested {
            captureWindow = J15FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let window = captureWindow { J15FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J14FixtureLaunch.requested {
            captureWindow = J14FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J14FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J13FixtureLaunch.requested {
            captureWindow = J13FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J13FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J12FixtureLaunch.requested {
            captureWindow = J12FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J12FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J42FixtureLaunch.requested {
            captureWindow = J42FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J41FixtureLaunch.requested {
            captureWindow = J41FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J11FixtureLaunch.requested {
            captureWindow = J11FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J11FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J33FixtureLaunch.requested || J31FixtureLaunch.requested {
            captureWindow = J33FixtureLaunch.requested ? J33FixtureLaunch.makeWindow() : J31FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J25FixtureLaunch.requested {
            J25FixtureLaunch.launch()
            return
        }
        if J24FixtureLaunch.requested {
            captureWindow = J24FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J23FixtureLaunch.requested {
            captureWindow = J23FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if C05FixtureLaunch.requested {
            captureWindow = C05FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { C05FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if C041FixtureLaunch.captureRequested || C042FixtureLaunch.captureRequested || C043FixtureLaunch.captureRequested || C044FixtureLaunch.captureRequested || C045FixtureLaunch.captureRequested || C046FixtureLaunch.captureRequested || C047FixtureLaunch.captureRequested || C048FixtureLaunch.captureRequested || C049FixtureLaunch.captureRequested || C0410FixtureLaunch.captureRequested || C0411FixtureLaunch.captureRequested || C0412FixtureLaunch.captureRequested {
            // MenuBarExtra is suppressed only for this opt-in harness. This is a
            // real app-owned NSStatusItem with the production SwiftUI label.
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.displayMode = C048FixtureLaunch.requested ? .iconOnly : C047FixtureLaunch.requested ? .components : C046FixtureLaunch.requested ? .draw : (C044FixtureLaunch.requested || C045FixtureLaunch.requested) ? .charger : .delta
            preferences.showSymbol = !C047FixtureLaunch.requested
            preferences.onboarding.completed = true
            let store = C049FixtureLaunch.requested ? C049FixtureLaunch.makeStore() : C048FixtureLaunch.requested ? C048FixtureLaunch.makeStore() : C047FixtureLaunch.requested ? C047FixtureLaunch.makeStore() : C046FixtureLaunch.requested ? C046FixtureLaunch.makeStore() : C045FixtureLaunch.requested ? C045FixtureLaunch.makeStore() : C044FixtureLaunch.requested ? C044FixtureLaunch.makeStore() : C043FixtureLaunch.requested ? C043FixtureLaunch.makeStore() : (C042FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C042FixtureLaunch.makeStore() : PowerReadingStore.preview
            let width = C049FixtureLaunch.requested ? C049FixtureLaunch.itemRect.width : C048FixtureLaunch.requested ? C048FixtureLaunch.itemRect.width : C047FixtureLaunch.requested ? C047FixtureLaunch.itemRect.width : C046FixtureLaunch.requested ? C046FixtureLaunch.itemRect.width : C045FixtureLaunch.requested ? C045FixtureLaunch.itemRect.width : C044FixtureLaunch.requested ? C044FixtureLaunch.itemRect.width : C043FixtureLaunch.requested ? C043FixtureLaunch.itemRect.width : (C042FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C042FixtureLaunch.itemRect.width : C041FixtureLaunch.itemRect.width
            let item = NSStatusBar.system.statusItem(withLength: width)
            chargingStatusItem = item
            guard let button = item.button else { return }
            button.appearance = NSAppearance(named: (C0411FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C0411FixtureLaunch.appearanceName : .darkAqua)
            let label = NSHostingView(rootView:
                MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
                    .environment(\.colorScheme, (C0411FixtureLaunch.requested || C0412FixtureLaunch.requested) ? .light : .dark)
                    .frame(width: width, height: 24))
            label.frame = NSRect(x: 0, y: 0, width: width, height: 24)
            label.autoresizingMask = [.width, .height]
            button.addSubview(label)
            let anchor = StatusAnchorView()
            chargingCaptureAnchor = anchor
            anchor.captureChargingStatusItem(button: button)
            return
        }
        if C03FixtureLaunch.requested, arguments.contains("--watt-c03-capture-directory"),
           let preferences = C03FixtureLaunch.preferences {
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            let anchor = StatusAnchorView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            let router = AppRouter()
            anchor.makeMenu = { StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true }) }
            anchor.install = { [weak anchor] in anchor?.openContextMenuFixture() }
            let window = NSWindow(contentRect: anchor.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = "C03 native menu capture anchor (not status-item evidence)"
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = anchor
            if let screen = NSScreen.main {
                window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 110,
                                              y: screen.visibleFrame.maxY - 100))
            }
            captureWindow = window
            window.orderFrontRegardless()
            return
        }
        let dark = arguments.contains("--watt-capture-gallery-dark")
        let light = arguments.contains("--watt-capture-gallery-light")
        guard Self.captureRequested(arguments: arguments) || dark || light || C01FixtureLaunch.requested || C02FixtureLaunch.requested else { return }
        let specimen = WattReferenceSpecimen.Kind.allCases.first { arguments.contains("--watt-specimen-" + $0.rawValue) }
        let window = dark || light ? Self.makeGalleryWindow(colorScheme: dark ? .dark : .light, specimen: specimen) : Self.makeWindow(c01: C01FixtureLaunch.requested, c02: C02FixtureLaunch.requested)
        if dark || light {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        captureWindow = window
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        if dark || light {
            DispatchQueue.main.async {
                window.makeKeyAndOrderFront(nil)
                @MainActor
                func focusField(in view: NSView) -> Bool {
                    if let field = view as? NSTextField, field.isEditable {
                        return window.makeFirstResponder(field)
                    }
                    return view.subviews.contains { focusField(in: $0) }
                }
                if let content = window.contentView { _ = focusField(in: content) }
            }
        }
    }
}
private final class GalleryCaptureWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
#endif

@MainActor
final class WattApplicationDelegate: NSObject, NSApplicationDelegate {
    var onReopen: (() -> Void)?
    var onTerminate: (() -> Void)?
    private(set) var isTerminating = false
    private var fallbackStatusItem: WattFallbackStatusItem?

    @MainActor
    func installFallbackStatusItem(router: AppRouter, powerStore: PowerReadingStore,
                                   preferences: PreferencesStore) {
        guard fallbackStatusItem == nil else { return }
        fallbackStatusItem = WattFallbackStatusItem(router: router, powerStore: powerStore,
                                                    preferences: preferences)
        fallbackStatusItem?.install()
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !isTerminating else { return }
        isTerminating = true
        onReopen = nil
        let cleanup = onTerminate
        onTerminate = nil
        cleanup?()
        fallbackStatusItem?.uninstall()
        fallbackStatusItem = nil
        // SwiftUI owns the MenuBarExtra/NSStatusItem. Process termination removes it;
        // do not remove a borrowed status item behind SwiftUI's back.
        NSApplication.shared.windows.forEach { $0.orderOut(nil) }
    }
    #if DEBUG
    private let capture = NativeCaptureDelegate()
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        capture.applicationDidFinishLaunching(notification)
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isTerminating else { return false }
        onReopen?()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Public AppKit fallback for hosts where SwiftUI's MenuBarExtra scene does not
/// register a visible status item. It deliberately uses the native status button
/// and NSPopover; no custom menu-bar chrome or pixel drawing is introduced.
@MainActor
private final class WattFallbackStatusItem: NSObject {
    private let router: AppRouter
    private let powerStore: PowerReadingStore
    private let preferences: PreferencesStore
    private var item: NSStatusItem?
    private var panel: NSPopover?
    private var fallbackWindow: NSWindow?
    private var contextMenuMonitor: Any?
    private var observations = Set<AnyCancellable>()

    init(router: AppRouter, powerStore: PowerReadingStore, preferences: PreferencesStore) {
        self.router = router
        self.powerStore = powerStore
        self.preferences = preferences
        super.init()
    }

    func install() {
        guard item == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item = statusItem
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp])
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        updateButton()

        contextMenuMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, let button = self.item?.button,
                  event.window === button.window,
                  button.frame.contains(event.locationInWindow) else { return event }
            let menu = StatusItemContextMenu.makeMenu(router: self.router,
                preferences: self.preferences,
                componentsAvailable: {
                    !self.router.settingsHelperSetup.helperSwitchedOff
                        && self.powerStore.currentReading.source != .unavailable
                        && self.powerStore.currentReading.freshness == .fresh
                        && self.powerStore.currentReading.capabilities.components == .available
                })
            NSMenu.popUpContextMenu(menu, with: event, for: button)
            return nil
        }

        router.present = { [weak self] destination in
            switch destination {
            case .statusPanel: self?.togglePanel()
            case .coachMark: self?.togglePanel()
            case .settings:
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            case .onboarding, .softwareUpdate, .update:
                // These routes are still owned by the SwiftUI scenes when they are
                // available; the fallback keeps the primary status panel usable.
                break
            }
        }

        powerStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &observations)
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &observations)

        // Give a double-click/open launch a visible native surface even on hosts
        // whose menu-bar compositor hides third-party status items.
        DispatchQueue.main.async { [weak self] in self?.showFallbackWindow() }
    }

    func uninstall() {
        observations.removeAll()
        if let contextMenuMonitor { NSEvent.removeMonitor(contextMenuMonitor) }
        contextMenuMonitor = nil
        panel?.close()
        panel = nil
        fallbackWindow?.close()
        fallbackWindow = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func togglePanel() {
        guard let button = item?.button else { return }
        if let panel, panel.isShown {
            panel.performClose(nil)
            router.statusPanelPresented = false
            return
        }
        let popover = panel ?? NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView:
            MenuBarRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences))
        panel = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        router.statusPanelPresented = true
    }

    private func updateButton() {
        guard let button = item?.button else { return }
        let label = MenuBarStatusLabel(reading: powerStore.statusReading,
                                       preferences: preferences,
                                       helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
        button.image = NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil)
        button.imagePosition = label.showsSymbol ? (label.text == nil ? .imageOnly : .imageLeading) : .noImage
        button.title = label.text ?? ""
        button.toolTip = label.accessibilityAnnouncement
        MenuBarStatusAccessibility.apply(to: button, label: label)
        button.sizeToFit()
        item?.length = max(42, button.intrinsicContentSize.width + 12)
    }

    private func showFallbackWindow() {
        guard fallbackWindow == nil else { return }
        let content = NSHostingView(rootView:
            MenuBarRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Watt?"
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        fallbackWindow = window
    }
}

private struct ScenePresentationBridge: View {
    let router: AppRouter
    let preferences: PreferencesStore
    let powerStore: PowerReadingStore
    let applicationDelegate: WattApplicationDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if #available(macOS 14, *) {
            ModernScenePresentationBridge(router: router, preferences: preferences, powerStore: powerStore,
                                          applicationDelegate: applicationDelegate)
        } else {
            StatusItemAdapter(router: router, preferences: preferences, powerStore: powerStore,
                              applicationDelegate: applicationDelegate, openWindow: openWindow) {
                NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}

@available(macOS 14, *)
private struct ModernScenePresentationBridge: View {
    let router: AppRouter
    let preferences: PreferencesStore
    let powerStore: PowerReadingStore
    let applicationDelegate: WattApplicationDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        StatusItemAdapter(router: router, preferences: preferences, powerStore: powerStore,
                          applicationDelegate: applicationDelegate, openWindow: openWindow) {
            openSettings()
        }
    }
}

/// Uses the existing MenuBarExtra's button; never allocates another NSStatusItem.
private struct StatusItemAdapter: NSViewRepresentable {
    let router: AppRouter
    let preferences: PreferencesStore
    let powerStore: PowerReadingStore
    let applicationDelegate: WattApplicationDelegate
    let openWindow: OpenWindowAction
    let openSettings: () -> Void

    func makeNSView(context: Context) -> StatusAnchorView {
        let view = StatusAnchorView()
        view.updateAccessibility = { [weak view] in
            view?.updateAccessibility(reading: powerStore.statusReading, preferences: preferences,
                                      helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
        }
        view.install = { [weak view] in
            guard let view, !applicationDelegate.isTerminating else { return }
            router.present = { [weak view] destination in
                switch destination {
                case .coachMark:
                    view?.showCoachMark(preferences: preferences, router: router)
                case .statusPanel:
                    view?.closeCoachMark()
                    if !router.statusPanelPresented { view?.openPanel() }
                case .onboarding:
                    view?.closeCoachMark()
                    openWindow(id: "onboarding")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .settings:
                    openSettings()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .softwareUpdate:
                    openWindow(id: "software-update")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .update:
                    openWindow(id: "update")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            applicationDelegate.onTerminate = { [weak view] in
                router.leftoverHelper?.close()
                router.present = { _ in }
                router.statusPanelPresented = false
                view?.tearDown()
            }
            applicationDelegate.onReopen = {
                router.reopen(preferences: preferences)
            }
            view.makeMenu = { StatusItemContextMenu.makeMenu(router: router, preferences: preferences,
                componentsAvailable: { !router.settingsHelperSetup.helperSwitchedOff && powerStore.currentReading.source != .unavailable
                    && powerStore.currentReading.freshness == .fresh
                    && powerStore.currentReading.capabilities.components == .available }) }
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if J93FixtureLaunch.requested {
                J93FixtureLaunch.observeAndQuit(menu: view.makeMenu?(), button: view.statusButton)
                return
            }
            if J51FixtureLaunch.requested {
                router.showCoachMark()
                return
            }
            if J82FixtureLaunch.requested {
                Task {
                    await J82FixtureLaunch.prepare(router: router, store: powerStore)
                    view.observeJ82StatusFixture(reading: powerStore.statusReading,
                                                 preferences: preferences, router: router)
                }
                return
            }
            if J125FixtureLaunch.requested {
                Task {
                    await J125FixtureLaunch.prepare(router: router, preferences: preferences)
                    J125FixtureLaunch.observe(preferences: preferences)
                    router.present(.settings)
                }
                return
            }
            if J92FixtureLaunch.requested {
                Task {
                    await J92FixtureLaunch.prepare(router: router, preferences: preferences)
                    J92FixtureLaunch.observe(preferences: preferences)
                    router.launch(preferences: preferences)
                }
                return
            }
            if (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested) {
                // No installed removal effects, even if confirmation is exercised in a fixture.
                router.removeFromSettings = { _ in .cancelled }
                if J113FixtureLaunch.requested {
                    J113FixtureLaunch.observe(preferences: preferences, button: view.statusButton)
                } else if J122FixtureLaunch.requested {
                    J122FixtureLaunch.observe(preferences: preferences, button: view.statusButton)
                } else {
                    J121FixtureLaunch.observe(preferences: preferences, button: view.statusButton)
                }
                router.launch(preferences: preferences)
                return
            }
            if J91FixtureLaunch.requested {
                Task {
                    await J91FixtureLaunch.prepare(router: router)
                    J91FixtureLaunch.observe(preferences: preferences)
                    router.launch(preferences: preferences)
                }
                return
            }
            if J83FixtureLaunch.requested {
                J83FixtureLaunch.observe(preferences: preferences)
                router.launch(preferences: preferences)
                return
            }
            if J112FixtureLaunch.requested {
                Task {
                    await J112FixtureLaunch.prepare(router: router)
                    J112FixtureLaunch.observe(preferences: preferences)
                    router.launch(preferences: preferences)
                }
                return
            }
            if J81FixtureLaunch.requested {
                Task {
                    await J81FixtureLaunch.prepare(router: router)
                    router.showStatusPanel()
                    view.observeJ81StatusFixture(router: router)
                }
                return
            }
            if J73FixtureLaunch.requested {
                Task {
                    await J73FixtureLaunch.prepare(router: router)
                    router.showSettings()
                    J73FixtureLaunch.openComponentsMenu()
                }
                return
            }
            if J74FixtureLaunch.requested {
                Task {
                    await J74FixtureLaunch.prepare(router: router)
                    view.observeJ74StatusFixture(reading: powerStore.statusReading, preferences: preferences)
                }
                return
            }
            if J72FixtureLaunch.requested {
                view.observeJ72StatusFixture(reading: powerStore.statusReading, preferences: preferences)
                return
            }
            if J71FixtureLaunch.requested {
                Task {
                    await J71FixtureLaunch.prepare(router: router)
                    view.openJ71ContextMenuFixture()
                }
                return
            }
            if J53FixtureLaunch.requested || J21FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
                view.openContextMenuFixture()
                return
            }
            if J32FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                Task {
                    let helper = HelperLifecycleAdapter(driver: J25FixtureDriver(),
                        transport: J25FixtureTransport(), expectedPeer: J25FixtureTransport.identity)
                    router.settingsHelperSetup.service = helper
                    await router.settingsHelperSetup.turnOn(preferences: preferences)
                    helper.disconnect()
                    router.showStatusPanel()
                }
                return
            }
            if J111FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J111FixtureLaunch.appearanceName)
                router.showStatusPanel()
                return
            }
            if J65FixtureLaunch.requested || J64FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J61FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J61FixtureLaunch.appearanceName)
                if J64FixtureLaunch.requested {
                    Task {
                        _ = await J64FixtureLaunch.exerciseNotification(variant: J64FixtureLaunch.variant,
                            preferences: preferences, store: powerStore, router: router)
                        if arguments.contains("--watt-j64-probe-notification-authorization") {
                            let permission = await NativeNotificationDriver(center: .current()).permission()
                            FileHandle.standardOutput.write(Data("J6.4 live system authorization (read only): \(permission); no permission request or OS delivery attempted\n".utf8))
                        }
                    }
                }
                router.showStatusPanel()
                return
            }
            if J43FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                router.showStatusPanel()
                return
            }
            if J52FixtureLaunch.requested || J18FixtureLaunch.requested || J22FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
                router.showStatusPanel()
                return
            }
            if J17FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
                router.showCoachMark()
                return
            }
            if J42FixtureLaunch.requested || J41FixtureLaunch.requested || J16FixtureLaunch.requested || J15FixtureLaunch.requested || J14FixtureLaunch.requested || J13FixtureLaunch.requested || J12FixtureLaunch.requested || J11FixtureLaunch.requested || C05FixtureLaunch.requested || C01FixtureLaunch.requested || C02FixtureLaunch.requested || C03FixtureLaunch.requested || C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
                C01FixtureLaunch.router = router
                if C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
                    NSApplication.shared.appearance = NSAppearance(named: (C0411FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C0411FixtureLaunch.appearanceName : .darkAqua)
                    view.captureChargingStatusItem()
                    if C0410FixtureLaunch.requested { router.showStatusPanel() }
                }
                if C03FixtureLaunch.requested && !arguments.contains("--watt-c03-capture-directory") {
                    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                    view.openContextMenuFixture()
                }
                return
            }
            if arguments.contains(where: { $0.hasPrefix("--watt-capture-") }) { return }
            #endif
            view.updateAccessibility?()
            Task {
                await router.presentLeftoverHelperAfterReinstall()
                router.launch(preferences: preferences)
            }
        }
        return view
    }

    func updateNSView(_ nsView: StatusAnchorView, context: Context) {
        nsView.updateAccessibility(reading: powerStore.statusReading, preferences: preferences,
                                   helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
    }

    static func dismantleNSView(_ nsView: StatusAnchorView, coordinator: ()) {
        nsView.tearDown()
    }
}

final class StatusAnchorView: NSView {
    var install: (() -> Void)?
    var updateAccessibility: (() -> Void)?
    var makeMenu: (() -> NSMenu)?
    private var monitor: Any?
    private var coachMark: NSPopover?
    private var accessibilityAnnouncementGate = MenuBarAccessibilityAnnouncementGate()

    func updateAccessibility(reading: PowerReading, preferences: PreferencesStore, helperSwitchedOff: Bool) {
        guard let button = statusButton else { return }
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences,
                                       helperSwitchedOff: helperSwitchedOff)
        guard accessibilityAnnouncementGate.shouldAnnounce(stateKey: label.accessibilityStateKey, now: Date()) else { return }
        MenuBarStatusAccessibility.apply(to: button, label: label)
    }

    func showCoachMark(preferences: PreferencesStore, router: AppRouter) {
        guard CoachMarkView.canPresent(preferences.onboarding),
              coachMark?.isShown != true, let button = statusButton else { return }
        let popover = CoachMarkView.makePopover(preferences: preferences, router: router)
        coachMark = popover
        // AppKit owns arrow placement and screen-edge constraints; anchor to the real item.
        let anchor = NSRect(x: button.bounds.maxX - 1, y: button.bounds.minY, width: 1, height: button.bounds.height)
        popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
        #if DEBUG
        if J17FixtureLaunch.requested { J17FixtureLaunch.capture(popover: popover, button: button) }
        #endif
    }

    func closeCoachMark() { coachMark?.close(); coachMark = nil }

    func tearDown() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        closeCoachMark()
        install = nil
        makeMenu = nil
    }


    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
                guard let self, event.window === self.window,
                      event.type == .rightMouseDown || event.modifierFlags.contains(.control),
                      let menu = self.makeMenu?() else { return event }
                let button = self.statusButton
                button?.highlight(true)
                defer {
                    StatusItemContextMenu.endPresentation(menu)
                    button?.highlight(false)
                }
                #if DEBUG
                if J71FixtureLaunch.requested, let button {
                    J71FixtureLaunch.observeTracking(menu: menu, button: button)
                }
                #endif
                NSMenu.popUpContextMenu(menu, with: event, for: self)
                return nil
            }
        }
        // Wait until SwiftUI has installed the status button and scene actions.
        DispatchQueue.main.async { [weak self] in
            self?.install?()
            self?.updateAccessibility?()
        }
    }

    #if DEBUG
    private var chargingCaptureStarted = false
    private var chargingCaptureWindow: NSWindow?
    private var selectedPanel: C0410PanelSelection?

    /// Captures a real app-owned NSStatusBarButton containing the production label.
    /// The fixture temporarily relocates it into a deterministic, app-owned 560x44 host.
    func captureChargingStatusItem(button suppliedButton: NSStatusBarButton? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let lightOnBattery = C0412FixtureLaunch.requested
        let light = C0411FixtureLaunch.requested || lightOnBattery
        let selected = C0410FixtureLaunch.requested
        let unavailable = C049FixtureLaunch.requested
        let iconOnly = C048FixtureLaunch.requested
        let components = C047FixtureLaunch.requested
        let desktop = C046FixtureLaunch.requested
        let unplugged = C045FixtureLaunch.requested
        let charger = C044FixtureLaunch.requested
        let charged = C043FixtureLaunch.requested
        let onBattery = C042FixtureLaunch.requested || lightOnBattery
        let story = lightOnBattery ? "C04.12" : light ? "C04.11" : selected ? "C04.10" : unavailable ? "C04.9" : iconOnly ? "C04.8" : components ? "C04.7" : desktop ? "C04.6" : unplugged ? "C04.5" : charger ? "C04.4" : charged ? "C04.3" : onBattery ? "C04.2" : "C04.1"
        let captureFlag = lightOnBattery ? "--watt-c0412-capture-directory" : light ? "--watt-c0411-capture-directory" : selected ? "--watt-c0410-capture-directory" : unavailable ? "--watt-c049-capture-directory" : iconOnly ? "--watt-c048-capture-directory" : components ? "--watt-c047-capture-directory" : desktop ? "--watt-c046-capture-directory" : unplugged ? "--watt-c045-capture-directory" : charger ? "--watt-c044-capture-directory" : charged ? "--watt-c043-capture-directory" : onBattery ? "--watt-c042-capture-directory" : "--watt-c041-capture-directory"
        let itemRect = unavailable ? C049FixtureLaunch.itemRect : iconOnly ? C048FixtureLaunch.itemRect : components ? C047FixtureLaunch.itemRect : desktop ? C046FixtureLaunch.itemRect : unplugged ? C045FixtureLaunch.itemRect : charger ? C044FixtureLaunch.itemRect : charged ? C043FixtureLaunch.itemRect : onBattery ? C042FixtureLaunch.itemRect : C041FixtureLaunch.itemRect
        guard (C041FixtureLaunch.captureRequested || C042FixtureLaunch.captureRequested || C043FixtureLaunch.captureRequested || C044FixtureLaunch.captureRequested || C045FixtureLaunch.captureRequested || C046FixtureLaunch.captureRequested || C047FixtureLaunch.captureRequested || C048FixtureLaunch.captureRequested || C049FixtureLaunch.captureRequested || C0410FixtureLaunch.captureRequested || C0411FixtureLaunch.captureRequested || C0412FixtureLaunch.captureRequested), !chargingCaptureStarted,
              let index = arguments.firstIndex(of: captureFlag),
              arguments.indices.contains(index + 1) else { return }
        chargingCaptureStarted = true
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            do {
                guard let button = suppliedButton ?? self.statusButton else {
                    throw NSError(domain: "\(story) missing native status button", code: 1)
                }
                let originalFrame = button.frame
                let host: NSView
                if light {
                    let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: C041FixtureLaunch.captureSize))
                    material.material = .menu
                    material.blendingMode = .withinWindow
                    material.state = .active
                    host = material
                } else {
                    host = NSView(frame: NSRect(origin: .zero, size: C041FixtureLaunch.captureSize))
                }
                if !light {
                    host.wantsLayer = true
                    host.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
                }
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                                      backing: .buffered, defer: false)
                window.title = "\(story) actual status button — bounded capture"
                window.appearance = NSAppearance(named: light ? C0411FixtureLaunch.appearanceName : .darkAqua)
                window.isReleasedWhenClosed = false
                window.contentView = host
                self.chargingCaptureWindow = window
                button.removeFromSuperview()
                host.addSubview(button)
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: itemRect.minX),
                    button.topAnchor.constraint(equalTo: host.topAnchor, constant: itemRect.minY),
                    button.widthAnchor.constraint(equalToConstant: itemRect.width),
                    button.heightAnchor.constraint(equalToConstant: itemRect.height)
                ])
                window.orderFrontRegardless()
                if selected {
                    host.layoutSubtreeIfNeeded()
                    let preferences = PreferencesStore(storage: InMemoryStorage())
                    preferences.onboarding.completed = true
                    self.selectedPanel = C0410PanelSelection(button: button, router: AppRouter(),
                        preferences: preferences, store: C0410FixtureLaunch.makeStore())
                    button.performClick(nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    do {
                        host.layoutSubtreeIfNeeded()
                        window.displayIfNeeded()
                        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                            throw NSError(domain: "\(story) bitmap unavailable", code: 2)
                        }
                        host.cacheDisplay(in: host.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else {
                            throw NSError(domain: "\(story) PNG unavailable", code: 3)
                        }
                        try png.write(to: output.appendingPathComponent("actual-status-item.png"))
                        guard let bitmap1x = C041FixtureLaunch.captureBitmap1x(),
                              let context1x = NSGraphicsContext(bitmapImageRep: bitmap1x) else {
                            throw NSError(domain: "\(story) 1x context unavailable", code: 4)
                        }
                        // Public AppKit subtree drawing into a 1 pixel/point context.
                        // Do not resize the screen-scale cache or redraw label content ourselves.
                        host.displayIgnoringOpacity(host.bounds, in: context1x)
                        guard let png1x = bitmap1x.representation(using: .png, properties: [:]) else {
                            throw NSError(domain: "\(story) 1x PNG unavailable", code: 5)
                        }
                        try png1x.write(to: output.appendingPathComponent("actual-status-item-1x.png"))
                        var record: [String: Any] = [
                            "fixture": story + "/base", "node": lightOnBattery ? "24:1960" : light ? "24:1711" : selected ? "24:1591" : unavailable ? "24:1472" : iconOnly ? "24:1353" : components ? "24:1234" : desktop ? "24:1115" : unplugged ? "24:996" : charger ? "24:877" : charged ? "24:758" : onBattery ? "24:639" : "24:390",
                            "component": lightOnBattery ? "24:2076" : light ? "24:1957" : selected ? "24:1707" : unavailable ? "24:1588" : iconOnly ? "24:1469" : components ? "24:1350" : desktop ? "24:1231" : unplugged ? "24:1112" : charger ? "24:993" : charged ? "24:874" : onBattery ? "24:755" : "24:636", "anchor": lightOnBattery ? "24:2078" : light ? "24:1959" : selected ? "24:1710" : unavailable ? "24:1590" : iconOnly ? "24:1471" : components ? "24:1352" : desktop ? "24:1233" : unplugged ? "24:1114" : charger ? "24:995" : charged ? "24:876" : onBattery ? "24:757" : "24:638",
                            "captureAPI": "NSView.cacheDisplay (screen-scale diagnostic); NSView.displayIgnoringOpacity(_:in:) (direct 1x)",
                            "bitmap1xPixels": [bitmap1x.pixelsWide, bitmap1x.pixelsHigh],
                            "bitmap1xPoints": [bitmap1x.size.width, bitmap1x.size.height],
                            "resampled": false,
                            "nativeItemHost": "DEBUG NSStatusItem; MenuBarExtra suppressed", "actualButtonClass": String(describing: type(of: button)),
                            "originalButtonFrame": NSStringFromRect(originalFrame),
                            "harnessPoints": [Int(C041FixtureLaunch.captureSize.width), Int(C041FixtureLaunch.captureSize.height)], "bitmapPixels": [bitmap.pixelsWide, bitmap.pixelsHigh],
                            "buttonFrame": NSStringFromRect(button.frame),
                            "appearance": button.effectiveAppearance.name.rawValue,
                            "selected": button.isHighlighted,
                            "customBackdrop": !light,
                            "limitations": light ? "Relocated native button; public Aqua appearance, no custom paint; no desktop/compositor pixels; not a visual pass." : "Relocated actual native button; synthetic dark backdrop; no compositor/desktop pixels; not a visual pass."
                        ]
                        if selected, let panel = self.selectedPanel {
                            record["panelShown"] = panel.popover.isShown
                            record["selectedWhileOpen"] = button.isHighlighted
                            record["routerPresentedWhileOpen"] = panel.router.statusPanelPresented
                            button.performClick(nil)
                            record["panelClosed"] = !panel.popover.isShown
                            record["unselectedAfterClose"] = !button.isHighlighted
                            record["routerDismissedAfterClose"] = !panel.router.statusPanelPresented
                            host.displayIgnoringOpacity(host.bounds, in: context1x)
                            try bitmap1x.representation(using: .png, properties: [:])?
                                .write(to: output.appendingPathComponent("closed-status-item-1x.png"))
                        }
                        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                            .write(to: output.appendingPathComponent("capture.json"))
                    } catch {
                        FileHandle.standardError.write(Data(("\(story) capture failed: \(error)\n").utf8))
                    }
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                FileHandle.standardError.write(Data(("\(story) capture failed: \(error)\n").utf8))
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Observe the actual native anchor in place; no menu/panel or replacement window.
    func observeJ72StatusFixture(reading: PowerReading, preferences: PreferencesStore) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusButton else { return }
            J72FixtureLaunch.observe(button: button, reading: reading, preferences: preferences)
        }
    }

    func observeJ81StatusFixture(router: AppRouter) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let button = self?.statusButton else { return }
            J81FixtureLaunch.observe(button: button, router: router)
        }
    }

    func observeJ82StatusFixture(reading: PowerReading, preferences: PreferencesStore, router: AppRouter) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let button = self?.statusButton else { return }
            J82FixtureLaunch.observe(button: button, router: router,
                                     reading: reading, preferences: preferences)
        }
    }

    func observeJ74StatusFixture(reading: PowerReading, preferences: PreferencesStore) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusButton else { return }
            J74FixtureLaunch.observe(button: button, reading: reading, preferences: preferences)
        }
    }

    /// Exercises the same secondary-click monitor as an ordinary status-item click.
    func openJ71ContextMenuFixture() {
        guard !fixtureOpened, let button = statusButton, let window = button.window else { return }
        fixtureOpened = true
        let location = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
        for type in [NSEvent.EventType.rightMouseDown, .rightMouseUp] {
            if let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
                NSApplication.shared.postEvent(event, atStart: false)
            }
        }
    }

    private var fixtureOpened = false
    private var fixtureMenu: NSMenu?
    func openContextMenuFixture() {
        guard !fixtureOpened, let menu = makeMenu?() else { return }
        fixtureOpened = true
        fixtureMenu = menu
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Native tracking, not a SwiftUI facsimile. No global event posting or AX.
            let arguments = ProcessInfo.processInfo.arguments
            let captureFlag = J21FixtureLaunch.requested ? "--watt-j21-capture-directory" : "--watt-c03-capture-directory"
            if J53FixtureLaunch.requested {
                J53FixtureLaunch.observeCapture(menu: menu)
            } else if let index = arguments.firstIndex(of: captureFlag),
               arguments.indices.contains(index + 1) {
                let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
                let expand = Timer(timeInterval: 0.2, repeats: false) { _ in
                    MainActor.assumeIsolated {
                        // Hover the parent using an app-local event, leaving Delta idle.
                        // AppKit owns submenu tracking and edge-aware placement.
                        if let window = NSApplication.shared.windows.first(where: {
                            $0.isVisible && !existing.contains(ObjectIdentifier($0))
                        }), let event = NSEvent.mouseEvent(with: .mouseMoved,
                            location: NSPoint(x: window.frame.width / 2, y: window.frame.height - 16),
                            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: window.windowNumber, context: nil,
                            eventNumber: 0, clickCount: 0, pressure: 0) {
                            NSApplication.shared.postEvent(event, atStart: true)
                        }
                    }
                }
                RunLoop.main.add(expand, forMode: .eventTracking)
                let timer = Timer(timeInterval: 1, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        let windows = NSApplication.shared.windows.filter {
                            $0.isVisible && !existing.contains(ObjectIdentifier($0))
                        }
                        var records: [[String: Any]] = []
                        for (index, window) in windows.enumerated() {
                            var record: [String: Any] = [
                                "class": String(describing: type(of: window)),
                                "frame": NSStringFromRect(window.frame),
                                "title": window.title,
                                "windowNumber": window.windowNumber
                            ]
                            if let view = window.contentView,
                               let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                                view.cacheDisplay(in: view.bounds, to: bitmap)
                                let name = "native-menu-\(index).png"
                                if let data = bitmap.representation(using: .png, properties: [:]) {
                                    do {
                                        try data.write(to: output.appendingPathComponent(name))
                                        record["capture"] = name
                                    } catch { record["error"] = String(describing: error) }
                                }
                            }
                            records.append(record)
                        }
                        let metadata: [String: Any] = [
                            "fixture": J53FixtureLaunch.requested ? "J5.3/base" : J21FixtureLaunch.requested ? "J2.1/base" : "C03/base",
                            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                            "windowOwnership": "NSApplication.shared.windows from this process",
                            "reference": J53FixtureLaunch.requested ? "30:4788" : J21FixtureLaunch.requested ? "29:1549" : "22:1095",
                            "method": "app-owned NSView.cacheDisplay during native NSMenu tracking",
                            "appearance": (J53FixtureLaunch.requested || J21FixtureLaunch.requested) ? "aqua" : "darkAqua", "windows": records,
                            "parentHighlighted": self?.fixtureMenu?.highlightedItem === self?.fixtureMenu?.items.first,
                            "submenuHighlighted": self?.fixtureMenu?.items.first?.submenu?.highlightedItem?.title ?? "none",
                            "deltaChecked": self?.fixtureMenu?.items.first?.submenu?.items.first?.state == .on,
                            "os": ProcessInfo.processInfo.operatingSystemVersionString,
                            "accessibility": "No AX, global event injection or TCC request",
                            "visualPass": false,
                            "limitation": "Only in-process menu views can be cached. System-hosted menu surfaces may be absent or blank."
                        ]
                        do {
                            try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                                .write(to: output.appendingPathComponent("capture-attempt.json"))
                        } catch { FileHandle.standardError.write(Data("Native menu capture failed: \(error)\n".utf8)) }
                        self?.fixtureMenu?.cancelTracking()
                    }
                }
                RunLoop.main.add(timer, forMode: .eventTracking)
            }
            let button = self.statusButton
            button?.highlight(true)
            defer {
                StatusItemContextMenu.endPresentation(menu)
                button?.highlight(false)
            }
            menu.popUp(positioning: menu.items.first, at: NSPoint(x: 0, y: -5), in: self)
        }
    }
    #endif

    fileprivate var statusButton: NSStatusBarButton? {
        func findButton(_ view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton { return button }
            return view.subviews.lazy.compactMap(findButton).first
        }
        return window?.contentView.flatMap(findButton)
    }

    func openPanel() {
        guard let button = statusButton else { return }
        // Defer until the context menu has ended its tracking loop.
        DispatchQueue.main.async { [weak self] in
            guard self?.window != nil, self?.makeMenu != nil else { return }
            button.performClick(nil)
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }
}

#if DEBUG
@MainActor
enum C05FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "C05/base"
        }
        return false
        #endif
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.completed = true
        return preferences
    }

    static func makeWindow() -> NSWindow {
        let host = NSHostingView(rootView: SettingsRootView()
            .environmentObject(makePreferences())
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 1000),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Watt? Settings"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-c05-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 580,
                    pixelsHigh: 1000, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "C05/base", "frameNode": "25:787", "windowNode": "25:1102",
                    "contentNode": "25:1129", "formNodes": ["25:1501", "25:1751", "25:1994", "25:2243", "25:2492"],
                    "appearance": "aqua", "locale": "en_US", "width": 580, "height": 1000,
                    "capture": "NSView.cacheDisplay; actual app-owned native form; titlebar excluded",
                    "storage": "fresh InMemoryStorage; fixed sampleCharging clock; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("C05 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J11FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.1/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(AppRouter())
            .environmentObject(preferences)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 308),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j11-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J1.1/base", "frameNode": "27:987", "windowNode": "27:1302",
                    "contentNode": "27:1319", "figmaWindowBounds": [260, 216, 480, 308],
                    "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned welcome content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; welcome checkpoint; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J11 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J12FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.2/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 346),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j12-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J1.2/base", "frameNode": "27:1354", "windowNode": "27:1508",
                    "contentNode": "27:1520", "figmaWindowBounds": [260, 197, 480, 346],
                    "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned reading content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; picker checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J12 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J13FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.3/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .helperOffer
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 412),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j13-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J1.3/base", "frameNode": "27:1584", "windowNode": "27:1738",
                    "contentNode": "27:1750", "rowsNode": "27:2106", "figmaWindowBounds": [260, 164, 480, 412],
                    "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned helper offer content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; helperOffer checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J13 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J14FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.4/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .approval
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 224),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j14-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "title": WaitingForApprovalView.title, "body": WaitingForApprovalView.message,
                    "fixture": "J1.4/base", "frameNode": "28:1206", "windowNode": "28:1521",
                    "contentNode": "28:1535", "spinnerNode": "28:1537", "notificationNode": "28:1584", "figmaWindowBounds": [260, 258, 480, 224],
                    "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned waiting for approval content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; approval checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "systemNotification": "Unavailable: system-owned surface excluded by safe app-owned capture/TCC",
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J14 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J15FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.5/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .preview
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 364),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j15-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "rows": ComponentPreviewView.componentNames.map {
                        $0 + " " + ComponentPreviewView.value(for: $0, reading: .sampleCharging)
                    },
                    "fixture": "J1.5/base", "frameNode": "28:1598", "windowNode": "28:1752",
                    "contentNode": "28:1764", "rowsNode": "28:2108", "figmaWindowBounds": [260, 188, 480, 364],
                    "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned component preview content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; preview checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J15 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J16FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.6/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .allSet
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 328),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j16-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "title": AllSetView.title, "body": AllSetView.message, "openAtLogin": true,
                    "fixture": "J1.6/base", "frameNode": "28:2199", "windowNode": "28:2353",
                    "contentNode": "28:2365", "rowsNode": "28:2532", "figmaWindowBounds": [260, 206, 480, 328],
                    "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned all-set content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; allSet checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics; not pixel-identical to Figma. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J16 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J17FixtureLaunch {
    private static var statusItem: NSStatusItem?
    private static var coachMark: NSPopover?
    private static var panel: C0410PanelSelection?

    static func launch() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding = .init(checkpoint: .coachMark, completed: true)
        let router = AppRouter()
        let item = NSStatusBar.system.statusItem(withLength: 96)
        statusItem = item
        guard let button = item.button else { return }
        let label = NSHostingView(rootView: MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences))
        label.frame = button.bounds
        label.autoresizingMask = [.width, .height]
        button.addSubview(label)
        MenuBarStatusAccessibility.apply(to: button, label: MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences))
        let popover = CoachMarkView.makePopover(preferences: preferences, router: router)
        coachMark = popover
        let selection = C0410PanelSelection(button: button, router: router, preferences: preferences, store: .preview)
        panel = selection
        router.present = { destination in
            if destination == .statusPanel { popover.close(); selection.togglePanel() }
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if button.window != nil {
                popover.show(relativeTo: NSRect(x: button.bounds.maxX - 1, y: button.bounds.minY,
                    width: 1, height: button.bounds.height), of: button, preferredEdge: .minY)
            }
            capture(popover: popover, button: button)
        }
    }

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.7/base"
        }
        return false
        #endif
    }

    static func capture(popover: NSPopover, button: NSStatusBarButton) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j17-capture-directory"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for (name, view) in [("actual-content", popover.contentViewController?.view), ("actual-status-item", button as NSView?)] {
                    guard let view else { throw ServiceFailure.invalidData }
                    view.layoutSubtreeIfNeeded()
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ServiceFailure.invalidData }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                    try png.write(to: directory.appendingPathComponent(name + ".png"))
                }
                let metadata: [String: Any] = ["fixture": "J1.7/base", "frameNode": "28:2621",
                    "popoverShown": popover.isShown, "actualStatusButton": true,
                    "capture": "cacheDisplay of real DEBUG NSStatusItem button and production NSPopover content; no relocation; not live MenuBarExtra interaction",
                    "storage": "InMemoryStorage; completed coachMark; fixed preview telemetry",
                    "visualPass": false, "liveInteractionVerified": false]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch { FileHandle.standardError.write(Data("J17 capture failed: \(error)\n".utf8)) }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J18FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.8/base"
        }
        return false
        #endif
    }
}

/// Captures only the live MenuBarExtra content after attachment to its real window.
/// No replacement window, fabricated status item, or offscreen rendering fallback.
struct J18PanelCaptureView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let arguments = ProcessInfo.processInfo.arguments
        let voiceOrder = J111FixtureLaunch.requested
        let lost = J32FixtureLaunch.requested
        let off = lost || J22FixtureLaunch.requested
        let height = Int(off ? WattSpacing.panelComponentsOffHeight : WattSpacing.panelHeight)
        let captureFlag = voiceOrder ? "--watt-j111-capture-directory" : lost ? "--watt-j32-capture-directory" : off ? "--watt-j22-capture-directory" : "--watt-j18-capture-directory"
        guard let index = arguments.firstIndex(of: captureFlag),
              index + 1 < arguments.count else { return view }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak view] in
            do {
                guard let view, let window = view.window, window.isVisible,
                      let content = window.contentView,
                      view.bounds.size == NSSize(width: WattSpacing.panelWidth, height: CGFloat(height)) else { throw ServiceFailure.invalidData }
                content.layoutSubtreeIfNeeded()
                let rect = view.convert(view.bounds, to: content)
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(WattSpacing.panelWidth),
                    pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                content.cacheDisplay(in: rect, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = ["fixture": voiceOrder ? "J11.1/base" : lost ? "J3.2/base" : off ? "J2.2/base" : "J1.8/base", "frameNode": voiceOrder ? "36:5057" : lost ? "29:5439" : off ? "29:2456" : "28:2802",
                    "panelNode": voiceOrder ? "36:5061" : lost ? "29:9518" : off ? "29:7572" : "29:9338", "width": Int(WattSpacing.panelWidth), "height": height, "appearance": voiceOrder || lost ? "darkAqua" : "aqua",
                    "capture": "cacheDisplay of attached real MenuBarExtra content; native chrome excluded",
                    "windowNumber": window.windowNumber, "visualPass": false,
                    "storage": "InMemoryStorage; completed livePanel; fixed charging telemetry",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch { FileHandle.standardError.write(Data("Live panel capture blocked: \(error)\n".utf8)) }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

#if DEBUG
@MainActor
enum J21FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.1/base"
        }
        return false
        #endif
    }
}
#endif

#if DEBUG
@MainActor
enum J22FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.2/base"
        }
        return false
        #endif
    }
}
#endif

#if DEBUG
@MainActor
enum J23FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.3/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WattSpacing.settingsExcerptWidth,
                                                  height: WattSpacing.settingsExcerptHeight),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        // Explicit reference appearance is confined to this DEBUG fixture.
        window.appearance = NSAppearance(named: .aqua)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true)
            .environmentObject(preferences).environmentObject(PowerReadingStore.preview)
            .environmentObject(AppRouter()).environment(\.locale, Locale(identifier: "en_US")))
        window.center()
        return window
    }
}
#endif

#if DEBUG
/// Pending-only fixture: no registration, OS notification, preference enablement or system effects.
@MainActor
enum J24FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.4/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let router = AppRouter()
        let helper = FakeHelperService()
        helper.status = .pending
        router.settingsHelperSetup.service = helper
        router.openApprovalSettings = {} // Fixture launch must not change OS state.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WattSpacing.settingsExcerptWidth,
                                                  height: WattSpacing.settingsExcerptHeight),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true)
            .environmentObject(preferences).environmentObject(router))
        window.center()
        return window
    }
}
#endif

#if DEBUG
/// J2.5 uses the production authentication/state machine with in-memory OS and IPC drivers.
/// Its identity and enabled registration are fixtures, never evidence of real OS approval.
@MainActor
final class J25FixtureSession {
    let preferences: PreferencesStore
    let router = AppRouter()
    let driver = J25FixtureDriver()
    let transport = J25FixtureTransport()
    let helper: HelperLifecycleAdapter
    let store = PowerReadingStore(currentReading: .unavailable,
                                 clock: FakeWattClock(now: PowerReading.samplePerComponent.timestamp))
    private var observation: AnyCancellable?

    init(storage: any PreferenceStorage = InMemoryStorage()) {
        preferences = PreferencesStore(storage: storage)
        preferences.displayMode = .components
        preferences.selectedComponents = ["CPU", "GPU"]
        preferences.showSymbol = false
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        helper = HelperLifecycleAdapter(driver: driver, transport: transport,
                                        expectedPeer: J25FixtureTransport.identity)
        router.settingsHelperSetup.service = helper
        router.openApprovalSettings = {} // No fixture action opens or changes System Settings.
        router.removeFromSettings = { [weak self] target in
            guard let self, target == .helper else { return .failed(.unknownStatus) }
            return await self.helper.remove(receipt: OperationReceipt(createdAt: self.store.currentReading.timestamp))
        }
        observation = router.settingsHelperSetup.$state.sink { [weak self] state in
            guard let self else { return }
            if state == .connected && self.helper.state == .connected {
                self.store.accept(.samplePerComponent, generation: self.store.generation)
            } else {
                self.store.disconnect()
            }
        }
    }

    func connect() async { await router.settingsHelperSetup.turnOn(preferences: preferences) }

    var componentsAvailable: Bool {
        router.settingsHelperSetup.helperOn && preferences.componentReadings
            && store.currentReading.source != .unavailable && store.currentReading.freshness == .fresh
            && store.currentReading.capabilities.components == .available
    }

    func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 330),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true, componentsExcerpt: true)
            .environmentObject(preferences).environmentObject(router).environmentObject(store))
        window.center()
        return window
    }
}

@MainActor
final class J25FixtureDriver: HelperLifecycleDriver {
    var statusValue: HelperRegistrationStatus = .enabled
    var removalFailure: ServiceFailure?
    func status() async throws -> HelperRegistrationStatus { statusValue }
    func verifyCandidate() throws -> HelperPeer { J25FixtureTransport.identity }
    func register(receipt: OperationReceipt) async throws { throw ServiceFailure.unknownStatus }
    func update(receipt: OperationReceipt) async throws { throw ServiceFailure.unknownStatus }
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { false }
    func unregister(receipt: OperationReceipt) async throws {
        if let removalFailure { throw removalFailure }
        statusValue = .absent
    }
}

@MainActor
final class J25FixtureTransport: HelperIPCTransport {
    static let identity = HelperPeer(identifier: "fixture.watt.helper", team: "FIXTURE", protocolVersion: 1)
    var peer = identity
    var onSend: (() -> Void)?
    func connect() async throws -> HelperPeer { peer }
    func send(_ request: HelperMessage) async throws -> HelperMessage { onSend?(); return request }
    func invalidate() {}
}

private struct J25StatusLabel: View {
    @ObservedObject var store: PowerReadingStore
    @ObservedObject var preferences: PreferencesStore
    var body: some View { MenuBarStatusLabel(reading: store.currentReading, preferences: preferences) }
}

@MainActor
enum J25FixtureLaunch {
    private static var session: J25FixtureSession?
    private static var window: NSWindow?
    private static var statusItem: NSStatusItem?
    private static var panel: C0410PanelSelection?
    private static var anchor: StatusAnchorView?
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.5/base"
        }
        return false
        #endif
    }
    static func launch() {
        let session = J25FixtureSession()
        self.session = session
        Task {
            await session.connect()
            let window = session.makeWindow()
            self.window = window
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem = item
            if let button = item.button {
                let host = NSHostingView(rootView: J25StatusLabel(store: session.store, preferences: session.preferences))
                item.length = host.fittingSize.width + 12
                host.frame = button.bounds
                host.autoresizingMask = [.width, .height]
                button.addSubview(host)
                MenuBarStatusAccessibility.apply(to: button, label: MenuBarStatusLabel(reading: session.store.currentReading, preferences: session.preferences))
                panel = C0410PanelSelection(button: button, router: session.router,
                                           preferences: session.preferences, store: session.store)
                let anchor = StatusAnchorView(frame: .zero)
                anchor.makeMenu = { StatusItemContextMenu.makeMenu(router: session.router,
                    preferences: session.preferences, componentsAvailable: { session.componentsAvailable }) }
                button.addSubview(anchor)
                self.anchor = anchor
            }
            session.router.present = { destination in
                switch destination {
                case .settings:
                    panel?.popover.performClose(nil)
                    window.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .statusPanel: if panel?.popover.isShown == false { panel?.togglePanel() }
                default: break // Unrelated fixture routes never start live services.
                }
            }
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J31FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J3.1/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let router = AppRouter()
        router.openApprovalSettings = {} // No fixture effects on OS settings.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 269),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true)
            .environmentObject(preferences).environmentObject(router)
            .task { router.settingsHelperSetup.cancel() })
        window.center()
        return window
    }
}
#endif

#if DEBUG
@MainActor
enum J32FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J3.2/base"
        }
        return false
        #endif
    }
}
#endif

#if DEBUG
@MainActor
enum J33FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J3.3/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let router = AppRouter()
        router.openApprovalSettings = {} // No fixture effects on OS settings.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 269),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Watt? Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView()
            .environmentObject(preferences).environmentObject(router)
            .task { router.helperUpdate.presented = true })
        window.center()
        return window
    }
}
#endif


#if DEBUG
@MainActor
enum J41FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J4.1/base"
        }
        return false
        #endif
    }

    static func makeWindow(preferences: PreferencesStore = PreferencesStore(storage: InMemoryStorage())) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WattSpacing.onboardingWidth, height: 308),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("J4.1.welcome")
        window.contentView = NSHostingView(rootView: OnboardingFlowView(
            welcomeVariant: .desktop, closeAction: { [weak window] in window?.performClose(nil) })
            .environmentObject(preferences)
            .environmentObject(PowerReadingStore(currentReading: J42FixtureLaunch.reading))
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        window.center()
        return window
    }
}
#endif

#if DEBUG
@MainActor
enum J42FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J4.2/base"
        }
        return false
        #endif
    }

    static let reading = PowerReading(
        mode: .systemDraw, watts: nil, timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        batteryState: .noBattery,
        capabilities: .init(battery: .unsupported, charger: .unsupported,
                            systemDraw: .available, components: .permissionRequired),
        source: .fixture, systemWatts: 38.2)

    static func makeWindow(preferences: PreferencesStore = PreferencesStore(storage: InMemoryStorage())) -> NSWindow {
        preferences.onboarding.checkpoint = .picker
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: reading)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WattSpacing.onboardingWidth, height: 346),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("J4.2.reading")
        window.contentView = NSHostingView(rootView: OnboardingFlowView(
            welcomeVariant: .desktop, closeAction: { [weak window] in window?.performClose(nil) })
            .environmentObject(preferences)
            .environmentObject(PowerReadingStore(currentReading: reading))
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        window.center()
        return window
    }
}
#endif


// Exact J4.3 specimen only; production never constructs this telemetry or changes preferences.
#if DEBUG
@MainActor
enum J43FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J4.3/base"
        }
        return false
        #endif
    }

    static let reading = PowerReading(
        mode: .systemDraw, watts: nil, detail: "Mac Studio · no battery, so it’s all draw",
        components: [PowerComponent(id: "cpu", name: "CPU", watts: 14.6),
                     PowerComponent(id: "gpu", name: "GPU", watts: 11.2),
                     PowerComponent(id: "ssd", name: "SSD", watts: 1.9),
                     PowerComponent(id: "other", name: "Other", watts: 10.5)],
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .noBattery,
        capabilities: .init(battery: .unsupported, charger: .unsupported,
                            systemDraw: .available, components: .available),
        source: .fixture, systemWatts: 38.2)

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: reading, clock: FakeWattClock(now: reading.timestamp))
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true)
        preferences.displayMode = .draw
        preferences.componentReadings = true
    }
}
#endif

// J5.1 uses the real MenuBarExtra/StatusAnchorView path with isolated fixture storage.
#if DEBUG
@MainActor
enum J51FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J5.1/base"
        }
        return false
        #endif
    }

    static func prepare(preferences: PreferencesStore) {
        OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter())
    }
}
#endif

// J5.2 opens the real light MenuBarExtra panel through its existing status anchor.
#if DEBUG
@MainActor
enum J52FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J5.2/base"
        }
        return false
        #endif
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .delta
        preferences.precision = .decimal
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .runningDefaults, completed: false)
    }
}
#endif

// J5.3 opens the production NSMenu through the actual status-item bridge.
#if DEBUG
@MainActor
enum J53FixtureLaunch {
    private static weak var capturedMenu: NSMenu?

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J5.3/base"
        }
        return false
        #endif
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .delta
        preferences.precision = .decimal
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .runningDefaults, completed: false)
    }

    /// Diagnostic identity only. Pixels must come from a PID-scoped compositor capture.
    /// Keep native tracking active until the capture process has collected its evidence.
    static func observeCapture(menu: NSMenu) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j53-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        capturedMenu = menu
        let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let hover = Timer(timeInterval: 0.2, repeats: false) { _ in
            MainActor.assumeIsolated {
                // App-local pointer movement exercises AppKit's native first-row highlight.
                if let window = NSApplication.shared.windows.first(where: {
                    $0.isVisible && !existing.contains(ObjectIdentifier($0))
                        && String(describing: type(of: $0)).contains("Menu")
                }), let event = NSEvent.mouseEvent(with: .mouseMoved,
                    location: NSPoint(x: window.frame.width / 2, y: window.frame.height - 16),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil,
                    eventNumber: 0, clickCount: 0, pressure: 0) {
                    NSApplication.shared.postEvent(event, atStart: true)
                }
            }
        }
        RunLoop.main.add(hover, forMode: .eventTracking)
        let observe = Timer(timeInterval: 1, repeats: false) { _ in
            MainActor.assumeIsolated {
                let windows: [[String: Any]] = NSApplication.shared.windows.filter {
                    $0.isVisible && !existing.contains(ObjectIdentifier($0))
                }.map { window in
                    ["class": String(describing: type(of: window)),
                     "frame": NSStringFromRect(window.frame), "title": window.title,
                     "windowNumber": window.windowNumber]
                }
                let metadata: [String: Any] = [
                    "fixture": "J5.3/base", "reference": "30:4788",
                    "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                    "method": "NSMenu tracking identity only; no in-process bitmap capture",
                    "appearance": "aqua", "windows": windows,
                    "finishSetupHighlighted": capturedMenu.map { $0.highlightedItem === $0.items.first } ?? false,
                    "visualPass": false, "liveInteractionVerified": false
                ]
                do {
                    try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appendingPathComponent("capture-attempt.json"))
                } catch { FileHandle.standardError.write(Data("Native menu observation failed: \(error)\n".utf8)) }
            }
        }
        RunLoop.main.add(observe, forMode: .eventTracking)
    }
}
#endif

// J6.1 opens the existing MenuBarExtra window; AppKit owns its dark chrome and selection.
#if DEBUG
@MainActor
enum J61FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua

    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J6.1/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleCharging,
                          clock: FakeWattClock(now: PowerReading.sampleCharging.timestamp))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        prepare(preferences: preferences)
        return preferences
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .delta
        preferences.precision = .decimal
        preferences.showSymbol = true
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true)
    }
}
#endif

// J6.2 opens the existing MenuBarExtra window; AppKit owns its dark chrome and selection.
#if DEBUG
@MainActor
enum J62FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua

    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J6.2/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleChargingHold,
                          clock: FakeWattClock(now: PowerReading.sampleChargingHold.timestamp))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        prepare(preferences: preferences)
        return preferences
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .delta
        preferences.precision = .decimal
        preferences.showSymbol = true
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true)
    }
}
#endif

// J6.3 opens the existing MenuBarExtra window; AppKit owns its dark chrome and selection.
#if DEBUG
@MainActor
enum J63FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua

    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J6.3/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleFullOnAdapter,
                          clock: FakeWattClock(now: PowerReading.sampleFullOnAdapter.timestamp))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        prepare(preferences: preferences)
        return preferences
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .delta
        preferences.precision = .decimal
        preferences.showSymbol = true
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true)
    }
}
#endif

// J6.4 uses the real native panel and P03 pipeline. The driver records intent only.
#if DEBUG
@MainActor
final class J64NotificationIntentDriver: NotificationSystemDriver {
    var permissionValue: NotificationPermission
    private(set) var permissionRequests = 0
    private(set) var intents: [(identifier: String, title: String, body: String)] = []

    init(permission: NotificationPermission) { permissionValue = permission }
    func permission() async -> NotificationPermission { permissionValue }
    func requestPermission() async throws {
        permissionRequests += 1
        throw ServiceFailure.unknownStatus
    }
    func enqueue(identifier: String, title: String, body: String) async throws {
        intents.append((identifier, title, body))
        // Deterministic eligibility evidence must never masquerade as OS acceptance.
        throw ServiceFailure.unknownStatus
    }
}
#endif

#if DEBUG
@MainActor
enum J64FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua
    static let variants = ["base", "notification-on-authorized", "notification-on-denied",
                           "notification-off-authorized", "notification-off-denied"]
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static var variant: String {
        #if SWIFT_PACKAGE
        "base"
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments),
           selection.story.id == "J6.4", variants.contains(selection.variant) { return selection.variant }
        return "base"
        #endif
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "J6.4" && variants.contains(selection.variant)
        }
        return false
        #endif
    }
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleInsufficientCharger,
                          clock: FakeWattClock(now: PowerReading.sampleInsufficientCharger.timestamp))
    }
    static func makePreferences(variant: String = "base") -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        J61FixtureLaunch.prepare(preferences: preferences)
        preferences.chargerNotification = ["base", "notification-on-authorized", "notification-on-denied"].contains(variant)
        return preferences
    }
    static func authorization(for variant: String) -> NotificationPermission {
        ["base", "notification-on-authorized", "notification-off-authorized"].contains(variant) ? .authorized : .denied
    }
    static func exerciseNotification(variant: String = "base", preferences: PreferencesStore,
                                     store: PowerReadingStore, router: AppRouter) async -> J64NotificationIntentDriver {
        let driver = J64NotificationIntentDriver(permission: authorization(for: variant))
        guard variants.contains(variant) else { return driver }
        let bridge = SystemNotificationBridge(driver: driver)
        router.notificationAuthorization = await bridge.authorization()
        let effect = await PowerNotificationEffects(bridge: bridge, preferences: preferences)
            .handleInsufficientCharger(store: store)
        FileHandle.standardOutput.write(Data("J6.4 fixture \(variant): intent count=\(driver.intents.count), effect=\(effect); simulated authorization only, OS delivery unproven\n".utf8))
        return driver
    }
}
#endif

// J6.5 reuses the on-battery sample and native MenuBarExtra selection bridge.
#if DEBUG
@MainActor
enum J65FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua

    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J6.5/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleOnBattery,
                          clock: FakeWattClock(now: PowerReading.sampleOnBattery.timestamp))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        prepare(preferences: preferences)
        return preferences
    }

    static func prepare(preferences: PreferencesStore) {
        J61FixtureLaunch.prepare(preferences: preferences)
    }
}
#endif

// J7.1 uses the production status-item secondary-click monitor and native NSMenu tracking.
#if DEBUG
@MainActor
enum J71FixtureLaunch {
    private static weak var capturedMenu: NSMenu?
    private static weak var capturedButton: NSStatusBarButton?
    private static var keyboardTimer: Timer?
    private static var keyboardSteps = 0
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J7.1/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleCharging,
                          clock: FakeWattClock(now: PowerReading.sampleCharging.timestamp))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .delta
        preferences.precision = .decimal
        preferences.showSymbol = true
        preferences.componentReadings = true
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    static func prepare(router: AppRouter) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.refreshStatus()
    }

    /// Records identity/state only. Pixels must come from the live PID-owned compositor.
    /// Arrow events are local to this app; AppKit chooses submenu geometry and highlight.
    static func observeTracking(menu: NSMenu, button: NSStatusBarButton) {
        let arguments = ProcessInfo.processInfo.arguments
        let output: URL? = arguments.firstIndex(of: "--watt-j71-capture-directory").flatMap {
            arguments.indices.contains($0 + 1) ? URL(fileURLWithPath: arguments[$0 + 1], isDirectory: true) : nil
        }
        let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        capturedMenu = menu
        capturedButton = button
        keyboardSteps = 0
        keyboardTimer?.invalidate()
        let keyboard = Timer(timeInterval: 0.2, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard let menu = capturedMenu, let button = capturedButton, let submenu = menu.items.first?.submenu,
                      keyboardSteps < 12, submenu.highlightedItem?.title != "Components" else {
                    keyboardTimer?.invalidate()
                    return
                }
                keyboardSteps += 1
                let openSubmenu = menu.highlightedItem === menu.items.first && submenu.highlightedItem == nil
                let character = String(UnicodeScalar(openSubmenu ? NSRightArrowFunctionKey : NSDownArrowFunctionKey)!)
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                    modifierFlags: [.function, .numericPad], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: button.window?.windowNumber ?? 0, context: nil, characters: character,
                    charactersIgnoringModifiers: character, isARepeat: false, keyCode: openSubmenu ? 124 : 125) {
                    NSApplication.shared.postEvent(event, atStart: true)
                }
            }
        }
        keyboardTimer = keyboard
        RunLoop.main.add(keyboard, forMode: .eventTracking)
        let observe = Timer(timeInterval: 2.8, repeats: false) { _ in
            MainActor.assumeIsolated {
                keyboardTimer?.invalidate()
                guard let output, let menu = capturedMenu, let button = capturedButton else { return }
                let windows: [[String: Any]] = NSApplication.shared.windows.filter {
                    $0.isVisible && !existing.contains(ObjectIdentifier($0))
                }.map {
                    ["class": String(describing: type(of: $0)), "frame": NSStringFromRect($0.frame),
                     "title": $0.title, "windowNumber": $0.windowNumber]
                }
                let metadata: [String: Any] = [
                    "fixture": "J7.1/base", "reference": "31:6173",
                    "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                    "method": "App-local secondary click and arrow keys; native tracking identity only",
                    "appearance": "aqua", "windows": windows,
                    "statusItem": ["windowNumber": button.window?.windowNumber ?? 0,
                                   "frame": NSStringFromRect(button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero),
                                   "highlighted": button.isHighlighted,
                                   "appearance": button.effectiveAppearance.name.rawValue],
                    "parentHighlighted": menu.highlightedItem === menu.items.first,
                    "submenuHighlighted": menu.items.first?.submenu?.highlightedItem?.title ?? "none",
                    "deltaChecked": menu.items.first?.submenu?.items.first?.state == .on,
                    "visualPass": false, "liveInteractionVerified": false
                ]
                do {
                    try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appendingPathComponent("capture-attempt.json"))
                } catch { FileHandle.standardError.write(Data("J7.1 native menu observation failed: \(error)\n".utf8)) }
            }
        }
        RunLoop.main.add(observe, forMode: .eventTracking)
    }
}
#endif

// J7.2 supplies values/preferences to the ordinary MenuBarExtra label and native bridge.
#if DEBUG
@MainActor
enum J72FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J7.2/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .samplePerComponent,
                          clock: FakeWattClock(now: PowerReading.samplePerComponent.timestamp))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .components
        preferences.selectedComponents = ["CPU", "GPU"]
        preferences.componentReadings = true
        preferences.showSymbol = false
        preferences.precision = .decimal
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    /// Identity and semantic evidence only; compositor/AX capture is external and PID-checked.
    static func observe(button: NSStatusBarButton, reading: PowerReading, preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j72-capture-directory"),
              arguments.indices.contains(index + 1), let window = button.window else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        let record: [String: Any] = [
            "fixture": "J7.2/base", "reference": "31:6952",
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "method": "Native status button identity only; no in-process bitmap capture",
            "statusText": label.text ?? "", "showsSymbol": label.showsSymbol,
            "accessibilityReading": label.accessibilityReading,
            "appearance": button.effectiveAppearance.name.rawValue,
            "selected": button.isHighlighted,
            "statusItem": ["windowNumber": window.windowNumber,
                           "windowClass": String(describing: type(of: window)),
                           "buttonClass": String(describing: type(of: button)),
                           "buttonFrameInScreen": NSStringFromRect(window.convertToScreen(button.convert(button.bounds, to: nil)))],
            "visualPass": false
        ]
        do {
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("capture-attempt.json"))
        } catch { FileHandle.standardError.write(Data("J7.2 native status observation failed: \(error)\n".utf8)) }
    }
}
#endif
