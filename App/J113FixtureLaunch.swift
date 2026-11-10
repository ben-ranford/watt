#if DEBUG
import AppKit

/// Deterministic native Settings-scene fixture for J11.3.
/// It exercises the same configured launch route used by Finder/Spotlight and
/// records only the real Settings window identity for the external capture gate.
@MainActor
enum J113FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J11.3/base"
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
        preferences.showSymbol = true
        preferences.openAtLogin = true
        preferences.checkForUpdatesAutomatically = true
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    static func observe(preferences: PreferencesStore, button: NSStatusBarButton?) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j113-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            for _ in 0..<80 {
                if let window = NSApplication.shared.windows.first(where: {
                    $0.isVisible && $0.title == SettingsRootView.title
                }) {
                    let record: [String: Any] = [
                        "fixture": "J11.3/base",
                        "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                        "method": "Native SwiftUI Settings scene identity; no replacement window or bitmap renderer",
                        "appearance": window.effectiveAppearance.name.rawValue,
                        "settingsWindowNumber": window.windowNumber,
                        "windowClass": String(describing: type(of: window)),
                        "title": window.title,
                        "frame": NSStringFromRect(window.frame),
                        "attachedSheet": window.attachedSheet != nil,
                        "contentSize": NSStringFromSize(window.contentView?.fittingSize ?? .zero),
                        "displayMode": preferences.displayMode.rawValue,
                        "statusWindowNumber": button?.window?.windowNumber ?? -1,
                        "statusItemTitle": button?.title ?? "",
                        "statusItemHasImage": button?.image != nil,
                        "showSymbol": preferences.showSymbol,
                        "openAtLogin": preferences.openAtLogin,
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
                "fixture": "J11.3/base",
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
            FileHandle.standardError.write(Data("J11.3 native observation failed: \(error)\n".utf8))
        }
    }
}
#endif
