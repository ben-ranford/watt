import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

// J5.1 uses the real MenuBarExtra/StatusAnchorView path with isolated fixture storage.
#if DEBUG
@MainActor
enum J51FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J5.1/base"
        }
        return false
        #endif
    }

    static func prepare(preferences: PreferencesStore) {
        OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter())
    }
}
#endif

// J5.2 opens the real light MenuBarExtra panel through its existing status anchor.
#if DEBUG
@MainActor
enum J52FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J5.2/base"
        }
        return false
        #endif
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .draw
        preferences.precision = .decimal
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .runningDefaults, completed: false)
    }
}
#endif

// J5.3 opens the production NSMenu through the actual status-item bridge.
#if DEBUG
@MainActor
enum J53FixtureLaunch {
    private static weak var capturedMenu: NSMenu?

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J5.3/base"
        }
        return false
        #endif
    }

    static func prepare(preferences: PreferencesStore) {
        preferences.displayMode = .draw
        preferences.precision = .decimal
        preferences.componentReadings = false
        preferences.onboarding = .init(checkpoint: .runningDefaults, completed: false)
    }

    /// Diagnostic identity only. Pixels must come from a PID-scoped compositor capture.
    /// Keep native tracking active until the capture process has collected its evidence.
    static func observeCapture(menu: NSMenu) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j53-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        capturedMenu = menu
        let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let hover = Timer(timeInterval: 0.2, repeats: false) { _ in
            MainActor.assumeIsolated {
                // App-local pointer movement exercises AppKit's native first-row highlight.
                if let window = NSApplication.shared.windows.first(where: {
                    $0.isVisible && !existing.contains(ObjectIdentifier($0))
                        && String(describing: type(of: $0)).contains("Menu")
                }), let event = NSEvent.mouseEvent(with: .mouseMoved,
                    location: NSPoint(x: window.frame.width / 2, y: window.frame.height - 16),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil,
                    eventNumber: 0, clickCount: 0, pressure: 0) {
                    NSApplication.shared.postEvent(event, atStart: true)
                }
            }
        }
        RunLoop.main.add(hover, forMode: .eventTracking)
        let observe = Timer(timeInterval: 1, repeats: false) { _ in
            MainActor.assumeIsolated {
                let windows: [[String: Any]] = NSApplication.shared.windows.filter {
                    $0.isVisible && !existing.contains(ObjectIdentifier($0))
                }.map { window in
                    ["class": String(describing: type(of: window)),
                     "frame": NSStringFromRect(window.frame), "title": window.title,
                     "windowNumber": window.windowNumber]
                }
                let metadata: [String: Any] = [
                    "fixture": "J5.3/base",
                    "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                    "method": "NSMenu tracking identity only; no in-process bitmap capture",
                    "appearance": "aqua", "windows": windows,
                    "finishSetupHighlighted": capturedMenu.map { $0.highlightedItem === $0.items.first } ?? false,
                    "visualPass": false, "liveInteractionVerified": false
                ]
                do {
                    try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appendingPathComponent("capture-attempt.json"))
                } catch { FileHandle.standardError.write(Data("Native menu observation failed: \(error)\n".utf8)) }
            }
        }
        RunLoop.main.add(observe, forMode: .eventTracking)
    }
}
#endif
