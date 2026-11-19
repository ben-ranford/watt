import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
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
