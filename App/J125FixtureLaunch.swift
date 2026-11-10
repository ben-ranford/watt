#if DEBUG
import AppKit

/// In-memory reconnect fixture; does not mutate an installed helper.
/// It exercises the configured Settings launch route and the verified reconnect state, and
/// records only the real Settings window identity for the external capture gate.
@MainActor
enum J125FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J12.5/base"
        }
        return false
        #endif
    }

    static func makeStore() -> PowerReadingStore { J71FixtureLaunch.makeStore() }
    static func makePreferences() -> PreferencesStore {
        let preferences = J71FixtureLaunch.makePreferences()
        preferences.showSymbol = true
        return preferences
    }

    static func prepare(router: AppRouter, preferences: PreferencesStore) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        router.removeFromSettings = { _ in .cancelled }
        let prompt = LeftoverHelperPrompt(storage: InMemoryStorage(), installationID: UUID())
        prompt.detect = { true }
        prompt.reconnect = { await helper.reconcile(receipt: nil) }
        prompt.onCompleted = { action in
            if action == .reconnect { try router.completeLeftoverReconnect(preferences: preferences) }
        }
        // Preserve the All Set route but display only the requested Settings reference.
        let present = router.present
        router.present = { _ in }
        await prompt.discover()
        if let intent = prompt.intent { await prompt.perform(.reconnect, intent: intent) }
        router.present = present
    }

    static func observe(preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j125-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        Task { @MainActor in
            for _ in 0..<80 {
                if let window = NSApplication.shared.windows.first(where: {
                    $0.isVisible && $0.title == SettingsRootView.title
                }) {
                    let record: [String: Any] = [
                        "fixture": "J12.5/base",
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
                "fixture": "J12.5/base",
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
            FileHandle.standardError.write(Data("J12.5 native observation failed: \(error)\n".utf8))
        }
    }
}
#endif
