#if DEBUG
import AppKit

/// J11.1 uses the production MenuBarExtra/status-item bridge and the native
/// `.window` panel. It only supplies deterministic telemetry/preferences.
@MainActor
enum J111FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua

    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J11.1/base"
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
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true)
        return preferences
    }
}
#endif
