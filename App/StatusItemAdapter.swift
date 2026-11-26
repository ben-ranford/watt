import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Uses the existing MenuBarExtra's button; never allocates another NSStatusItem.
struct StatusItemAdapter: NSViewRepresentable {
    let router: AppRouter
    let preferences: PreferencesStore
    let powerStore: PowerReadingStore
    let applicationDelegate: WattApplicationDelegate
    let openWindow: OpenWindowAction
    let openSettings: () -> Void

    func makeNSView(context: Context) -> StatusAnchorView {
        let view = StatusAnchorView()
        view.updateAccessibility = { [weak view] in
            view?.updateAccessibility(reading: powerStore.statusReading, preferences: preferences,
                                      helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
        }
        view.install = { [weak view] in
            guard let view, !applicationDelegate.isTerminating else { return }
            router.present = { [weak view] destination in
                switch destination {
                case .coachMark:
                    view?.showCoachMark(preferences: preferences, router: router)
                case .statusPanel:
                    view?.closeCoachMark()
                    if !router.statusPanelPresented { view?.openPanel() }
                case .onboarding:
                    view?.closeCoachMark()
                    openWindow(id: "onboarding")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .settings:
                    openSettings()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .softwareUpdate:
                    openWindow(id: "software-update")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .update:
                    openWindow(id: "update")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .whatsNew:
                    openWindow(id: "whats-new")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            WattIntentSession.notePresenterReady()
            router.statusItemButton = { [weak view] in view?.statusButton }
            applicationDelegate.onTerminate = { [weak view] in
                router.leftoverHelper?.close()
                router.present = { _ in }
                router.statusItemButton = { nil }
                router.statusPanelPresented = false
                view?.tearDown()
            }
            applicationDelegate.onReopen = {
                router.reopen(preferences: preferences)
            }
            view.makeMenu = { StatusItemContextMenu.makeMenu(router: router, preferences: preferences,
                componentsAvailable: { !router.settingsHelperSetup.helperSwitchedOff && !powerStore.availableComponentIDs.isEmpty }) }
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if J93FixtureLaunch.requested {
                J93FixtureLaunch.observeAndQuit(menu: view.makeMenu?(), button: view.statusButton)
                return
            }
            if J51FixtureLaunch.requested {
                router.showCoachMark()
                return
            }
            if J82FixtureLaunch.requested {
                Task {
                    await J82FixtureLaunch.prepare(router: router, store: powerStore)
                    view.observeJ82StatusFixture(reading: powerStore.statusReading,
                                                 preferences: preferences, router: router)
                }
                return
            }
            if J125FixtureLaunch.requested {
                Task {
                    await J125FixtureLaunch.prepare(router: router, preferences: preferences)
                    J125FixtureLaunch.observe(preferences: preferences)
                    router.present(.settings)
                }
                return
            }
            if J92FixtureLaunch.requested {
                Task {
                    await J92FixtureLaunch.prepare(router: router, preferences: preferences)
                    J92FixtureLaunch.observe(preferences: preferences)
                    router.launch(preferences: preferences)
                }
                return
            }
            if (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested) {
                // No installed removal effects, even if confirmation is exercised in a fixture.
                router.removeFromSettings = { _ in .cancelled }
                if J113FixtureLaunch.requested {
                    J113FixtureLaunch.observe(preferences: preferences, button: view.statusButton)
                } else if J122FixtureLaunch.requested {
                    J122FixtureLaunch.observe(preferences: preferences, button: view.statusButton)
                } else {
                    J121FixtureLaunch.observe(preferences: preferences, button: view.statusButton)
                }
                router.launch(preferences: preferences)
                return
            }
            if J91FixtureLaunch.requested {
                Task {
                    await J91FixtureLaunch.prepare(router: router)
                    J91FixtureLaunch.observe(preferences: preferences)
                    router.launch(preferences: preferences)
                }
                return
            }
            if J83FixtureLaunch.requested {
                J83FixtureLaunch.observe(preferences: preferences)
                router.launch(preferences: preferences)
                return
            }
            if J112FixtureLaunch.requested {
                Task {
                    J112FixtureLaunch.observe(preferences: preferences)
                    router.launch(preferences: preferences)
                }
                return
            }
            if J81FixtureLaunch.requested {
                Task {
                    await J81FixtureLaunch.prepare(router: router)
                    router.showStatusPanel()
                    view.observeJ81StatusFixture(router: router)
                }
                return
            }
            if J73FixtureLaunch.requested {
                Task {
                    await J73FixtureLaunch.prepare(router: router)
                    router.showSettings()
                    J73FixtureLaunch.openComponentsMenu()
                }
                return
            }
            if J74FixtureLaunch.requested {
                Task {
                    await J74FixtureLaunch.prepare(router: router)
                    view.observeJ74StatusFixture(reading: powerStore.statusReading, preferences: preferences)
                }
                return
            }
            if J72FixtureLaunch.requested {
                view.observeJ72StatusFixture(reading: powerStore.statusReading, preferences: preferences)
                return
            }
            if J71FixtureLaunch.requested {
                Task {
                    await J71FixtureLaunch.prepare(router: router)
                    view.openJ71ContextMenuFixture()
                }
                return
            }
            if J53FixtureLaunch.requested || J21FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
                view.openContextMenuFixture()
                return
            }
            if J32FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                Task {
                    let helper = HelperLifecycleAdapter(driver: J25FixtureDriver(),
                        transport: J25FixtureTransport(), expectedPeer: J25FixtureTransport.identity)
                    router.settingsHelperSetup.service = helper
                    await router.settingsHelperSetup.turnOn(preferences: preferences)
                    helper.disconnect()
                    router.showStatusPanel()
                }
                return
            }
            if J111FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J111FixtureLaunch.appearanceName)
                router.showStatusPanel()
                return
            }
            if J65FixtureLaunch.requested || J64FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J61FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J61FixtureLaunch.appearanceName)
                if J64FixtureLaunch.requested {
                    Task {
                        _ = await J64FixtureLaunch.exerciseNotification(variant: J64FixtureLaunch.variant,
                            preferences: preferences, store: powerStore, router: router)
                        if arguments.contains("--watt-j64-probe-notification-authorization") {
                            let permission = await NativeNotificationDriver(center: .current()).permission()
                            FileHandle.standardOutput.write(Data("J6.4 live system authorization (read only): \(permission); no permission request or OS delivery attempted\n".utf8))
                        }
                    }
                }
                router.showStatusPanel()
                return
            }
            if J43FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                router.showStatusPanel()
                return
            }
            if J52FixtureLaunch.requested || J18FixtureLaunch.requested || J22FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
                if J18FixtureLaunch.requested {
                    J18FixtureLaunch.launch(preferences: preferences, store: powerStore, router: router)
                    return
                }
                if J22FixtureLaunch.requested {
                    J22FixtureLaunch.launch(preferences: preferences, store: powerStore, router: router)
                    return
                }
                router.showStatusPanel()
                return
            }
            if J17FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
                router.showCoachMark()
                return
            }
            if J42FixtureLaunch.requested || J41FixtureLaunch.requested || J16FixtureLaunch.requested || J15FixtureLaunch.requested || J14FixtureLaunch.requested || J13FixtureLaunch.requested || J12FixtureLaunch.requested || J11FixtureLaunch.requested || C05FixtureLaunch.requested || C01FixtureLaunch.requested || C02FixtureLaunch.requested || C03FixtureLaunch.requested || C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
                C01FixtureLaunch.router = router
                if C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
                    NSApplication.shared.appearance = NSAppearance(named: (C0411FixtureLaunch.requested || C0412FixtureLaunch.requested) ? C0411FixtureLaunch.appearanceName : .darkAqua)
                    view.captureChargingStatusItem()
                    if C0410FixtureLaunch.requested { router.showStatusPanel() }
                }
                if C03FixtureLaunch.requested && !arguments.contains("--watt-c03-capture-directory") {
                    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                    view.openContextMenuFixture()
                }
                return
            }
            if arguments.contains(where: { $0.hasPrefix("--watt-capture-") }) { return }
            #endif
            view.updateAccessibility?()
            Task {
                await router.presentLeftoverHelperAfterReinstall()
                router.startAutomaticUpdates(preferences: preferences)
                router.launch(preferences: preferences)
            }
        }
        return view
    }

    func updateNSView(_ nsView: StatusAnchorView, context: Context) {
        nsView.updateAccessibility(reading: powerStore.statusReading, preferences: preferences,
                                   helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
    }

    static func dismantleNSView(_ nsView: StatusAnchorView, coordinator: ()) {
        nsView.tearDown()
    }
}

final class StatusAnchorView: NSView {
    var install: (() -> Void)?
    var updateAccessibility: (() -> Void)?
    var makeMenu: (() -> NSMenu)?
    private var monitor: Any?
    private var coachMark: NSPopover?
    private var accessibilityAnnouncementGate = MenuBarAccessibilityAnnouncementGate()

    func updateAccessibility(reading: PowerReading, preferences: PreferencesStore, helperSwitchedOff: Bool) {
        guard let button = statusButton else { return }
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences,
                                       helperSwitchedOff: helperSwitchedOff)
        guard accessibilityAnnouncementGate.shouldAnnounce(stateKey: label.accessibilityStateKey, now: Date()) else { return }
        MenuBarStatusAccessibility.apply(to: button, label: label)
    }

    func showCoachMark(preferences: PreferencesStore, router: AppRouter) {
        guard CoachMarkView.canPresent(preferences.onboarding),
              coachMark?.isShown != true, let button = statusButton else { return }
        let popover = CoachMarkView.makePopover(preferences: preferences, router: router)
        coachMark = popover
        // AppKit owns arrow placement and screen-edge constraints; anchor to the real item.
        let anchor = NSRect(x: button.bounds.maxX - 1, y: button.bounds.minY, width: 1, height: button.bounds.height)
        popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
        #if DEBUG
        if J17FixtureLaunch.requested { J17FixtureLaunch.capture(popover: popover, button: button) }
        #endif
    }

    func closeCoachMark() { coachMark?.close(); coachMark = nil }

    func tearDown() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        closeCoachMark()
        install = nil
        makeMenu = nil
    }


    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
                guard let self, event.window === self.window,
                      event.type == .rightMouseDown || event.modifierFlags.contains(.control),
                      let menu = self.makeMenu?() else { return event }
                let button = self.statusButton
                button?.highlight(true)
                defer {
                    StatusItemContextMenu.endPresentation(menu)
                    button?.highlight(false)
                }
                #if DEBUG
                if J71FixtureLaunch.requested, let button {
                    J71FixtureLaunch.observeTracking(menu: menu, button: button)
                }
                #endif
                NSMenu.popUpContextMenu(menu, with: event, for: self)
                return nil
            }
        }
        // Wait until SwiftUI has installed the status button and scene actions.
        DispatchQueue.main.async { [weak self] in
            self?.install?()
            self?.updateAccessibility?()
        }
    }

    #if DEBUG
    private var chargingCaptureStarted = false
    private var chargingCaptureWindow: NSWindow?
    private var selectedPanel: C0410PanelSelection?

    /// Captures a real app-owned NSStatusBarButton containing the production label.
    /// The fixture temporarily relocates it into a deterministic, app-owned 560x44 host.
    func captureChargingStatusItem(button suppliedButton: NSStatusBarButton? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let lightOnBattery = C0412FixtureLaunch.requested
        let light = C0411FixtureLaunch.requested || lightOnBattery
        let selected = C0410FixtureLaunch.requested
        let unavailable = C049FixtureLaunch.requested
        let iconOnly = C048FixtureLaunch.requested
        let components = C047FixtureLaunch.requested
        let desktop = C046FixtureLaunch.requested
        let unplugged = C045FixtureLaunch.requested
        let charger = C044FixtureLaunch.requested
        let charged = C043FixtureLaunch.requested
        let onBattery = C042FixtureLaunch.requested || lightOnBattery
        let story = lightOnBattery ? "C04.12" : light ? "C04.11" : selected ? "C04.10" : unavailable ? "C04.9" : iconOnly ? "C04.8" : components ? "C04.7" : desktop ? "C04.6" : unplugged ? "C04.5" : charger ? "C04.4" : charged ? "C04.3" : onBattery ? "C04.2" : "C04.1"
        let captureFlag = lightOnBattery ? "--watt-c0412-capture-directory" : light ? "--watt-c0411-capture-directory" : selected ? "--watt-c0410-capture-directory" : unavailable ? "--watt-c049-capture-directory" : iconOnly ? "--watt-c048-capture-directory" : components ? "--watt-c047-capture-directory" : desktop ? "--watt-c046-capture-directory" : unplugged ? "--watt-c045-capture-directory" : charger ? "--watt-c044-capture-directory" : charged ? "--watt-c043-capture-directory" : onBattery ? "--watt-c042-capture-directory" : "--watt-c041-capture-directory"
        let itemRect = unavailable ? C049FixtureLaunch.itemRect : iconOnly ? C048FixtureLaunch.itemRect : components ? C047FixtureLaunch.itemRect : desktop ? C046FixtureLaunch.itemRect : unplugged ? C045FixtureLaunch.itemRect : charger ? C044FixtureLaunch.itemRect : charged ? C043FixtureLaunch.itemRect : onBattery ? C042FixtureLaunch.itemRect : C041FixtureLaunch.itemRect
        guard (C041FixtureLaunch.captureRequested || C042FixtureLaunch.captureRequested || C043FixtureLaunch.captureRequested || C044FixtureLaunch.captureRequested || C045FixtureLaunch.captureRequested || C046FixtureLaunch.captureRequested || C047FixtureLaunch.captureRequested || C048FixtureLaunch.captureRequested || C049FixtureLaunch.captureRequested || C0410FixtureLaunch.captureRequested || C0411FixtureLaunch.captureRequested || C0412FixtureLaunch.captureRequested), !chargingCaptureStarted,
              let index = arguments.firstIndex(of: captureFlag),
              arguments.indices.contains(index + 1) else { return }
        chargingCaptureStarted = true
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            do {
                guard let button = suppliedButton ?? self.statusButton else {
                    throw NSError(domain: "\(story) missing native status button", code: 1)
                }
                let originalFrame = button.frame
                let host: NSView
                if light {
                    let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: C041FixtureLaunch.captureSize))
                    material.material = .menu
                    material.blendingMode = .withinWindow
                    material.state = .active
                    host = material
                } else {
                    host = NSView(frame: NSRect(origin: .zero, size: C041FixtureLaunch.captureSize))
                }
                if !light {
                    host.wantsLayer = true
                    host.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
                }
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                                      backing: .buffered, defer: false)
                window.title = "\(story) actual status button, bounded capture"
                window.appearance = NSAppearance(named: light ? C0411FixtureLaunch.appearanceName : .darkAqua)
                window.isReleasedWhenClosed = false
                window.contentView = host
                self.chargingCaptureWindow = window
                button.removeFromSuperview()
                host.addSubview(button)
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: itemRect.minX),
                    button.topAnchor.constraint(equalTo: host.topAnchor, constant: itemRect.minY),
                    button.widthAnchor.constraint(equalToConstant: itemRect.width),
                    button.heightAnchor.constraint(equalToConstant: itemRect.height)
                ])
                window.orderFrontRegardless()
                if selected {
                    host.layoutSubtreeIfNeeded()
                    let preferences = PreferencesStore(storage: InMemoryStorage())
                    preferences.onboarding.completed = true
                    self.selectedPanel = C0410PanelSelection(button: button, router: AppRouter(),
                        preferences: preferences, store: C0410FixtureLaunch.makeStore())
                    button.performClick(nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    do {
                        host.layoutSubtreeIfNeeded()
                        window.displayIfNeeded()
                        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                            throw NSError(domain: "\(story) bitmap unavailable", code: 2)
                        }
                        host.cacheDisplay(in: host.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else {
                            throw NSError(domain: "\(story) PNG unavailable", code: 3)
                        }
                        try png.write(to: output.appendingPathComponent("actual-status-item.png"))
                        guard let bitmap1x = C041FixtureLaunch.captureBitmap1x(),
                              let context1x = NSGraphicsContext(bitmapImageRep: bitmap1x) else {
                            throw NSError(domain: "\(story) 1x context unavailable", code: 4)
                        }
                        // Public AppKit subtree drawing into a 1 pixel/point context.
                        // Do not resize the screen-scale cache or redraw label content ourselves.
                        host.displayIgnoringOpacity(host.bounds, in: context1x)
                        guard let png1x = bitmap1x.representation(using: .png, properties: [:]) else {
                            throw NSError(domain: "\(story) 1x PNG unavailable", code: 5)
                        }
                        try png1x.write(to: output.appendingPathComponent("actual-status-item-1x.png"))
                        var record: [String: Any] = [
                            "fixture": story + "/base",
                            "captureAPI": "NSView.cacheDisplay (screen-scale diagnostic); NSView.displayIgnoringOpacity(_:in:) (direct 1x)",
                            "bitmap1xPixels": [bitmap1x.pixelsWide, bitmap1x.pixelsHigh],
                            "bitmap1xPoints": [bitmap1x.size.width, bitmap1x.size.height],
                            "resampled": false,
                            "nativeItemHost": "DEBUG NSStatusItem; MenuBarExtra suppressed", "actualButtonClass": String(describing: type(of: button)),
                            "originalButtonFrame": NSStringFromRect(originalFrame),
                            "harnessPoints": [Int(C041FixtureLaunch.captureSize.width), Int(C041FixtureLaunch.captureSize.height)], "bitmapPixels": [bitmap.pixelsWide, bitmap.pixelsHigh],
                            "buttonFrame": NSStringFromRect(button.frame),
                            "appearance": button.effectiveAppearance.name.rawValue,
                            "selected": button.isHighlighted,
                            "customBackdrop": !light,
                            "limitations": light ? "Relocated native button; public Aqua appearance, no custom paint; no desktop/compositor pixels; not a visual pass." : "Relocated actual native button; synthetic dark backdrop; no compositor/desktop pixels; not a visual pass."
                        ]
                        if selected, let panel = self.selectedPanel {
                            record["panelShown"] = panel.popover.isShown
                            record["selectedWhileOpen"] = button.isHighlighted
                            record["routerPresentedWhileOpen"] = panel.router.statusPanelPresented
                            button.performClick(nil)
                            record["panelClosed"] = !panel.popover.isShown
                            record["unselectedAfterClose"] = !button.isHighlighted
                            record["routerDismissedAfterClose"] = !panel.router.statusPanelPresented
                            host.displayIgnoringOpacity(host.bounds, in: context1x)
                            try bitmap1x.representation(using: .png, properties: [:])?
                                .write(to: output.appendingPathComponent("closed-status-item-1x.png"))
                        }
                        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                            .write(to: output.appendingPathComponent("capture.json"))
                    } catch {
                        FileHandle.standardError.write(Data(("\(story) capture failed: \(error)\n").utf8))
                    }
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                FileHandle.standardError.write(Data(("\(story) capture failed: \(error)\n").utf8))
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Observe the actual native anchor in place; no menu/panel or replacement window.
    func observeJ72StatusFixture(reading: PowerReading, preferences: PreferencesStore) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusButton else { return }
            J72FixtureLaunch.observe(button: button, reading: reading, preferences: preferences)
        }
    }

    func observeJ81StatusFixture(router: AppRouter) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let button = self?.statusButton else { return }
            J81FixtureLaunch.observe(button: button, router: router)
        }
    }

    func observeJ82StatusFixture(reading: PowerReading, preferences: PreferencesStore, router: AppRouter) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let button = self?.statusButton else { return }
            J82FixtureLaunch.observe(button: button, router: router,
                                     reading: reading, preferences: preferences)
        }
    }

    func observeJ74StatusFixture(reading: PowerReading, preferences: PreferencesStore) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusButton else { return }
            J74FixtureLaunch.observe(button: button, reading: reading, preferences: preferences)
        }
    }

    /// Exercises the same secondary-click monitor as an ordinary status-item click.
    func openJ71ContextMenuFixture() {
        guard !fixtureOpened, let button = statusButton, let window = button.window else { return }
        fixtureOpened = true
        let location = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
        for type in [NSEvent.EventType.rightMouseDown, .rightMouseUp] {
            if let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
                NSApplication.shared.postEvent(event, atStart: false)
            }
        }
    }

    private var fixtureOpened = false
    private var fixtureMenu: NSMenu?
    func openContextMenuFixture() {
        guard !fixtureOpened, let menu = makeMenu?() else { return }
        fixtureOpened = true
        fixtureMenu = menu
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Native tracking, not a SwiftUI facsimile. No global event posting or AX.
            let arguments = ProcessInfo.processInfo.arguments
            let captureFlag = J21FixtureLaunch.requested ? "--watt-j21-capture-directory" : "--watt-c03-capture-directory"
            if J53FixtureLaunch.requested {
                J53FixtureLaunch.observeCapture(menu: menu)
            } else if let index = arguments.firstIndex(of: captureFlag),
               arguments.indices.contains(index + 1) {
                let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
                let expand = Timer(timeInterval: 0.2, repeats: false) { _ in
                    MainActor.assumeIsolated {
                        // Hover the parent using an app-local event, leaving Delta idle.
                        // AppKit owns submenu tracking and edge-aware placement.
                        if let window = NSApplication.shared.windows.first(where: {
                            $0.isVisible && !existing.contains(ObjectIdentifier($0))
                        }), let event = NSEvent.mouseEvent(with: .mouseMoved,
                            location: NSPoint(x: window.frame.width / 2, y: window.frame.height - 16),
                            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: window.windowNumber, context: nil,
                            eventNumber: 0, clickCount: 0, pressure: 0) {
                            NSApplication.shared.postEvent(event, atStart: true)
                        }
                    }
                }
                RunLoop.main.add(expand, forMode: .eventTracking)
                let timer = Timer(timeInterval: 1, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        let windows = NSApplication.shared.windows.filter {
                            $0.isVisible && !existing.contains(ObjectIdentifier($0))
                        }
                        var records: [[String: Any]] = []
                        for (index, window) in windows.enumerated() {
                            var record: [String: Any] = [
                                "class": String(describing: type(of: window)),
                                "frame": NSStringFromRect(window.frame),
                                "title": window.title,
                                "windowNumber": window.windowNumber
                            ]
                            if let view = window.contentView,
                               let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                                view.cacheDisplay(in: view.bounds, to: bitmap)
                                let name = "native-menu-\(index).png"
                                if let data = bitmap.representation(using: .png, properties: [:]) {
                                    do {
                                        try data.write(to: output.appendingPathComponent(name))
                                        record["capture"] = name
                                    } catch { record["error"] = String(describing: error) }
                                }
                            }
                            records.append(record)
                        }
                        let metadata: [String: Any] = [
                            "fixture": J53FixtureLaunch.requested ? "J5.3/base" : J21FixtureLaunch.requested ? "J2.1/base" : "C03/base",
                            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                            "windowOwnership": "NSApplication.shared.windows from this process",
                            "method": "app-owned NSView.cacheDisplay during native NSMenu tracking",
                            "appearance": (J53FixtureLaunch.requested || J21FixtureLaunch.requested) ? "aqua" : "darkAqua", "windows": records,
                            "parentHighlighted": self?.fixtureMenu?.highlightedItem === self?.fixtureMenu?.items.first,
                            "submenuHighlighted": self?.fixtureMenu?.items.first?.submenu?.highlightedItem?.title ?? "none",
                            "deltaChecked": self?.fixtureMenu?.items.first?.submenu?.items.first?.state == .on,
                            "checkForUpdatesEnabled": self?.fixtureMenu?.item(withTitle: "Check for Updates…")?.isEnabled ?? false,
                            "os": ProcessInfo.processInfo.operatingSystemVersionString,
                            "accessibility": "No AX, global event injection or TCC request",
                            "visualPass": false,
                            "limitation": "Only in-process menu views can be cached. System-hosted menu surfaces may be absent or blank."
                        ]
                        do {
                            try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                                .write(to: output.appendingPathComponent("capture-attempt.json"))
                        } catch { FileHandle.standardError.write(Data("Native menu capture failed: \(error)\n".utf8)) }
                        self?.fixtureMenu?.cancelTracking()
                    }
                }
                RunLoop.main.add(timer, forMode: .eventTracking)
            }
            let button = self.statusButton
            button?.highlight(true)
            defer {
                StatusItemContextMenu.endPresentation(menu)
                button?.highlight(false)
            }
            menu.popUp(positioning: menu.items.first, at: NSPoint(x: 0, y: -5), in: self)
        }
    }
    #endif

    fileprivate var statusButton: NSStatusBarButton? {
        func findButton(_ view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton { return button }
            return view.subviews.lazy.compactMap(findButton).first
        }
        return window?.contentView.flatMap(findButton)
    }

    func openPanel() {
        guard let button = statusButton else { return }
        // Defer until the context menu has ended its tracking loop.
        DispatchQueue.main.async { [weak self] in
            guard self?.window != nil, self?.makeMenu != nil else { return }
            button.performClick(nil)
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }
}
