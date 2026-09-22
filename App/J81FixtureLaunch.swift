#if DEBUG
import AppKit

/// Isolated state for the production native panel. No capture window or renderer.
@MainActor
enum J81FixtureLaunch {
    static let appearanceName = NSAppearance.Name.darkAqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J8.1/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(),
                          telemetry: FakeTelemetryService(outcome: .success(.unavailable)))
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

    static func prepare(router: AppRouter) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.refreshStatus()
    }

    /// Records native identity only; an external AX/compositor gate proves capture eligibility.
    static func observe(button: NSStatusBarButton, router: AppRouter) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j81-capture-directory"),
              arguments.indices.contains(index + 1), let window = button.window else { return }
        let record: [String: Any] = [
            "fixture": "J8.1/base", "node": "32:3451",
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "method": "Native MenuBarExtra identity only; no in-process bitmap capture",
            "appearance": button.effectiveAppearance.name.rawValue,
            "selected": button.isHighlighted, "panelPresented": router.statusPanelPresented,
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
        } catch { FileHandle.standardError.write(Data("J8.1 native observation failed: \(error)\n".utf8)) }
    }
}
#endif
