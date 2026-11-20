import AppKit

/// Live objects for Shortcuts. The intents only read or call what is already running.
/// They do not start a sampler, a timer, or a second update client.
@MainActor
enum WattIntentSession {
    static weak var router: AppRouter?
    static weak var readings: PowerReadingStore?
    static weak var preferences: PreferencesStore?
    /// True after a scene has installed `router.present`. An LSUIElement launch can
    /// run an intent before that closure exists; the destination waits instead of
    /// calling the default no-op.
    private(set) static var presenterReady = false
    private static var pendingDestination: AppDestination?
    /// Production activates the accessory app. Tests replace this so they do not
    /// change the host app's activation policy.
    static var activateForIntent: @MainActor () -> Void = defaultActivation

    static func install(router: AppRouter, readings: PowerReadingStore, preferences: PreferencesStore) {
        self.router = router
        self.readings = readings
        self.preferences = preferences
    }

    static func resetForTests() {
        router = nil
        readings = nil
        preferences = nil
        presenterReady = false
        pendingDestination = nil
        activateForIntent = defaultActivation
        performingIntent = 0
        reopenTicket = 0
        quietUntil = nil
        reopenQuietNanoseconds = 400_000_000
        reopenSenderLookup = liveReopenSender
        reopenHasAppleEvent = { NSAppleEventManager.shared().currentAppleEvent != nil }
    }

    /// Shortcuts asks LinkDaemon which process will run the action. Announcing
    /// the running app is the public registration call. It does not install a
    /// helper or start a sampler. Ad-hoc builds may log a RunningBoard warning;
    /// that warning is not fatal and does not change the accessory policy.
    static func connectToShortcuts() {
        Task { @MainActor in
            WattShortcuts.updateAppShortcutParameters()
        }
    }

    static func notePresenterReady() {
        presenterReady = true
        guard let destination = pendingDestination else { return }
        pendingDestination = nil
        activate()
        deliver(destination)
    }

    /// The same snapshot the status panel shows. A stale or missing sample is the
    /// panel's unavailable reading, which has no watt values to turn into zero.
    static func currentReading() -> WattPowerReading {
        guard let readings else { return .unavailable }
        return WattPowerReading.make(from: readings.statusReading)
    }

    static var precision: WattPrecision { preferences?.precision ?? .decimal }

    /// Writes the mode the menu bar and Settings already read: `preferences.v1`,
    /// `displayMode` set to `WattDisplayMode.rawValue` (`Components`, not the
    /// Shortcuts label `Per Component`). The published change refreshes the
    /// status item on the next main-queue turn.
    static func setDisplayMode(_ mode: WattDisplayMode) throws {
        guard let preferences else { throw WattIntentFailure.notRunning }
        preferences.displayMode = mode
    }

    static func open(_ destination: AppDestination) throws {
        guard router != nil else { throw WattIntentFailure.notRunning }
        activate()
        if presenterReady {
            deliver(destination)
        } else {
            pendingDestination = destination
        }
    }

    /// Settings and the menu both enter here. The adapter's check still verifies
    /// the detached signature. Download hash verification stays on that same path
    /// and is not reachable from this intent.
    static func checkForUpdates() throws -> WattUpdateIntentOutcome {
        guard let router else { throw WattIntentFailure.notRunning }
        activate()
        let started = router.checkForUpdatesNow()
        if started, !presenterReady {
            pendingDestination = .softwareUpdate
        }
        if started {
            return WattUpdateIntentOutcome(started: true, message: "Checking for updates.")
        }
        let message = router.updateUnavailableReason ?? "Couldn’t check for updates."
        return WattUpdateIntentOutcome(started: false, message: message)
    }

    /// `openAppWhenRun` can promote an accessory app. Put the Dock policy back
    /// before activating so the panel can come forward without a Dock icon.
    private static func defaultActivation() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func activate() {
        activateForIntent()
    }

    private static func deliver(_ destination: AppDestination) {
        guard let router else { return }
        switch destination {
        case .statusPanel:
            // The status-item button toggles. Open must show the popover and
            // leave it up when the action runs again.
            router.showStatusPanel()
        case .settings:
            router.showSettings()
        case .softwareUpdate:
            router.present(.softwareUpdate)
        default:
            router.present(destination)
        }
    }

    private(set) static var performingIntent = 0
    private static var reopenTicket = 0
    private static var quietUntil: Date?
    /// How long a Shortcuts-delivered reopen waits before it may open Settings.
    /// An intent that starts in that window cancels it. Finder still opens Settings.
    static var reopenQuietNanoseconds: UInt64 = 400_000_000
    static var reopenSenderLookup: @MainActor () -> String? = liveReopenSender
    static var reopenHasAppleEvent: @MainActor () -> Bool = {
        NSAppleEventManager.shared().currentAppleEvent != nil
    }

    static var isPerformingIntent: Bool { performingIntent > 0 }
    /// False while `perform` is on the stack, so a reopen in that window does not open Settings.
    static var shouldPresentOnReopen: Bool { performingIntent == 0 }

    static func handlingIntent<T>(_ body: @MainActor () throws -> T) rethrows -> T {
        beginIntentHandling()
        defer { endIntentHandling() }
        return try body()
    }

    static func beginIntentHandling() { beginIntent() }

    static func endIntentHandling() { endIntent() }

    static func beginIntent() {
        performingIntent += 1
        reopenTicket += 1
        quietUntil = nil
    }

    static func endIntent() {
        performingIntent = max(0, performingIntent - 1)
        guard performingIntent == 0 else { return }
        quietUntil = Date().addingTimeInterval(Double(reopenQuietNanoseconds) / 1_000_000_000)
        reopenTicket += 1
    }

    /// `applicationShouldHandleReopen` shows Settings for a Finder or Dock open.
    /// Shortcuts talks to this accessory app with the same reopen, including for
    /// actions that do not ask to come forward. That path must not open Settings.
    static func handleReopen(_ showSettings: @escaping @MainActor () -> Void) {
        switch decision(for: reopenSenderLookup(), hasAppleEvent: reopenHasAppleEvent()) {
        case .suppress:
            return
        case .showSettings:
            showSettings()
        case .waitForIntent:
            let ticket = reserveReopen()
            let delay = reopenQuietNanoseconds
            Task { @MainActor in
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
                guard claimReopen(ticket) else { return }
                showSettings()
            }
        }
    }

    static func decision(for senderBundleIdentifier: String?, hasAppleEvent: Bool) -> WattReopenDecision {
        if performingIntent > 0 || isIntentDispatcher(senderBundleIdentifier) { return .suppress }
        // No Apple event is a direct AppKit reopen, including the unit-test call
        // and a Finder open. The quiet tail only covers an event from an
        // unknown sender, such as Launch Services delivering a shortcut.
        if isUserReopenSender(senderBundleIdentifier) || !hasAppleEvent { return .showSettings }
        if let quietUntil, Date() < quietUntil { return .suppress }
        return .waitForIntent
    }

    static func isIntentDispatcher(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        let id = bundleIdentifier.lowercased()
        let senders = [
            "com.apple.shortcuts", "com.apple.linkd", "com.apple.siri", "com.apple.siriactionsd",
            "com.apple.assistant", "com.apple.spotlight", "com.apple.corespotlight",
            "com.apple.speech", "com.apple.workflowkit"
        ]
        return senders.contains { id == $0 || id.hasPrefix($0 + ".") }
    }

    static func isUserReopenSender(_ bundleIdentifier: String?) -> Bool {
        guard let id = bundleIdentifier?.lowercased() else { return false }
        if let own = Bundle.main.bundleIdentifier?.lowercased(), id == own { return true }
        return ["com.apple.finder", "com.apple.dock", "com.apple.loginwindow"].contains(id)
    }

    private static func reserveReopen() -> Int {
        reopenTicket += 1
        return reopenTicket
    }

    private static func claimReopen(_ ticket: Int) -> Bool {
        guard ticket == reopenTicket, performingIntent == 0 else { return false }
        if let quietUntil, Date() < quietUntil { return false }
        return true
    }

    /// `keySenderPIDAttr` ('spid'). The reopen event's sender tells a Finder
    /// double-click apart from Shortcuts and linkd.
    private static func liveReopenSender() -> String? {
        let keySenderPIDAttr = AEKeyword(0x73706964)
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let pid = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value,
              pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier
    }
}

enum WattReopenDecision: Equatable {
    case showSettings
    case suppress
    case waitForIntent
}

enum WattIntentFailure: Error, Equatable {
    case notRunning
}

struct WattUpdateIntentOutcome: Equatable, Sendable {
    var started: Bool
    var message: String
}

/// Numbers the panel would show. Nil is an unmeasured channel, never a stand-in zero.
struct WattPowerReading: Equatable, Sendable {
    var available: Bool
    var systemDrawWatts: Double?
    var chargerWatts: Double?
    var batteryPercentage: Int?
    var batteryState: String

    static let unavailableLabel = "Unavailable"
    static let unavailable = WattPowerReading(available: false, systemDrawWatts: nil, chargerWatts: nil,
                                             batteryPercentage: nil, batteryState: unavailableLabel)

    func summary(precision: WattPrecision = .decimal) -> String {
        guard available else { return Self.unavailableLabel }
        let system = systemDrawWatts.map { Self.watts($0, precision: precision) } ?? Self.unavailableLabel
        let charger = chargerWatts.map { Self.watts($0, precision: precision) } ?? Self.unavailableLabel
        let battery = batteryPercentage.map { "\($0)%" } ?? Self.unavailableLabel
        return "System draw \(system), charger \(charger), battery \(battery), \(batteryState)."
    }

    static func watts(_ value: Double, precision: WattPrecision) -> String {
        PowerFormatter.watts(value, signed: false, precision: precision)
    }

    /// Uses the panel's sample gate and the same per-channel availability as the rows.
    static func make(from reading: PowerReading) -> WattPowerReading {
        guard reading.hasCurrentSample else { return .unavailable }
        let model = StatusPanelModel(reading: reading)
        let percentage = model.available(reading.capabilities.battery) ? reading.batteryPercentage : nil
        return WattPowerReading(available: true,
                                systemDrawWatts: model.systemNumber,
                                chargerWatts: model.chargerNumber,
                                batteryPercentage: percentage,
                                batteryState: batteryStateLabel(reading))
    }

    private static func batteryStateLabel(_ reading: PowerReading) -> String {
        switch reading.batteryState {
        case .charging: return "Charging"
        case .discharging: return "On battery"
        case .chargingHold: return "Charging paused"
        case .full: return "Full"
        case .noBattery: return "No battery"
        case .unknown: return "Unknown"
        }
    }
}
