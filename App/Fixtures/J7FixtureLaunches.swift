import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

// J7.1 uses the production status-item secondary-click monitor and native NSMenu tracking.
#if DEBUG
@MainActor
enum J71FixtureLaunch {
    private static weak var capturedMenu: NSMenu?
    private static weak var capturedButton: NSStatusBarButton?
    private static var keyboardTimer: Timer?
    private static var keyboardSteps = 0
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J7.1/base"
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
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    static func prepare(router: AppRouter) async {
        let helper = FakeHelperService()
        helper.status = .connected
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.refreshStatus()
    }

    /// Records identity/state only. Pixels must come from the live PID-owned compositor.
    /// Arrow events are local to this app; AppKit chooses submenu geometry and highlight.
    static func observeTracking(menu: NSMenu, button: NSStatusBarButton) {
        let arguments = ProcessInfo.processInfo.arguments
        let output: URL? = arguments.firstIndex(of: "--watt-j71-capture-directory").flatMap {
            arguments.indices.contains($0 + 1) ? URL(fileURLWithPath: arguments[$0 + 1], isDirectory: true) : nil
        }
        let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        capturedMenu = menu
        capturedButton = button
        keyboardSteps = 0
        keyboardTimer?.invalidate()
        let keyboard = Timer(timeInterval: 0.2, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard let menu = capturedMenu, let button = capturedButton, let submenu = menu.items.first?.submenu,
                      keyboardSteps < 12, submenu.highlightedItem?.title != "Components" else {
                    keyboardTimer?.invalidate()
                    return
                }
                keyboardSteps += 1
                let openSubmenu = menu.highlightedItem === menu.items.first && submenu.highlightedItem == nil
                let character = String(UnicodeScalar(openSubmenu ? NSRightArrowFunctionKey : NSDownArrowFunctionKey)!)
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                    modifierFlags: [.function, .numericPad], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: button.window?.windowNumber ?? 0, context: nil, characters: character,
                    charactersIgnoringModifiers: character, isARepeat: false, keyCode: openSubmenu ? 124 : 125) {
                    NSApplication.shared.postEvent(event, atStart: true)
                }
            }
        }
        keyboardTimer = keyboard
        RunLoop.main.add(keyboard, forMode: .eventTracking)
        let observe = Timer(timeInterval: 2.8, repeats: false) { _ in
            MainActor.assumeIsolated {
                keyboardTimer?.invalidate()
                guard let output, let menu = capturedMenu, let button = capturedButton else { return }
                let windows: [[String: Any]] = NSApplication.shared.windows.filter {
                    $0.isVisible && !existing.contains(ObjectIdentifier($0))
                }.map {
                    ["class": String(describing: type(of: $0)), "frame": NSStringFromRect($0.frame),
                     "title": $0.title, "windowNumber": $0.windowNumber]
                }
                let metadata: [String: Any] = [
                    "fixture": "J7.1/base",
                    "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                    "method": "App-local secondary click and arrow keys; native tracking identity only",
                    "appearance": "aqua", "windows": windows,
                    "statusItem": ["windowNumber": button.window?.windowNumber ?? 0,
                                   "frame": NSStringFromRect(button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero),
                                   "highlighted": button.isHighlighted,
                                   "appearance": button.effectiveAppearance.name.rawValue],
                    "parentHighlighted": menu.highlightedItem === menu.items.first,
                    "submenuHighlighted": menu.items.first?.submenu?.highlightedItem?.title ?? "none",
                    "deltaChecked": menu.items.first?.submenu?.items.first?.state == .on,
                    "visualPass": false, "liveInteractionVerified": false
                ]
                do {
                    try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appendingPathComponent("capture-attempt.json"))
                } catch { FileHandle.standardError.write(Data("J7.1 native menu observation failed: \(error)\n".utf8)) }
            }
        }
        RunLoop.main.add(observe, forMode: .eventTracking)
    }
}
#endif

// J7.2 supplies values/preferences to the ordinary MenuBarExtra label and native bridge.
#if DEBUG
@MainActor
enum J72FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }

    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.stableID == "J7.2/base"
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
        preferences.showSymbol = false
        preferences.precision = .decimal
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        return preferences
    }

    /// Identity and semantic evidence only; compositor/AX capture is external and PID-checked.
    static func observe(button: NSStatusBarButton, reading: PowerReading, preferences: PreferencesStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j72-capture-directory"),
              arguments.indices.contains(index + 1), let window = button.window else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        let record: [String: Any] = [
            "fixture": "J7.2/base",
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "method": "Native status button identity only; no in-process bitmap capture",
            "statusText": label.text ?? "", "showsSymbol": label.showsSymbol,
            "accessibilityReading": label.accessibilityReading,
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
        } catch { FileHandle.standardError.write(Data("J7.2 native status observation failed: \(error)\n".utf8)) }
    }
}
#endif
