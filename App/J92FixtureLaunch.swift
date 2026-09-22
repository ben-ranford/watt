#if DEBUG
import AppKit

/// Deterministic native Settings-scene fixture for J9.2.
/// It exercises the configured Settings launch route and the verified removed state, and
/// records only the real Settings window identity for the external capture gate.
@MainActor
enum J92FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J9.2/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore { J71FixtureLaunch.makeStore() }
    static func makePreferences() -> PreferencesStore {
        let preferences = J91FixtureLaunch.makePreferences()
        preferences.showSymbol = true
        return preferences
    }

    static func prepare(router: AppRouter, preferences: PreferencesStore) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        // Exercise the real verified-removal route using an isolated in-memory service.
        router.removeFromSettings = { _ in
            await helper.remove(receipt: OperationReceipt(createdAt: Date()))
        }
        _ = await router.removeVerifiedHelper(preferences: preferences)
    }

    static func observe(preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j92-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        Task { @MainActor in
            for _ in 0..<80 {
                if let window = NSApplication.shared.windows.first(where: {
                    $0.isVisible && $0.title == SettingsRootView.title
                }) {
                    let record: [String: Any] = [
                        "fixture": "J9.2/base",
                        "node": "32:5844",
                        "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                        "method": "Native SwiftUI Settings scene identity; no replacement window or bitmap renderer",
                        "appearance": window.effectiveAppearance.name.rawValue,
                        "settingsWindowNumber": window.windowNumber,
                        "windowClass": String(describing: type(of: window)),
                        "title": window.title,
                        "frame": NSStringFromRect(window.frame),
                        "contentSize": NSStringFromSize(window.contentView?.fittingSize ?? .zero),
                        "displayMode": preferences.displayMode.rawValue,
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
                "fixture": "J9.2/base",
                "node": "32:5844",
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
            FileHandle.standardError.write(Data("J9.2 native observation failed: \(error)\n".utf8))
        }
    }
}
#endif
