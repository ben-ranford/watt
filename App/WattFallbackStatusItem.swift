import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Public AppKit fallback for hosts where SwiftUI's MenuBarExtra scene does not
/// register a visible status item. It deliberately uses the native status button
/// and NSPopover; no custom menu-bar chrome or pixel drawing is introduced.
@MainActor
final class WattFallbackStatusItem: NSObject, NSPopoverDelegate {
    private let router: AppRouter
    private let powerStore: PowerReadingStore
    private let preferences: PreferencesStore
    private var item: NSStatusItem?
    private var panel: NSPopover?
    private var fallbackWindow: NSWindow?
    private var contextMenuMonitor: Any?
    private var wakeObserver: NSObjectProtocol?
    private var powerStateObserver: NSObjectProtocol?
    private var observations = Set<AnyCancellable>()
    private var samplingTask: Task<Void, Never>?
    private var buttonUpdateScheduled = false
    /// Widest text width shown since the display mode, precision, unit, or font changed.
    private var textHighWater: CGFloat = 0
    private var widthIdentity: MenuBarStatusWidthIdentity?

    init(router: AppRouter, powerStore: PowerReadingStore, preferences: PreferencesStore) {
        self.router = router
        self.powerStore = powerStore
        self.preferences = preferences
        super.init()
    }

    func install() {
        guard item == nil else { return }
        // SwiftUI Window scenes can promote an LSUIElement process to the
        // regular activation policy during launch. Restore the native agent
        // policy before creating the status item so AppKit assigns it a real
        // menu-bar slot instead of a zero-height NSStatusBarWindow.
        NSApp.setActivationPolicy(.accessory)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        item = statusItem
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp])
        button.font = MenuBarStatusFont.menuBar()
        updateButton()

        // The normal app deliberately suppresses MenuBarExtra because some
        // hosts do not materialise its status item. The fallback is therefore
        // also the owner of the production sampling task; attaching polling
        // only to the hidden SwiftUI label leaves the visible widget at “—”.
        // Install the policy first so the component loop does not arm a timer
        // before it knows the panel is hidden.
        powerStore.setComponentSamplingPolicy { [weak self] in
            self?.componentSamplingNeeded ?? false
        }
        startSampling()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.powerStore.observesSystemWake else { return }
                self.powerStore.handleWake()
                await self.powerStore.refresh()
            }
        }
        powerStateObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleButtonUpdate()
            }
        }

        contextMenuMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            guard let self, let button = self.item?.button,
                  event.window === button.window,
                  button.frame.contains(event.locationInWindow),
                  event.type == .rightMouseDown || event.modifierFlags.contains(.control) else { return event }
            let menu = StatusItemContextMenu.makeMenu(router: self.router,
                preferences: self.preferences,
                componentsAvailable: {
                    !self.router.settingsHelperSetup.helperSwitchedOff
                        && !self.powerStore.availableComponentIDs.isEmpty
                })
            button.highlight(true)
            defer {
                StatusItemContextMenu.endPresentation(menu)
                button.highlight(false)
            }
            NSMenu.popUpContextMenu(menu, with: event, for: button)
            return nil
        }

        router.present = { [weak self] destination in
            switch destination {
            case .statusPanel: self?.togglePanel()
            case .coachMark: self?.togglePanel()
            case .settings:
                guard let self else { return }
                // The AppKit fallback is used when MenuBarExtra has not
                // materialised. In that mode macOS can report
                // `showSettingsWindow:` as handled without creating the
                // SwiftUI Settings scene, leaving the panel apparently dead.
                // Present the same native SettingsRootView directly instead.
                self.closePanel()
                self.showFallbackWindow(title: SettingsRootView.title,
                                        size: NSSize(width: WattSpacing.settingsWidth,
                                                     height: WattSpacing.settingsContentHeight),
                                        content: SettingsRootView()
                                            .environmentObject(self.router)
                                            .environmentObject(self.powerStore)
                                            .environmentObject(self.preferences))
            case .onboarding:
                guard let self else { return }
                self.showFallbackWindow(title: "Watt? Setup", fitContent: true, content: OnboardingFlowView()
                    .environmentObject(self.router)
                    .environmentObject(self.powerStore)
                    .environmentObject(self.preferences))
            case .softwareUpdate:
                guard let self else { return }
                let window = SoftwareUpdateWindowMetrics.makeWindow(
                    content: UpdateRootView(softwareUpdate: true).environmentObject(self.router))
                window.center()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                self.fallbackWindow?.close()
                self.fallbackWindow = window
            case .update:
                guard let self else { return }
                self.showFallbackWindow(title: "Watt? Update", content: UpdateRootView()
                    .environmentObject(self.router)
                    .environmentObject(self.powerStore)
                    .environmentObject(self.preferences))
            case .whatsNew:
                guard let self else { return }
                self.showFallbackWindow(title: "What’s New", fitContent: true, content: WhatsNewScene()
                    .environmentObject(self.router))
            }
        }

        powerStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleButtonUpdate() }
            .store(in: &observations)
        powerStore.$currentReading
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await PowerNotificationDelivery.deliver(store: self.powerStore, router: self.router) }
            }
            .store(in: &observations)
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleButtonUpdate() }
            .store(in: &observations)

        // The fallback status item owns sampling on the production host. Its
        // Task is outside SwiftUI's task(id:) lifecycle, so restart it when the
        // native Settings picker changes instead of waiting for the old sleep
        // interval to expire.
        preferences.$updateInterval
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.startSampling() }
            }
            .store(in: &observations)
        preferences.$displayMode
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.powerStore.refreshComponentSamplingNeed() }
            }
            .store(in: &observations)
        preferences.$componentReadings
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.powerStore.refreshComponentSamplingNeed() }
            }
            .store(in: &observations)

        // The normal launch does not mount the SwiftUI status-item bridge, so
        // route persisted setup here after installing its presentation handler.
        router.startAutomaticUpdates(preferences: preferences)
        router.launch(preferences: preferences)
    }

    func uninstall() {
        samplingTask?.cancel()
        samplingTask = nil
        observations.removeAll()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        if let powerStateObserver { NotificationCenter.default.removeObserver(powerStateObserver) }
        powerStateObserver = nil
        if let contextMenuMonitor { NSEvent.removeMonitor(contextMenuMonitor) }
        contextMenuMonitor = nil
        panel?.close()
        panel = nil
        fallbackWindow?.close()
        fallbackWindow = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func togglePanel() {
        guard let button = item?.button else { return }
        if let panel, panel.isShown {
            panel.performClose(nil)
            router.statusPanelPresented = false
            powerStore.refreshComponentSamplingNeed()
            return
        }
        let popover = panel ?? NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let host = NSHostingController(rootView:
            MenuBarRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences))
        popover.contentViewController = host
        panel = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        host.view.layoutSubtreeIfNeeded()
        let fitted = host.view.fittingSize
        if fitted.height > 1 {
            popover.contentSize = NSSize(width: max(fitted.width, WattSpacing.panelWidth), height: fitted.height)
        }
        router.statusPanelPresented = true
        powerStore.refreshComponentSamplingNeed()
    }

    /// The popover is reused, but its SwiftUI tree is not. Leaving the hosting
    /// controller in place invalidates the hidden panel on every menu-bar sample.
    func popoverDidClose(_ notification: Notification) {
        if panel?.contentViewController != nil {
            panel?.contentViewController = nil
        }
        router.statusPanelPresented = false
        powerStore.refreshComponentSamplingNeed()
    }

    /// Component watts are visible in the open panel, and in the status item
    /// when that display mode is selected. Either one keeps the helper sampler.
    private var componentSamplingNeeded: Bool {
        guard preferences.componentReadings, !router.settingsHelperSetup.helperSwitchedOff else { return false }
        if router.statusPanelPresented { return true }
        return preferences.displayMode == .components
    }

    private func updateButton() {
        if let pair = powerStore.freshComponentEstimate {
            router.settingsHelperSetup.confirmRecoveredComponents(PowerReading.unavailable.presenting(pair))
        }
        guard let button = item?.button else { return }
        let font = MenuBarStatusFont.menuBar()
        button.font = font
        let label = MenuBarStatusLabel(reading: powerStore.statusReading,
                                       preferences: preferences,
                                       helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
        if let image = label.batteryStatusBarImage() {
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil)
        }
        let showsTitle = label.text != nil || label.percentagePlainTitle != nil
        button.imagePosition = label.showsSymbol ? (showsTitle ? .imageLeading : .imageOnly) : .noImage
        button.title = label.text ?? ""
        if let percentTitle = label.percentagePlainTitle {
            button.title = percentTitle
        }
        // Shorter readings sit in the middle of the reserved width.
        (button.cell as? NSButtonCell)?.alignment = .center
        button.toolTip = label.accessibilityAnnouncement
        MenuBarStatusAccessibility.apply(to: button, label: label)
        button.sizeToFit()

        // The watt reading keeps its two-digit reserve. A percent shown on its
        // own has no watt text, so it reserves nothing for watts and leaves the
        // watt high-water alone for when the reading comes back.
        var wattSlack: CGFloat = 0
        if label.showsWattText {
            let identity = label.statusWidthIdentity(font: font)
            let references = label.statusWidthReferences
            let title = label.text ?? ""
            let metrics = MenuBarFontMetrics.measuring(font, covering: [title] + references)
            let resolved = MenuBarStatusWidth.resolve(.init(
                displayed: title,
                references: references,
                metrics: metrics,
                highWater: textHighWater,
                keepHighWater: widthIdentity == identity
            ))
            textHighWater = resolved.highWater
            widthIdentity = identity
            wattSlack = resolved.textWidth - resolved.displayedTextWidth
        }
        // The percent keeps its own slot, wide enough for "100%". This slack is
        // separate from the watt-reading reserve, so 9%, 87% and 100% stay the same width.
        let percentSlack = label.percentageSlotSlack(font: font)
        let scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        item?.length = MenuBarStatusWidth.itemLength(
            intrinsicWidth: button.intrinsicContentSize.width,
            textSlack: wattSlack + percentSlack,
            scale: scale
        )
    }

    private func startSampling() {
        samplingTask?.cancel()
        let powerStore = self.powerStore
        let preferences = self.preferences
        samplingTask = Task { [powerStore, preferences] in
            await powerStore.runSampling(interval: { preferences.updateIntervalSeconds })
        }
    }

    /// `ObservableObject.objectWillChange` is emitted before an `@Published`
    /// value is assigned. Defer and coalesce the AppKit update so the native
    /// status item reads the completed snapshot rather than the previous one.
    private func scheduleButtonUpdate() {
        guard !buttonUpdateScheduled else { return }
        buttonUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.buttonUpdateScheduled = false
            self.updateButton()
        }
    }

    private func closePanel() {
        panel?.performClose(nil)
        panel = nil
        router.statusPanelPresented = false
    }

    private func showFallbackWindow<Content: View>(title: String,
                                                   size: NSSize = NSSize(width: 420, height: 560),
                                                   fitContent: Bool = false,
                                                   content: Content) {
        let host = NSHostingView(rootView: content)
        let resolved: NSSize
        if fitContent {
            let fitted = host.fittingSize
            let height = fitted.height > 1 ? fitted.height + 28 : 460
            resolved = NSSize(width: max(fitted.width, WattSpacing.onboardingWidth), height: height)
        } else {
            resolved = size
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: resolved),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = title
        if fitContent { window.identifier = NSUserInterfaceItemIdentifier("watt.onboarding") }
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        fallbackWindow?.close()
        fallbackWindow = window
    }
}
