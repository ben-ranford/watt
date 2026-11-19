import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

#if DEBUG
@MainActor
enum C01FixtureLaunch {
    static weak var router: AppRouter?
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C01"
        }
        return false
        #endif
    }
}

@MainActor
enum C02FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C02"
        }
        return false
        #endif
    }
}

@MainActor
enum C03FixtureLaunch {
    static weak var preferences: PreferencesStore?
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C03"
        }
        return false
        #endif
    }
}

@MainActor
enum C041FixtureLaunch {
    // Capture frame and app-owned component geometry, in points.
    static let captureSize = NSSize(width: 560, height: 44)
    static let itemRect = NSRect(x: 205, y: 5, width: 96, height: 24)

    /// Explicit pixels and point size avoid inheriting the screen's Retina scale.
    static func captureBitmap1x() -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(captureSize.width),
            pixelsHigh: Int(captureSize.height), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        bitmap.size = captureSize
        return bitmap
    }

    static var captureRequested: Bool {
        requested && ProcessInfo.processInfo.arguments.contains("--watt-c041-capture-directory")
    }
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.story.id == "C04.1"
        }
        return false
        #endif
    }
}

@MainActor
enum C042FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 204, y: 5, width: 97, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleOnBattery,
                          clock: FakeWattClock(now: PowerReading.sampleOnBattery.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.2"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c042-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C043FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 220, y: 5, width: 81, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleChargedOnAdapter,
                          clock: FakeWattClock(now: PowerReading.sampleChargedOnAdapter.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.3"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c043-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C044FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 221, y: 5, width: 80, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleChargerInput,
                          clock: FakeWattClock(now: PowerReading.sampleChargerInput.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.4"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c044-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C045FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 213, y: 5, width: 88, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleUnpluggedCharger,
                          clock: FakeWattClock(now: PowerReading.sampleUnpluggedCharger.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.5"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c045-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C046FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 221, y: 5, width: 80, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleDesktopSystemDraw,
                          clock: FakeWattClock(now: PowerReading.sampleDesktopSystemDraw.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.6"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c046-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C047FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 153, y: 5, width: 148, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .samplePerComponent,
                          clock: FakeWattClock(now: PowerReading.samplePerComponent.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.7"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c047-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C048FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 260, y: 5, width: 41, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .sampleCharging,
                          clock: FakeWattClock(now: PowerReading.sampleCharging.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.8"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c048-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C049FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = NSRect(x: 230, y: 5, width: 71, height: 24)
    static func makeStore() -> PowerReadingStore {
        PowerReadingStore(currentReading: .unavailable,
                          clock: FakeWattClock(now: PowerReading.unavailable.timestamp))
    }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.9"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c049-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C0410FixtureLaunch {
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = C041FixtureLaunch.itemRect
    static func makeStore() -> PowerReadingStore { PowerReadingStore.preview }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.10"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c0410-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C0411FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = C041FixtureLaunch.itemRect
    static func makeStore() -> PowerReadingStore { PowerReadingStore.preview }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.11"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c0411-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

@MainActor
enum C0412FixtureLaunch {
    static let appearanceName = NSAppearance.Name.aqua
    static let captureSize = C041FixtureLaunch.captureSize
    static let itemRect = C042FixtureLaunch.itemRect
    static func makeStore() -> PowerReadingStore { C042FixtureLaunch.makeStore() }
    static func matches(arguments: [String]) -> Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(arguments) {
            return selection.story.id == "C04.12"
        }
        return false
        #endif
    }
    static var requested: Bool { matches(arguments: ProcessInfo.processInfo.arguments) }
    static func captureRequested(arguments: [String]) -> Bool {
        matches(arguments: arguments) && arguments.contains("--watt-c0412-capture-directory")
    }
    static var captureRequested: Bool { captureRequested(arguments: ProcessInfo.processInfo.arguments) }
}

/// DEBUG capture counterpart of MenuBarExtra's system-owned selection lifecycle.
/// Public NSStatusBarButton highlighting only; never draws selected chrome.
@MainActor
final class C0410PanelSelection: NSObject, NSPopoverDelegate {
    let router: AppRouter
    let popover = NSPopover()
    private weak var button: NSStatusBarButton?

    init(button: NSStatusBarButton, router: AppRouter, preferences: PreferencesStore,
         store: PowerReadingStore) {
        self.button = button
        self.router = router
        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarRootView()
            .environmentObject(router).environmentObject(store).environmentObject(preferences))
        button.target = self
        button.action = #selector(togglePanel)
    }

    @objc func togglePanel() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        synchronizeSelection()
        // NSButton ends click tracking after dispatching its action and clears the
        // pressed highlight. Reapply native selection only if the panel stays open.
        DispatchQueue.main.async { [weak self] in self?.synchronizeSelection() }
    }

    func popoverDidClose(_ notification: Notification) { synchronizeSelection() }

    private func synchronizeSelection() {
        applySelection(isPresented: popover.isShown)
    }

    // Deterministic lifecycle seam; production capture supplies actual popover state.
    func applySelection(isPresented: Bool) {
        router.statusPanelPresented = isPresented
        button?.highlight(isPresented)
    }
}

#endif

#if DEBUG
@MainActor
enum C05FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "C05/base"
        }
        return false
        #endif
    }

    static func makePreferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.completed = true
        return preferences
    }

    static func makeWindow() -> NSWindow {
        let host = NSHostingView(rootView: SettingsRootView()
            .environmentObject(makePreferences())
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 1000),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Watt? Settings"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-c05-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 580,
                    pixelsHigh: 1000, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "C05/base", "appearance": "aqua", "locale": "en_US", "width": 580, "height": 1000,
                    "capture": "NSView.cacheDisplay; actual app-owned native form; titlebar excluded",
                    "storage": "fresh InMemoryStorage; fixed sampleCharging clock; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("C05 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif
