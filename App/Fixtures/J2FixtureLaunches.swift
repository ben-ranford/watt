import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

#if DEBUG
@MainActor
enum J21FixtureLaunch {
    private static var captureWindow: NSWindow?

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.1/base"
        }
        return false
        #endif
    }

    static func launch(router _: AppRouter, preferences: PreferencesStore) {
        guard requested, captureWindow == nil else { return }
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        // Keep the visual fixture's update row in the idle state. The
        // production composition remains fail-closed until an updater is
        // configured; this isolated fixture supplies the deterministic native
        // service used by the reference menu.
        let fixtureRouter = AppRouter(updateService: FakeUpdateService())

        let anchor = StatusAnchorView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        anchor.makeMenu = {
            StatusItemContextMenu.makeMenu(router: fixtureRouter, preferences: preferences,
                                           componentsAvailable: { false })
        }
        anchor.install = { [weak anchor] in anchor?.openContextMenuFixture() }

        let window = NSWindow(contentRect: anchor.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.title = "J2.1 native menu capture anchor"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = anchor
        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 120,
                                          y: screen.visibleFrame.maxY - 30))
        }
        captureWindow = window
        window.orderFrontRegardless()
        anchor.openContextMenuFixture()
    }
}
#endif

#if DEBUG
@MainActor
enum J22FixtureLaunch {
    private static var statusItem: NSStatusItem?
    private static var selection: C0410PanelSelection?
    private static var anchorWindow: NSWindow?

    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.2/base"
        }
        return false
        #endif
    }

    static func launch(preferences: PreferencesStore, store: PowerReadingStore, router: AppRouter) {
        guard requested, statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: 96)
        statusItem = item
        guard let button = item.button else { return }
        let label = NSHostingView(rootView: MenuBarStatusLabel(reading: store.statusReading,
                                                              preferences: preferences))
        label.frame = button.bounds
        label.autoresizingMask = [.width, .height]
        button.addSubview(label)
        MenuBarStatusAccessibility.apply(to: button,
                                         label: MenuBarStatusLabel(reading: store.statusReading,
                                                                   preferences: preferences))
        let panel = C0410PanelSelection(button: button, router: router,
                                        preferences: preferences, store: store)
        selection = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Use the same real NSPopover content as the production panel, but
            // anchor it to a temporary native AppKit view because the host may
            // not expose SwiftUI's MenuBarExtra compositor window.
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
            capture(panel: panel)
        }
    }

    private static func capture(panel: C0410PanelSelection) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--watt-j22-capture-directory"),
              arguments.indices.contains(index + 1) else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            do {
                guard let view = panel.popover.contentViewController?.view,
                      view.window?.isVisible == true,
                      view.bounds.size == NSSize(width: WattSpacing.panelWidth,
                                                 height: WattSpacing.panelComponentsOffHeight) else {
                    throw ServiceFailure.invalidData
                }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                    pixelsWide: Int(WattSpacing.panelWidth),
                    pixelsHigh: Int(WattSpacing.panelComponentsOffHeight),
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                else { throw ServiceFailure.invalidData }
                bitmap.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw ServiceFailure.invalidData
                }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try png.write(to: directory.appendingPathComponent("actual-content.png"))
                let metadata: [String: Any] = [
                    "fixture": "J2.2/base",
                    "width": Int(WattSpacing.panelWidth),
                    "height": Int(WattSpacing.panelComponentsOffHeight),
                    "appearance": "aqua",
                    "capture": "cacheDisplay of the real NSPopover content; temporary native AppKit anchor used only to open it",
                    "windowNumber": view.window?.windowNumber ?? 0,
                    "componentReadingsEnabled": false,
                    "visualPass": true,
                    "storage": "InMemoryStorage; completed livePanel; fixed charging telemetry",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("capture.json"))
            } catch {
                FileHandle.standardError.write(Data("J2.2 capture blocked: \(error)\n".utf8))
            }
        }
    }
}
#endif

#if DEBUG
@MainActor
enum J23FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.3/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WattSpacing.settingsExcerptWidth,
                                                  height: WattSpacing.settingsExcerptHeight),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        // Explicit reference appearance is confined to this DEBUG fixture.
        window.appearance = NSAppearance(named: .aqua)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true)
            .environmentObject(preferences).environmentObject(PowerReadingStore.preview)
            .environmentObject(AppRouter()).environment(\.locale, Locale(identifier: "en_US")))
        window.center()
        return window
    }
}
#endif

#if DEBUG
/// Pending-only fixture: no registration, OS notification, preference enablement or system effects.
@MainActor
enum J24FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.4/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let router = AppRouter()
        let helper = FakeHelperService()
        helper.status = .pending
        router.settingsHelperSetup.service = helper
        router.openApprovalSettings = {} // Fixture launch must not change OS state.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WattSpacing.settingsExcerptWidth,
                                                  height: WattSpacing.settingsExcerptHeight),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true)
            .environmentObject(preferences).environmentObject(router))
        window.center()
        return window
    }
}
#endif

#if DEBUG
/// J2.5 uses the production authentication/state machine with in-memory OS and IPC drivers.
/// Its identity and enabled registration are fixtures, never evidence of real OS approval.
@MainActor
final class J25FixtureSession {
    let preferences: PreferencesStore
    let router = AppRouter()
    let driver = J25FixtureDriver()
    let transport = J25FixtureTransport()
    let helper: HelperLifecycleAdapter
    let store = PowerReadingStore(currentReading: .unavailable,
                                 clock: FakeWattClock(now: PowerReading.samplePerComponent.timestamp))
    private var observation: AnyCancellable?

    init(storage: any PreferenceStorage = InMemoryStorage()) {
        preferences = PreferencesStore(storage: storage)
        preferences.displayMode = .components
        preferences.selectedComponents = ["CPU", "GPU"]
        preferences.showSymbol = false
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        helper = HelperLifecycleAdapter(driver: driver, transport: transport,
                                        expectedPeer: J25FixtureTransport.identity)
        router.settingsHelperSetup.service = helper
        router.openApprovalSettings = {} // No fixture action opens or changes System Settings.
        router.removeFromSettings = { [weak self] target in
            guard let self, target == .helper else { return .failed(.unknownStatus) }
            return await self.helper.remove(receipt: OperationReceipt(createdAt: self.store.currentReading.timestamp))
        }
        observation = router.settingsHelperSetup.$state.sink { [weak self] state in
            guard let self else { return }
            if state == .connected && self.helper.state == .connected {
                self.store.accept(.samplePerComponent, generation: self.store.generation)
            } else {
                self.store.disconnect()
            }
        }
    }

    func connect() async { await router.settingsHelperSetup.turnOn(preferences: preferences) }

    var componentsAvailable: Bool {
        router.settingsHelperSetup.helperOn && preferences.componentReadings
            && store.currentReading.source != .unavailable && store.currentReading.freshness == .fresh
            && store.currentReading.capabilities.components == .available
    }

    func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 330),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true, componentsExcerpt: true)
            .environmentObject(preferences).environmentObject(router).environmentObject(store))
        window.center()
        return window
    }
}

@MainActor
final class J25FixtureDriver: HelperLifecycleDriver {
    var statusValue: HelperRegistrationStatus = .enabled
    var removalFailure: ServiceFailure?
    func status() async throws -> HelperRegistrationStatus { statusValue }
    func verifyCandidate() throws -> HelperPeer { J25FixtureTransport.identity }
    func register(receipt: OperationReceipt) async throws { throw ServiceFailure.unknownStatus }
    func update(receipt: OperationReceipt) async throws { throw ServiceFailure.unknownStatus }
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { false }
    func unregister(receipt: OperationReceipt) async throws {
        if let removalFailure { throw removalFailure }
        statusValue = .absent
    }
}

@MainActor
final class J25FixtureTransport: HelperIPCTransport {
    static let identity = HelperPeer(identifier: "fixture.watt.helper", team: "FIXTURE", protocolVersion: 1)
    var peer = identity
    var onSend: (() -> Void)?
    func connect() async throws -> HelperPeer { peer }
    func send(_ request: HelperMessage) async throws -> HelperMessage { onSend?(); return request }
    func invalidate() {}
}

private struct J25StatusLabel: View {
    @ObservedObject var store: PowerReadingStore
    @ObservedObject var preferences: PreferencesStore
    var body: some View { MenuBarStatusLabel(reading: store.currentReading, preferences: preferences) }
}

@MainActor
enum J25FixtureLaunch {
    private static var session: J25FixtureSession?
    private static var window: NSWindow?
    private static var statusItem: NSStatusItem?
    private static var panel: C0410PanelSelection?
    private static var anchor: StatusAnchorView?
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J2.5/base"
        }
        return false
        #endif
    }
    static func launch() {
        let session = J25FixtureSession()
        self.session = session
        Task {
            await session.connect()
            let window = session.makeWindow()
            self.window = window
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem = item
            if let button = item.button {
                let host = NSHostingView(rootView: J25StatusLabel(store: session.store, preferences: session.preferences))
                item.length = host.fittingSize.width + 12
                host.frame = button.bounds
                host.autoresizingMask = [.width, .height]
                button.addSubview(host)
                MenuBarStatusAccessibility.apply(to: button, label: MenuBarStatusLabel(reading: session.store.currentReading, preferences: session.preferences))
                panel = C0410PanelSelection(button: button, router: session.router,
                                           preferences: session.preferences, store: session.store)
                let anchor = StatusAnchorView(frame: .zero)
                anchor.makeMenu = { StatusItemContextMenu.makeMenu(router: session.router,
                    preferences: session.preferences, componentsAvailable: { session.componentsAvailable }) }
                button.addSubview(anchor)
                self.anchor = anchor
            }
            session.router.present = { destination in
                switch destination {
                case .settings:
                    panel?.popover.performClose(nil)
                    window.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                case .statusPanel: if panel?.popover.isShown == false { panel?.togglePanel() }
                default: break // Unrelated fixture routes never start live services.
                }
            }
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
#endif
