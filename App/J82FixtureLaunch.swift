#if DEBUG
import AppKit

/// Deterministic recovery fixture for the native status-item surface.
/// It starts with no reading, then resumes through PowerReadingStore.refresh().
@MainActor
enum J82FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J8.2/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .unavailable,
                          clock: FakeWattClock(now: PowerReading.sampleCharging.timestamp),
                          telemetry: FakeTelemetryService(outcome: .success(.sampleCharging)))
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .delta
        preferences.showSymbol = true
        preferences.precision = .decimal
        preferences.componentReadings = true
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    static func prepare(router: AppRouter, store: PowerReadingStore) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.refreshStatus()
        // Simulate telemetry resuming through the same validated production path.
        await store.refresh()
    }

    /// Records native identity and recovered semantics only; capture eligibility is external.
    static func observe(button: NSStatusBarButton, router: AppRouter,
                        reading: PowerReading, preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j82-capture-directory"),
              arguments.indices.contains(index + 1), let window = button.window else { return }
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        let record: [String: Any] = [
            "fixture": "J8.2/base", "node": "32:4456",
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "method": "Native MenuBarExtra identity only; no in-process bitmap capture",
            "appearance": button.effectiveAppearance.name.rawValue,
            "selected": button.isHighlighted, "panelPresented": router.statusPanelPresented,
            "reading": ["text": label.text ?? "<icon-only>", "accessibility": label.accessibilityReading,
                        "symbol": label.symbolName],
            "statusItem": ["windowNumber": window.windowNumber,
                           "windowClass": String(describing: type(of: window)),
                           "buttonClass": String(describing: type(of: button)),
                           "buttonFrameInScreen": NSStringFromRect(window.convertToScreen(button.convert(button.bounds, to: nil)))],
            "visualPass": false, "score": NSNull(), "pixel_diff": NSNull()
        ]
        do {
            let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("capture-attempt.json"))
        } catch { FileHandle.standardError.write(Data("J8.2 native observation failed: \(error)\n".utf8)) }
    }
}
#endif
