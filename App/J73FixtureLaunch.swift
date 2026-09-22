#if DEBUG
import AppKit

/// Isolated state and native-control invocation only. No window or bitmap renderer.
@MainActor
enum J73FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J7.3/base"
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
        preferences.displayMode = .components
        preferences.selectedComponents = ["CPU", "GPU"]
        preferences.componentReadings = true
        preferences.precision = .decimal
        preferences.showSymbol = false
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    static func prepare(router: AppRouter) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.refreshStatus()
    }

    static func openComponentsMenu() {
        Task {
            for _ in 0..<40 {
                if let button = NSApplication.shared.windows.filter(\.isVisible).compactMap({ window in
                    window.contentView.flatMap(findButton)
                }).first, let window = button.window {
                    observeTracking(button: button, window: window)
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(button)
                    button.performClick(nil)
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private static func findButton(_ view: NSView) -> NSPopUpButton? {
        if let button = view as? NSPopUpButton,
           button.accessibilityIdentifier() == "settings.components" { return button }
        return view.subviews.compactMap(findButton).first
    }

    private static func observeTracking(button: NSPopUpButton, window: NSWindow) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j73-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let existing = Set(NSApplication.shared.windows.map(\.windowNumber))
        let timer = Timer(timeInterval: 1, repeats: false) { [weak button, weak window] _ in
            MainActor.assumeIsolated {
                guard let button, let window else { return }
                let windows: [[String: Any]] = NSApplication.shared.windows.filter {
                    $0.isVisible && !existing.contains($0.windowNumber)
                }.map { ["windowNumber": $0.windowNumber, "class": String(describing: type(of: $0))] }
                let record: [String: Any] = [
                    "fixture": "J7.3/base", "reference": "31:7102",
                    "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                    "settingsWindowNumber": window.windowNumber, "title": window.title,
                    "appearance": window.effectiveAppearance.name.rawValue,
                    "buttonClass": String(describing: type(of: button)),
                    "buttonIdentifier": button.accessibilityIdentifier(),
                    "menuWindows": windows,
                    "items": button.itemArray.map {
                        ["title": $0.title, "checked": $0.state == .on, "enabled": $0.isEnabled] as [String: Any]
                    },
                    "visualPass": false
                ]
                do {
                    try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appendingPathComponent("capture-attempt.json"))
                } catch { FileHandle.standardError.write(Data("J7.3 observation failed: \(error)\n".utf8)) }
            }
        }
        RunLoop.main.add(timer, forMode: .eventTracking)
    }
}
#endif
