#if DEBUG
import AppKit

/// Deterministic native Settings-scene fixture for G079/J11.2.
/// The fixture reaches the production Settings scene and only injects isolated
/// preferences/helper state needed to make every reference row deterministic.
@MainActor
enum J112FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J11.2/base"
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
        preferences.displayMode = .delta
        preferences.showSymbol = true
        preferences.precision = .decimal
        preferences.selectedComponents = ["CPU", "GPU"]
        preferences.updateInterval = "Every 2 seconds"
        preferences.smoothReadings = true
        preferences.componentReadings = true
        preferences.chargerNotification = true
        preferences.fullyChargedNotification = false
        preferences.openAtLogin = true
        preferences.checkForUpdatesAutomatically = true
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    static func prepare(router: AppRouter) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.refreshStatus()
    }

    /// Records only the real Settings window identity; pixels remain the
    /// responsibility of the strict app-owned compositor capture script.
    static func observe(preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j112-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        Task { @MainActor in
            for _ in 0..<80 {
                if let window = NSApplication.shared.windows.first(where: {
                    $0.isVisible && $0.title == SettingsRootView.title
                }) {
                    let record: [String: Any] = [
                        "fixture": "J11.2/base",
                        "node": "36:5186",
                        "windowNode": "36:5188",
                        "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                        "method": "Native SwiftUI Settings scene identity; no replacement window or bitmap renderer",
                        "appearance": window.effectiveAppearance.name.rawValue,
                        "settingsWindowNumber": window.windowNumber,
                        "windowClass": String(describing: type(of: window)),
                        "title": window.title,
                        "frame": NSStringFromRect(window.frame),
                        "contentSize": NSStringFromSize(window.contentView?.fittingSize ?? .zero),
                        "resizable": window.styleMask.contains(.resizable),
                        "key": window.isKeyWindow,
                        "firstResponder": window.firstResponder.map { String(describing: type(of: $0)) } ?? "none",
                        "displayMode": preferences.displayMode.rawValue,
                        "showSymbol": preferences.showSymbol,
                        "precision": preferences.precision.rawValue,
                        "updateInterval": preferences.updateInterval,
                        "smoothReadings": preferences.smoothReadings,
                        "componentReadings": preferences.componentReadings,
                        "chargerNotification": preferences.chargerNotification,
                        "fullyChargedNotification": preferences.fullyChargedNotification,
                        "openAtLogin": preferences.openAtLogin,
                        "checkForUpdatesAutomatically": preferences.checkForUpdatesAutomatically,
                        "visualPass": false,
                        "score": NSNull(),
                        "pixel_diff": NSNull()
                    ]
                    write(record, to: output)
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            write([
                "fixture": "J11.2/base",
                "node": "36:5186",
                "windowNode": "36:5188",
                "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                "status": "blocked",
                "reason": "Native Settings window did not become visible before observation timeout",
                "visualPass": false,
                "score": NSNull(),
                "pixel_diff": NSNull()
            ], to: output)
        }
    }

    private static func write(_ record: [String: Any], to directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("capture-attempt.json"))
        } catch {
            FileHandle.standardError.write(Data("J11.2 native observation failed: \(error)\n".utf8))
        }
    }
}
#endif
