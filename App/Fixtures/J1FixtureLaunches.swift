import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

#if DEBUG
@MainActor
enum J11FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.1/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(AppRouter())
            .environmentObject(preferences)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 308),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j11-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J1.1/base", "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned welcome content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; welcome checkpoint; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J11 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J12FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.2/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        let router = AppRouter()
        router.settingsHelperSetup.service = FakeHelperService()
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(router)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 346),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j12-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J1.2/base", "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned reading content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; picker checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J12 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J13FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.3/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .helperOffer
        let router = AppRouter()
        router.settingsHelperSetup.service = FakeHelperService()
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(router)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 412),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j13-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J1.3/base", "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned helper offer content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; helperOffer checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J13 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J14FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.4/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .approval
        let router = AppRouter()
        router.settingsHelperSetup.service = FakeHelperService()
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(router)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 224),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j14-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "title": WaitingForApprovalView.title, "body": WaitingForApprovalView.message,
                    "fixture": "J1.4/base", "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned waiting for approval content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; approval checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "systemNotification": "Unavailable: system-owned surface excluded by safe app-owned capture/TCC",
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J14 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J15FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.5/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .preview
        let router = AppRouter()
        router.settingsHelperSetup.service = FakeHelperService()
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(router)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 364),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j15-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "rows": ComponentPreviewView.componentNames.map {
                        $0 + " " + ComponentPreviewView.value(for: $0, reading: .sampleCharging)
                    },
                    "fixture": "J1.5/base", "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned component preview content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; preview checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J15 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J16FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.6/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .allSet
        let host = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(PowerReadingStore.preview)
            .environmentObject(preferences)
            .environmentObject(AppRouter())
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 328),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    static func capture(window: NSWindow, arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--watt-j16-capture-directory"),
              index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let view = window.contentView else { throw ServiceFailure.invalidData }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
                    pixelsHigh: Int(view.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "title": AllSetView.title, "body": AllSetView.message, "openAtLogin": false,
                    "fixture": "J1.6/base", "appearance": "aqua", "locale": "en_US", "width": Int(view.bounds.width), "height": Int(view.bounds.height),
                    "capture": "NSView.cacheDisplay; actual app-owned all-set content; native titlebar not assessed",
                    "storage": "fresh InMemoryStorage; allSet checkpoint; Delta selected; fixed preview telemetry; no live services",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "visualPass": false, "limitation": "Native system metrics. AX/VoiceOver not audited."
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J16 capture failed: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J17FixtureLaunch {
    private static var statusItem: NSStatusItem?
    private static var coachMark: NSPopover?
    private static var panel: C0410PanelSelection?

    static func launch() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding = .init(checkpoint: .coachMark, completed: true)
        let router = AppRouter()
        let item = NSStatusBar.system.statusItem(withLength: 96)
        statusItem = item
        guard let button = item.button else { return }
        let label = NSHostingView(rootView: MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences))
        label.frame = button.bounds
        label.autoresizingMask = [.width, .height]
        button.addSubview(label)
        MenuBarStatusAccessibility.apply(to: button, label: MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences))
        let popover = CoachMarkView.makePopover(preferences: preferences, router: router)
        coachMark = popover
        let selection = C0410PanelSelection(button: button, router: router, preferences: preferences, store: .preview)
        panel = selection
        router.present = { destination in
            if destination == .statusPanel { popover.close(); selection.togglePanel() }
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if button.window != nil {
                popover.show(relativeTo: NSRect(x: button.bounds.maxX - 1, y: button.bounds.minY,
                    width: 1, height: button.bounds.height), of: button, preferredEdge: .minY)
            }
            capture(popover: popover, button: button)
        }
    }

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.7/base"
        }
        return false
        #endif
    }

    static func capture(popover: NSPopover, button: NSStatusBarButton) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j17-capture-directory"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let contentView = popover.contentViewController?.view
                var fallbackWindow: NSWindow?
                if !popover.isShown {
                    // A host may expose no compositor window for a status item.
                    // Anchor the real NSPopover to a temporary native AppKit
                    // view only for capture. This keeps the popover chrome and
                    // arrow OS-owned; the temporary anchor is not product UI.
                    let host = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
                                       styleMask: .borderless, backing: .buffered, defer: false)
                    host.isOpaque = false
                    host.backgroundColor = .clear
                    host.appearance = NSAppearance(named: .aqua)
                    let anchor = NSView(frame: NSRect(x: 296, y: 8, width: 24, height: 24))
                    host.contentView = anchor
                    if let screen = NSScreen.main?.visibleFrame {
                        host.setFrameOrigin(NSPoint(x: screen.maxX - host.frame.width - 32,
                                                     y: screen.maxY - host.frame.height - 32))
                    }
                    host.orderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
                    fallbackWindow = host
                }
                // A menu-bar-only fixture may not receive a compositor window on
                // a host that cannot materialise third-party status items. Keep
                // the app-owned content capture useful without fabricating the
                // popover chrome: size the real hosting view to NSPopover's
                // native content size before asking AppKit to rasterize it.
                if let contentView, contentView.bounds.size == .zero {
                    contentView.setFrameSize(popover.contentSize)
                    contentView.layoutSubtreeIfNeeded()
                }
                for (name, view) in [("actual-content", contentView), ("actual-status-item", button as NSView?)] {
                    guard let view else { throw ServiceFailure.invalidData }
                    view.layoutSubtreeIfNeeded()
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ServiceFailure.invalidData }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                    try png.write(to: directory.appendingPathComponent(name + ".png"))
                }
                let metadata: [String: Any] = ["fixture": "J1.7/base",
                "popoverShown": popover.isShown, "actualStatusButton": true,
                    "capture": "cacheDisplay of real DEBUG NSStatusItem button and production NSPopover content; no relocation; not live MenuBarExtra interaction",
                    "contentFallback": fallbackWindow != nil ? "temporary native AppKit anchor; actual NSPopover chrome" : "none",
                    "storage": "InMemoryStorage; completed coachMark; fixed preview telemetry",
                    "visualPass": false, "liveInteractionVerified": false]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch { FileHandle.standardError.write(Data("J17 capture failed: \(error)\n".utf8)) }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J18FixtureLaunch {
    private static var statusItem: NSStatusItem?
    private static var selection: C0410PanelSelection?
    private static var anchorWindow: NSWindow?

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J1.8/base"
        }
        return false
        #endif
    }

    static func launch(preferences: PreferencesStore, store: PowerReadingStore, router: AppRouter) {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: 96)
        statusItem = item
        guard let button = item.button else { return }
        let label = NSHostingView(rootView: MenuBarStatusLabel(reading: store.statusReading, preferences: preferences))
        label.frame = button.bounds
        label.autoresizingMask = [.width, .height]
        button.addSubview(label)
        MenuBarStatusAccessibility.apply(to: button,
                                         label: MenuBarStatusLabel(reading: store.statusReading, preferences: preferences))
        let panel = C0410PanelSelection(button: button, router: router, preferences: preferences, store: store)
        selection = panel
        router.present = { destination in
            if destination == .statusPanel { panel.togglePanel() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Some verification hosts expose the status-item window but do
            // not expose the attached popover to the compositor. Anchor the
            // same real NSPopover to a temporary native AppKit view for this
            // DEBUG-only fixture so the panel itself can be captured without
            // replacing its native surface with custom chrome.
            let host = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
                               styleMask: .borderless, backing: .buffered, defer: false)
            NSApp.setActivationPolicy(.regular)
            host.isReleasedWhenClosed = false
            host.isOpaque = false
            host.backgroundColor = .clear
            host.appearance = NSAppearance(named: .aqua)
            let anchor = NSView(frame: NSRect(x: 296, y: 8, width: 24, height: 24))
            host.contentView = anchor
            if let screen = NSScreen.main?.visibleFrame {
                host.setFrameOrigin(NSPoint(x: screen.maxX - host.frame.width - 32,
                                             y: screen.maxY - host.frame.height - 32))
            }
            host.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            panel.popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            panel.applySelection(isPresented: true)
            anchorWindow = host
        }
    }
}

/// Captures only the live MenuBarExtra content after attachment to its real window.
/// No replacement window, fabricated status item, or offscreen rendering fallback.
struct J18PanelCaptureView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let arguments = ProcessInfo.processInfo.arguments
        let voiceOrder = J111FixtureLaunch.requested
        let lost = J32FixtureLaunch.requested
        let off = lost || J22FixtureLaunch.requested
        let height = Int(off ? WattSpacing.panelComponentsOffHeight : WattSpacing.panelHeight)
        let captureFlag = voiceOrder ? "--watt-j111-capture-directory" : lost ? "--watt-j32-capture-directory" : off ? "--watt-j22-capture-directory" : "--watt-j18-capture-directory"
        guard let index = arguments.firstIndex(of: captureFlag),
              index + 1 < arguments.count else { return view }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak view] in
            do {
                guard let view, let window = view.window, window.isVisible,
                      let content = window.contentView,
                      view.bounds.size == NSSize(width: WattSpacing.panelWidth, height: CGFloat(height)) else { throw ServiceFailure.invalidData }
                content.layoutSubtreeIfNeeded()
                let rect = view.convert(view.bounds, to: content)
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(WattSpacing.panelWidth),
                    pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                content.cacheDisplay(in: rect, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ServiceFailure.invalidData }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = ["fixture": voiceOrder ? "J11.1/base" : lost ? "J3.2/base" : off ? "J2.2/base" : "J1.8/base", "width": Int(WattSpacing.panelWidth), "height": height, "appearance": voiceOrder || lost ? "darkAqua" : "aqua",
                    "capture": "cacheDisplay of attached real MenuBarExtra content; native chrome excluded",
                    "windowNumber": window.windowNumber, "visualPass": false,
                    "storage": "InMemoryStorage; completed livePanel; fixed charging telemetry",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch { FileHandle.standardError.write(Data("Live panel capture blocked: \(error)\n".utf8)) }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
