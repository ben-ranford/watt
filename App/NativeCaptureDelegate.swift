import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

#if DEBUG
/// Opt-in rendering harness only; absent from Release and inert on ordinary launches.
@MainActor
final class NativeCaptureDelegate: NSObject, NSApplicationDelegate {
    static let launchArgument = "--watt-capture-status-panel"
    static let windowTitle = "Watt F01 StatusPanel Capture"
    private var captureWindow: NSWindow?
    private var chargingStatusItem: NSStatusItem?
    private var chargingCaptureAnchor: StatusAnchorView?

    static func captureRequested(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func makeWindow(c01: Bool = false, c02: Bool = false) -> NSWindow {
        let panel = StatusPanelView(
            reading: c02 ? .sampleOnBattery : .sampleCharging,
            chargerDescription: c01 ? "96 W USB-C charger" : nil,
            onSettings: { C01FixtureLaunch.router?.showSettings() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.colorScheme, c01 ? .dark : .light)
        .frame(width: WattSpacing.panelWidth, height: c01 || c02 ? WattSpacing.panelHeight : nil)
        let hostingView = NSHostingView(rootView: panel)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.title = c02 ? "Watt C02 StatusPanel Capture" : c01 ? "Watt C01 StatusPanel Capture" : windowTitle
        window.appearance = NSAppearance(named: c01 ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        return window
    }

    static func makeGalleryWindow(colorScheme: ColorScheme, specimen: WattReferenceSpecimen.Kind? = nil) -> NSWindow {
        let content = specimen.map { AnyView(WattReferenceSpecimen(kind: $0, colorScheme: colorScheme)) }
            ?? AnyView(WattComponentGallery(colorScheme: colorScheme))
        let host = NSHostingView(rootView: content)
        let window = GalleryCaptureWindow(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.title = "Watt F02 Gallery " + (specimen.map { $0.rawValue + "-" } ?? "") + (colorScheme == .dark ? "dark" : "light")
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if J124FixtureLaunch.requested { J124FixtureLaunch.launch(); return }
        if J108FixtureLaunch.requested {
            captureWindow = J108FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J107FixtureLaunch.requested {
            captureWindow = J107FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J106FixtureLaunch.requested {
            captureWindow = J106FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J105FixtureLaunch.requested {
            captureWindow = J105FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J104FixtureLaunch.requested {
            captureWindow = J104FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        } else if J103FixtureLaunch.requested {
            captureWindow = J103FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if J102FixtureLaunch.requested {
            captureWindow = J102FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let arguments = ProcessInfo.processInfo.arguments
        if J17FixtureLaunch.requested {
            J17FixtureLaunch.launch()
            return
        }
        if J16FixtureLaunch.requested {
            captureWindow = J16FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let window = captureWindow { J16FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J15FixtureLaunch.requested {
            captureWindow = J15FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let window = captureWindow { J15FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J14FixtureLaunch.requested {
            captureWindow = J14FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J14FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J13FixtureLaunch.requested {
            captureWindow = J13FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J13FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J12FixtureLaunch.requested {
            captureWindow = J12FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J12FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J42FixtureLaunch.requested {
            captureWindow = J42FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J41FixtureLaunch.requested {
            captureWindow = J41FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J11FixtureLaunch.requested {
            captureWindow = J11FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { J11FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if J33FixtureLaunch.requested || J31FixtureLaunch.requested {
            captureWindow = J33FixtureLaunch.requested ? J33FixtureLaunch.makeWindow() : J31FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J25FixtureLaunch.requested {
            J25FixtureLaunch.launch()
            return
        }
        if J24FixtureLaunch.requested {
            captureWindow = J24FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if J23FixtureLaunch.requested {
            captureWindow = J23FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        if C05FixtureLaunch.requested {
            captureWindow = C05FixtureLaunch.makeWindow()
            captureWindow?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = captureWindow { C05FixtureLaunch.capture(window: window, arguments: arguments) }
            return
        }
        if C041FixtureLaunch.captureRequested || C042FixtureLaunch.captureRequested || C043FixtureLaunch.captureRequested || C044FixtureLaunch.captureRequested || C045FixtureLaunch.captureRequested || C046FixtureLaunch.captureRequested || C047FixtureLaunch.captureRequested || C048FixtureLaunch.captureRequested || C049FixtureLaunch.captureRequested || C0410FixtureLaunch.captureRequested || C0411FixtureLaunch.captureRequested || C0412FixtureLaunch.captureRequested {
            // MenuBarExtra is suppressed only for this opt-in harness. This is a
            // real app-owned NSStatusItem with the production SwiftUI label.
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.displayMode = C048FixtureLaunch.requested ? .iconOnly : C047FixtureLaunch.requested ? .components : C046FixtureLaunch.requested ? .draw : (C044FixtureLaunch.requested || C045FixtureLaunch.requested) ? .charger : .delta
            preferences.showSymbol = !C047FixtureLaunch.requested
            preferences.onboarding.completed = true
            let store = C049FixtureLaunch.requested ? C049FixtureLaunch.makeStore() : C048FixtureLaunch.requested ? C048FixtureLaunch.makeStore() : C047FixtureLaunch.requested ? C047FixtureLaunch.makeStore() : C046FixtureLaunch.requested ? C046FixtureLaunch.makeStore() : C045FixtureLaunch.requested ? C045FixtureLaunch.makeStore() : C044FixtureLaunch.requested ? C044FixtureLaunch.makeStore() : C043FixtureLaunch.requested ? C043FixtureLaunch.makeStore() : (C042FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C042FixtureLaunch.makeStore() : PowerReadingStore.preview
            let width = C049FixtureLaunch.requested ? C049FixtureLaunch.itemRect.width : C048FixtureLaunch.requested ? C048FixtureLaunch.itemRect.width : C047FixtureLaunch.requested ? C047FixtureLaunch.itemRect.width : C046FixtureLaunch.requested ? C046FixtureLaunch.itemRect.width : C045FixtureLaunch.requested ? C045FixtureLaunch.itemRect.width : C044FixtureLaunch.requested ? C044FixtureLaunch.itemRect.width : C043FixtureLaunch.requested ? C043FixtureLaunch.itemRect.width : (C042FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C042FixtureLaunch.itemRect.width : C041FixtureLaunch.itemRect.width
            let item = NSStatusBar.system.statusItem(withLength: width)
            chargingStatusItem = item
            guard let button = item.button else { return }
            button.appearance = NSAppearance(named: (C0411FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C0411FixtureLaunch.appearanceName : .darkAqua)
            let label = NSHostingView(rootView:
                MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
                    .environment(\.colorScheme, (C0411FixtureLaunch.requested || C0412FixtureLaunch.requested) ? .light : .dark)
                    .frame(width: width, height: 24))
            label.frame = NSRect(x: 0, y: 0, width: width, height: 24)
            label.autoresizingMask = [.width, .height]
            button.addSubview(label)
            let anchor = StatusAnchorView()
            chargingCaptureAnchor = anchor
            anchor.captureChargingStatusItem(button: button)
            return
        }
        if C03FixtureLaunch.requested, arguments.contains("--watt-c03-capture-directory"),
           let preferences = C03FixtureLaunch.preferences {
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            let anchor = StatusAnchorView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            let router = AppRouter(updateService: FakeUpdateService())
            anchor.makeMenu = { StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true }) }
            anchor.install = { [weak anchor] in anchor?.openContextMenuFixture() }
            let window = NSWindow(contentRect: anchor.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = "C03 native menu capture anchor (not status-item evidence)"
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = anchor
            if let screen = NSScreen.main {
                window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 110,
                                              y: screen.visibleFrame.maxY - 100))
            }
            captureWindow = window
            window.orderFrontRegardless()
            return
        }
        let dark = arguments.contains("--watt-capture-gallery-dark")
        let light = arguments.contains("--watt-capture-gallery-light")
        guard Self.captureRequested(arguments: arguments) || dark || light || C01FixtureLaunch.requested || C02FixtureLaunch.requested else { return }
        let specimen = WattReferenceSpecimen.Kind.allCases.first { arguments.contains("--watt-specimen-" + $0.rawValue) }
        let window = dark || light ? Self.makeGalleryWindow(colorScheme: dark ? .dark : .light, specimen: specimen) : Self.makeWindow(c01: C01FixtureLaunch.requested, c02: C02FixtureLaunch.requested)
        if dark || light {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        captureWindow = window
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        if dark || light {
            DispatchQueue.main.async {
                window.makeKeyAndOrderFront(nil)
                @MainActor
                func focusField(in view: NSView) -> Bool {
                    if let field = view as? NSTextField, field.isEditable {
                        return window.makeFirstResponder(field)
                    }
                    return view.subviews.contains { focusField(in: $0) }
                }
                if let content = window.contentView { _ = focusField(in: content) }
            }
        }
    }
}
private final class GalleryCaptureWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
#endif
