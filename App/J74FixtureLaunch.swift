#if DEBUG
import AppKit

/// Supplies isolated state to the ordinary MenuBarExtra; never draws a status item.
@MainActor
enum J74FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J7.4/base"
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
        preferences.displayMode = .iconOnly
        preferences.showSymbol = true
        preferences.precision = .decimal
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

    /// Identity/semantics only. A separate PID-owned compositor/AX capture must prove pixels.
    static func observe(button: NSStatusBarButton, reading: PowerReading, preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j74-capture-directory"),
              arguments.indices.contains(index + 1), let window = button.window else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        let record: [String: Any] = [
            "fixture": "J7.4/base",
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "method": "Native status button identity only; no in-process bitmap capture",
            "statusText": label.text ?? "", "showsSymbol": label.showsSymbol,
            "symbolName": label.symbolName, "accessibilityReading": label.accessibilityReading,
            "nativeButtonImageIsTemplate": button.image.map { $0.isTemplate as Any } ?? NSNull(),
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
        } catch { FileHandle.standardError.write(Data("J7.4 native status observation failed: \(error)\n".utf8)) }
    }
}
#endif
