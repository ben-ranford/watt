#if DEBUG
import AppKit

/// Native quit observation only. No desktop, status item, or replacement window is created.
@MainActor
enum J93FixtureLaunch {
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J9.3/base"
        }
        return false
        #endif
    }
    static func makeStore() -> PowerReadingStore { J92FixtureLaunch.makeStore() }
    static func makePreferences() -> PreferencesStore { J92FixtureLaunch.makePreferences() }

    static func observeAndQuit(menu: NSMenu?, button: NSStatusBarButton?) {
        guard let menu, let button, let window = button.window,
              let index = menu.items.firstIndex(where: { $0.title == "Quit Watt?" }) else { return }
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.firstIndex(of: "--watt-j93-capture-directory"), args.indices.contains(flag + 1) {
            let output = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
            let record: [String: Any] = [
                "fixture": "J9.3/base",
                "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                "statusWindowNumber": window.windowNumber,
                "method": "Programmatic invocation of production native Quit menu action; not a user AX click",
                "visualPass": false, "liveInteractionVerified": false,
                "score": NSNull(), "pixel_diff": NSNull()
            ]
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                    .write(to: output.appendingPathComponent("before-quit.json"))
            } catch { FileHandle.standardError.write(Data("J9.3 observation failed: \(error)\n".utf8)) }
        }
        // Exit the installation callback before dispatching the existing native action.
        DispatchQueue.main.async { menu.performActionForItem(at: index) }
    }
}
#endif
