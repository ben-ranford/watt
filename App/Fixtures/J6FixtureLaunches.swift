import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
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
