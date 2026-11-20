import AppIntents
import AppKit
import Darwin
import os
import Security

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
        WattIntentHost.registerIfNeeded()
        WattIntentLog.notice("intent host registered pid=\(getpid())")
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
        remoteIntent = false
        reopenQuietNanoseconds = 400_000_000
        reopenSenderLookup = liveReopenSender
        reopenHasAppleEvent = { NSAppleEventManager.shared().currentAppleEvent != nil }
        frontmostBundleIdentifier = { nil }
        otherCopies = liveOtherCopies
        role = .keeper
        intentAccepted = false
        intentVisibleUntil = nil
        claimDeferralNanoseconds = 3_000_000_000
        otherInstances = liveOtherInstances
        claimSingleInstance = { SingleInstanceClaim.becomeOnlyInstance() }
        keeperIntentInFlight = { await WattIntentBridge.probeIntentInFlight() }
        launchSignal = liveLaunchSignal
        exitProcess = { NSApp.terminate(nil) }
        onBecameKeeper = nil
        startBridge = { WattIntentBridge.startKeeper() }
        satelliteGeneration += 1
        WattIntentBridge.stop()
        WattIntentBridge.directoryOverride = nil
    }

    static var shouldPresentLaunchUI: Bool { !otherCopies() && performingIntent == 0 }

    static func liveOtherCopies() -> Bool {
        let id = Bundle.main.bundleIdentifier ?? ""
        guard !id.isEmpty else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != getpid() && !$0.isTerminated }
    }

    /// Shortcuts asks LinkDaemon which process will run the action. Announcing
    /// the running app is the public registration call. It does not install a
    /// helper or start a sampler. Ad-hoc builds may log a RunningBoard warning;
    /// that warning is not fatal and does not change the accessory policy.
    static func connectToShortcuts() {
        startRelay()
        Task { @MainActor in
            WattShortcuts.updateAppShortcutParameters()
        }
    }

    private static let relayName = Notification.Name("io.github.ben-ranford.watt.intent")
    private static var relayObserver: NSObjectProtocol?

    private static func startRelay() {
        guard relayObserver == nil else { return }
        relayObserver = DistributedNotificationCenter.default().addObserver(
            forName: relayName, object: nil, queue: .main
        ) { notification in
            let action = notification.object as? String
            let mode = notification.userInfo?["mode"] as? String
            Task { @MainActor in
                applyRelay(action: action, mode: mode)
            }
        }
    }

    private static func applyRelay(action: String?, mode: String?) {
        switch action {
        case "began":
            remoteIntent = true
            reopenTicket += 1
        case "ended":
            remoteIntent = false
        case "panel":
            guard presenterReady else { return }
            router?.showStatusPanel()
        case "settings":
            guard presenterReady else { return }
            router?.showSettings()
        case "updates":
            guard presenterReady else { return }
            _ = router?.checkForUpdatesNow()
        case "mode":
            guard let mode, let displayMode = WattDisplayMode(rawValue: mode), let preferences else { return }
            preferences.displayMode = displayMode
        default:
            break
        }
    }

    private static func relayAction(_ destination: AppDestination) -> String? {
        switch destination {
        case .statusPanel: return "panel"
        case .settings: return "settings"
        case .softwareUpdate: return "updates"
        default: return nil
        }
    }

    private static func postRelay(_ action: String?, mode: String? = nil) {
        guard let action else { return }
        var info: [String: String] = [:]
        if let mode { info["mode"] = mode }
        DistributedNotificationCenter.default().postNotificationName(
            relayName, object: action, userInfo: info, deliverImmediately: true
        )
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
        // The menu-bar process applies the mode itself. A second process tells it.
        if role != .keeper, otherCopies() { postRelay("mode", mode: mode.rawValue) }
    }

    static func open(_ destination: AppDestination) throws {
        guard router != nil else { throw WattIntentFailure.notRunning }
        if role != .keeper, otherCopies() {
            postRelay(relayAction(destination))
            return
        }
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
        if role != .keeper, otherCopies() {
            postRelay("updates")
            return WattUpdateIntentOutcome(started: true, message: "Checking for updates.")
        }
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

    enum Role: String, Equatable {
        case undecided, keeper, satellite
    }

    /// The menu-bar process is the keeper. A second process started for a
    /// shortcut is a satellite: it does not take over and it does not sample.
    static var role: Role = .keeper
    static var intentAccepted = false
    static var intentVisibleUntil: Date?
    static var intentSeenRecently: Bool {
        if isPerformingIntent { return true }
        if let intentVisibleUntil, Date() < intentVisibleUntil { return true }
        return false
    }
    /// How long a second process waits for an intent before the version claim runs.
    /// An update relaunch waits this long. A shortcut is recognised inside it.
    static var claimDeferralNanoseconds: UInt64 = 3_000_000_000
    static var otherInstances: @MainActor () -> [Int32] = liveOtherInstances
    static var claimSingleInstance: @MainActor () -> SingleInstanceOutcome = {
        SingleInstanceClaim.becomeOnlyInstance()
    }
    static var keeperIntentInFlight: @MainActor () async -> Bool = {
        await WattIntentBridge.probeIntentInFlight()
    }
    static var launchSignal: @MainActor () -> WattIntentLaunchSignal = liveLaunchSignal
    static var exitProcess: @MainActor () -> Void = { NSApp.terminate(nil) }
    static var onBecameKeeper: (@MainActor () -> Void)?
    static var startBridge: @MainActor () -> Void = { WattIntentBridge.startKeeper() }
    private static var satelliteGeneration = 0
    private(set) static var performingIntent = 0
    /// The other Watt process is running an action, so this process must not open Settings.
    private static var remoteIntent = false
    static var otherCopies: @MainActor () -> Bool = liveOtherCopies
    private static var reopenTicket = 0
    private static var quietUntil: Date?
    /// How long a Shortcuts-delivered reopen waits before it may open Settings.
    /// An intent that starts in that window cancels it. Finder still opens Settings.
    static var reopenQuietNanoseconds: UInt64 = 400_000_000
    static var reopenSenderLookup: @MainActor () -> String? = liveReopenSender
    /// Tests set this to nil. Production reads the app that is in front.
    static var frontmostBundleIdentifier: @MainActor () -> String? = liveFrontmostBundleIdentifier
    static var reopenHasAppleEvent: @MainActor () -> Bool = {
        NSAppleEventManager.shared().currentAppleEvent != nil
    }

    static var isPerformingIntent: Bool { performingIntent > 0 }
    /// False while `perform` is on the stack, so a reopen in that window does not open Settings.
    static var shouldPresentOnReopen: Bool { performingIntent == 0 }

    static func handlingIntent<T>(action: String, _ body: @MainActor () async throws -> T) async rethrows -> T {
        WattIntentLog.notice("perform begin action=\(action) pid=\(getpid()) role=\(role.rawValue)")
        beginIntentHandling()
        defer {
            endIntentHandling()
            WattIntentLog.notice("perform end action=\(action) pid=\(getpid()) role=\(role.rawValue)")
        }
        return try await body()
    }

    static func beginIntentHandling() { beginIntent() }

    static func endIntentHandling() { endIntent() }

    static func beginIntent() {
        performingIntent += 1
        intentAccepted = true
        noteIntentActivity()
        reopenTicket += 1
        quietUntil = nil
        if otherCopies() { postRelay("began") }
    }

    static func endIntent() {
        performingIntent = max(0, performingIntent - 1)
        guard performingIntent == 0 else { return }
        quietUntil = Date().addingTimeInterval(Double(reopenQuietNanoseconds) / 1_000_000_000)
        reopenTicket += 1
        if otherCopies() { postRelay("ended") }
        guard role == .satellite else { return }
        // perform() has to return the shortcut result before this process exits.
        // LinkDaemon treats a process that dies first as ProcessRegistry error 0.
        // Only the extra process exits. The menu-bar process stays.
        let generation = satelliteGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard role == .satellite, satelliteGeneration == generation, performingIntent == 0 else { return }
            WattIntentLog.notice("satellite intent finished; exiting without replacing the running instance pid=\(getpid())")
            exitProcess()
        }
    }

    /// The running process answers a sibling's probe for a few seconds after an
    /// intent starts, so the sibling can leave it in place.
    static func noteIntentActivity() {
        intentVisibleUntil = Date().addingTimeInterval(3)
    }

    /// `applicationShouldHandleReopen` shows Settings for a Finder or Dock open.
    /// Shortcuts talks to this accessory app with the same reopen, including for
    /// actions that do not ask to come forward. That path must not open Settings.
    static func handleReopen(_ showSettings: @escaping @MainActor () -> Void) {
        let sender = reopenSenderLookup()
        let frontmost = frontmostBundleIdentifier()
        let choice = decision(for: sender, hasAppleEvent: reopenHasAppleEvent(), frontmost: frontmost)
        WattIntentLog.notice("reopen sender=\(sender ?? "none") frontmost=\(frontmost ?? "none") decision=\(String(describing: choice)) pid=\(getpid()) role=\(role.rawValue)")
        switch choice {
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
                let later = frontmostBundleIdentifier()
                // The wait is for an intent. It is not a second chance to open
                // Settings while Shortcuts is the app in front.
                if isIntentDispatcher(later) { return }
                showSettings()
            }
        }
    }

    static func decision(for senderBundleIdentifier: String?, hasAppleEvent: Bool, frontmost: String? = nil) -> WattReopenDecision {
        if performingIntent > 0 || remoteIntent || isIntentDispatcher(senderBundleIdentifier) || isIntentDispatcher(frontmost) {
            return .suppress
        }
        if let quietUntil, Date() < quietUntil,
           !isUserReopenSender(senderBundleIdentifier), !isExternalUserOpener(frontmost) {
            return .suppress
        }
        // The reopen event often has no sender. Finder is still the frontmost
        // app when someone opens Watt? from Finder; Shortcuts is frontmost when
        // the Shortcuts editor runs an action. This process being frontmost is
        // not that signal: an action can activate Watt? before the reopen runs.
        if isUserReopenSender(senderBundleIdentifier) || isExternalUserOpener(frontmost) { return .showSettings }
        _ = hasAppleEvent
        return .waitForIntent
    }

    /// A Quit from the menu has no intent-dispatcher sender. linkd and Shortcuts
    /// must not be able to end the menu-bar process after Stop.
    static func quitReply() -> NSApplication.TerminateReply {
        let sender = reopenSenderLookup()
        if isIntentDispatcher(sender) {
            WattIntentLog.notice("refusing quit from sender=\(sender ?? "none") pid=\(getpid()) role=\(role.rawValue)")
            return .terminateCancel
        }
        WattIntentLog.notice("accepting quit from sender=\(sender ?? "none") pid=\(getpid()) role=\(role.rawValue)")
        return .terminateNow
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

    static func liveFrontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func isExternalUserOpener(_ bundleIdentifier: String?) -> Bool {
        guard let id = bundleIdentifier?.lowercased() else { return false }
        return ["com.apple.finder", "com.apple.dock", "com.apple.loginwindow"].contains(id)
    }

    static func isUserReopenSender(_ bundleIdentifier: String?) -> Bool {
        guard let id = bundleIdentifier?.lowercased() else { return false }
        if let own = Bundle.main.bundleIdentifier?.lowercased(), id == own { return true }
        return isExternalUserOpener(id)
    }

    private static func reserveReopen() -> Int {
        reopenTicket += 1
        return reopenTicket
    }

    private static func claimReopen(_ ticket: Int) -> Bool {
        guard ticket == reopenTicket, performingIntent == 0, !remoteIntent else { return false }
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

    static func liveOtherInstances() -> [Int32] {
        let identifier = Bundle.main.bundleIdentifier ?? ""
        guard !identifier.isEmpty else { return [] }
        return RunningApplicationRegistry().runningInstances(bundleIdentifier: identifier).map(\.processIdentifier)
            .filter { $0 != getpid() && $0 > 0 }
    }

    static func liveLaunchSignal() -> WattIntentLaunchSignal {
        let parent = getppid()
        let parentBundle = parent > 1 ? NSRunningApplication(processIdentifier: parent)?.bundleIdentifier : nil
        return WattIntentLaunchSignal(parentPID: parent, parentBundleIdentifier: parentBundle,
                                      eventSenderBundleIdentifier: liveReopenSender())
    }

    static func isDispatcherLaunch(_ signal: WattIntentLaunchSignal) -> Bool {
        isIntentDispatcher(signal.parentBundleIdentifier) || isIntentDispatcher(signal.eventSenderBundleIdentifier)
    }

    /// Decides whether this process keeps the menu bar. A shortcut's second
    /// process waits, then stays out of the version claim so neither pid is quit.
    static func finishLaunchClaim() async {
        let others = otherInstances()
        let signal = launchSignal()
        let signature = WattCodeSignature.current()
        let otherSignature = others.first.flatMap { WattCodeSignature.ofProcess($0) }
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "none"
        WattIntentLog.notice(WattCodeSignature.launchLine(pid: getpid(), version: version,
                                                          path: Bundle.main.bundleURL.path,
                                                          signature: signature, others: others,
                                                          other: otherSignature, signal: signal,
                                                          arguments: Array(CommandLine.arguments.dropFirst().prefix(8))))
        if others.isEmpty {
            adoptKeeper(reason: "only instance")
            return
        }
        role = .undecided
        let seconds = Double(claimDeferralNanoseconds) / 1_000_000_000
        WattIntentLog.notice("deferring single-instance claim for \(seconds)s pid=\(getpid()) others=\(others.map(String.init).joined(separator: ","))")
        let deadline = Date().addingTimeInterval(seconds)
        while true {
            if await shouldRemainSatellite() {
                becomeSatellite(keepers: others)
                return
            }
            if claimDeferralNanoseconds == 0 || Date() >= deadline { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if await shouldRemainSatellite() {
            becomeSatellite(keepers: others)
            return
        }
        adoptKeeper(reason: "no intent during launch")
    }

    private static func shouldRemainSatellite() async -> Bool {
        if intentAccepted || isPerformingIntent || isDispatcherLaunch(launchSignal()) { return true }
        return await keeperIntentInFlight()
    }

    private static func adoptKeeper(reason: String) {
        satelliteGeneration += 1
        let outcome = claimSingleInstance()
        if outcome.terminatedSelf {
            WattIntentLog.notice("yielded to running instance pid=\(outcome.activated.map(String.init) ?? "none"); this process is exiting")
            return
        }
        if outcome.deferredForIntent {
            becomeSatellite(keepers: otherInstances())
            return
        }
        role = .keeper
        startBridge()
        WattIntentLog.notice("keeper pid=\(getpid()) reason=\(reason) stopped=\(outcome.stopped.map(String.init).joined(separator: ","))")
        onBecameKeeper?()
    }

    private static func becomeSatellite(keepers: [Int32]) {
        role = .satellite
        satelliteGeneration += 1
        let generation = satelliteGeneration
        WattIntentLog.notice("satellite pid=\(getpid()) leaving \(keepers.map(String.init).joined(separator: ",")) running; single-instance claim skipped")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard role == .satellite, satelliteGeneration == generation, performingIntent == 0 else { return }
            WattIntentLog.notice("satellite exiting; running instance kept pid=\(getpid())")
            exitProcess()
        }
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

enum WattIntentLog {
    static let subsystem = "io.github.ben-ranford.watt"
    static let category = "intents"
    private static let log = Logger(subsystem: "io.github.ben-ranford.watt", category: "intents")

    static func notice(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }
}

struct WattIntentLaunchSignal: Equatable, Sendable {
    var parentPID: Int32
    var parentBundleIdentifier: String?
    var eventSenderBundleIdentifier: String?
}

/// The model Shortcuts calls. Registered from `App.init`, not from the delegate,
/// so `perform()` does not need a process that has finished launching windows.
/// The type stays off the main actor: `AppDependencyManager.add` stores it in a
/// Sendable closure, which cannot read a main-actor static.
final class WattIntentHost: NSObject, @unchecked Sendable {
    static let shared = WattIntentHost()
    private static let registration = OSAllocatedUnfairLock(initialState: false)

    static func registerIfNeeded() {
        let shouldRegister = registration.withLock { registered in
            if registered { return false }
            registered = true
            return true
        }
        guard shouldRegister else { return }
        // `add` stores a Sendable closure. Capture the instance here so that
        // closure does not read a main-actor static, and register the host
        // rather than the closure's own type.
        let host = WattIntentHost.shared
        AppDependencyManager.shared.add(dependency: host)
    }

    @MainActor
    func readingEntity() -> WattPowerReadingEntity {
        GetPowerReadingIntent.entity(from: WattIntentSession.currentReading(), precision: WattIntentSession.precision)
    }

    @MainActor
    func setDisplayMode(_ mode: WattDisplayMode) throws -> String {
        try SetMenuBarDisplayIntent.apply(WattMenuBarDisplay(mode))
    }

    @MainActor
    func open(_ destination: AppDestination) throws {
        try WattIntentSession.open(destination)
    }

    @MainActor
    func checkForUpdates() throws -> WattUpdateIntentOutcome {
        try WattIntentSession.checkForUpdates()
    }
}

struct WattIntentRequest: Codable, Equatable, Sendable {
    var action: String
    var destination: String? = nil
    var mode: String? = nil
}

struct WattIntentReply: Codable, Equatable, Sendable {
    var ok: Bool
    var intentInFlight: Bool
    var summary: String? = nil
    var available: Bool? = nil
    var systemDrawWatts: Double? = nil
    var chargerWatts: Double? = nil
    var batteryPercentage: Int? = nil
    var batteryState: String? = nil
    var displayTitle: String? = nil
    var updateStarted: Bool? = nil
    var updateMessage: String? = nil
    var failure: String? = nil
}

enum WattCodeSignature {
    struct Snapshot: Equatable, Sendable {
        var teamIdentifier: String
        var adhoc: Bool
        var cdhash: String
        var readable: Bool
    }

    static let unreadable = Snapshot(teamIdentifier: "none", adhoc: false, cdhash: "none", readable: false)

    static func current() -> Snapshot {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return unreadable }
        return snapshot(of: code) ?? unreadable
    }

    static func ofProcess(_ pid: Int32) -> Snapshot? {
        var guest: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &guest) == errSecSuccess,
              let guest else { return nil }
        return snapshot(of: guest)
    }

    static func launchLine(pid: Int32, version: String, path: String, signature: Snapshot, others: [Int32],
                           other: Snapshot?, signal: WattIntentLaunchSignal, arguments: [String] = []) -> String {
        let otherPIDs = others.map(String.init).joined(separator: ",")
        var line = "launch pid=\(pid) version=\(version) path=\(path) team=\(signature.teamIdentifier) adhoc=\(signature.adhoc) cdhash=\(signature.cdhash) others=\(otherPIDs) parent=\(signal.parentPID) parentBundle=\(signal.parentBundleIdentifier ?? "none") eventSender=\(signal.eventSenderBundleIdentifier ?? "none")"
        if let other {
            let match = signature.readable && other.readable && signature.cdhash == other.cdhash && signature.teamIdentifier == other.teamIdentifier
            line += " otherTeam=\(other.teamIdentifier) otherAdhoc=\(other.adhoc) otherCDHash=\(other.cdhash) signatureMatch=\(match)"
        }
        if !arguments.isEmpty {
            line += " arguments=\(arguments.joined(separator: " ").prefix(180))"
        }
        if signature.readable, signature.adhoc, signature.teamIdentifier == "none" {
            line += " note=adhoc signature has no Team ID; linkd identifies processes by cdhash and may launch a second instance instead of adopting the running one"
        }
        return line
    }

    private static func snapshot(of code: SecCode) -> Snapshot? {
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let fields = information as? [String: Any] else { return nil }
        let team = (fields[kSecCodeInfoTeamIdentifier as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "none"
        let flags = flagValue(fields[kSecCodeInfoFlags as String])
        // cs_blobs.h kSecCodeSignatureAdhoc. The Security Swift overlay does not import that C enum.
        let adhoc = (flags & 0x0002) != 0
        let hash = (fields[kSecCodeInfoUnique as String] as? Data).map { $0.map { String(format: "%02x", $0) }.joined() } ?? "none"
        return Snapshot(teamIdentifier: team, adhoc: adhoc, cdhash: hash, readable: true)
    }

    private static func flagValue(_ value: Any?) -> UInt32 {
        switch value {
        case let number as NSNumber: return number.uint32Value
        case let number as UInt32: return number
        case let number as Int: return UInt32(truncatingIfNeeded: number)
        default: return 0
        }
    }
}

@MainActor
enum WattIntentBridge {
    static var directoryOverride: URL?
    private static var listenFD: Int32 = -1

    static var directory: URL {
        directoryOverride ?? URL(fileURLWithPath: "/tmp/watt-intents-\(getuid())", isDirectory: true)
    }

    static func startKeeper() {
        guard listenFD < 0 else { return }
        let root = directory
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        } catch {
            WattIntentLog.notice("intent bridge directory failed \(error.localizedDescription)")
            return
        }
        if let existing = readPID(), existing != getpid(), kill(existing, 0) == 0,
           NSRunningApplication(processIdentifier: existing)?.bundleIdentifier == Bundle.main.bundleIdentifier {
            WattIntentLog.notice("intent bridge already owned by pid=\(existing)")
            return
        }
        let socketPath = root.appendingPathComponent("host.sock").path
        unlink(socketPath)
        guard let fd = WattIntentSocket.listen(path: socketPath) else {
            WattIntentLog.notice("intent bridge listen failed errno=\(errno)")
            return
        }
        listenFD = fd
        let pidURL = root.appendingPathComponent("host.pid")
        try? Data("\(getpid())\n".utf8).write(to: pidURL, options: .atomic)
        chmod(pidURL.path, 0o600)
        WattIntentLog.notice("intent bridge listening pid=\(getpid())")
        WattIntentBridgeQueue.accept.async {
            WattIntentSocket.acceptLoop(fd: fd) { requestData, respond in
                Task { @MainActor in
                    respond(WattIntentBridge.handle(requestData))
                }
            }
        }
    }

    static func stop() {
        let fd = listenFD
        listenFD = -1
        if fd >= 0 { Darwin.close(fd) }
        guard readPID() == getpid() else { return }
        unlink(directory.appendingPathComponent("host.sock").path)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("host.pid"))
    }

    static func probeIntentInFlight() async -> Bool {
        guard liveKeeperPID() != nil else { return false }
        return (try? await exchange(WattIntentRequest(action: "probe"), timeout: 1))?.intentInFlight == true
    }

    static func forwardReading() async throws -> WattPowerReadingEntity? {
        guard liveKeeperPID() != nil else { return nil }
        let reply = try await exchange(WattIntentRequest(action: "reading"), timeout: 2)
        guard reply.ok, let summary = reply.summary, let available = reply.available, let state = reply.batteryState else {
            WattIntentLog.notice("reading forward failed pid=\(getpid())")
            throw WattIntentFailure.notRunning
        }
        WattIntentLog.notice("reading via=keeper summary=\(summary)")
        return WattPowerReadingEntity(id: available ? "current" : "unavailable", available: available,
                                      systemDrawWatts: reply.systemDrawWatts, chargerWatts: reply.chargerWatts,
                                      batteryPercentage: reply.batteryPercentage, batteryState: state, summary: summary)
    }

    static func forwardOpen(_ destination: AppDestination) async throws -> Bool {
        guard liveKeeperPID() != nil else { return false }
        let reply = try await exchange(WattIntentRequest(action: "open", destination: destinationName(destination)), timeout: 2)
        if reply.ok {
            WattIntentLog.notice("open via=keeper destination=\(destinationName(destination))")
            return true
        }
        WattIntentLog.notice("open forward failed destination=\(destinationName(destination)) pid=\(getpid())")
        throw WattIntentFailure.notRunning
    }

    static func forwardDisplayMode(_ mode: WattDisplayMode) async throws -> String? {
        guard liveKeeperPID() != nil else { return nil }
        let reply = try await exchange(WattIntentRequest(action: "displayMode", mode: mode.rawValue), timeout: 2)
        guard reply.ok, let title = reply.displayTitle else {
            WattIntentLog.notice("display mode forward failed pid=\(getpid())")
            throw WattIntentFailure.notRunning
        }
        WattIntentLog.notice("display mode via=keeper title=\(title)")
        return title
    }

    static func forwardCheck() async throws -> WattUpdateIntentOutcome? {
        guard liveKeeperPID() != nil else { return nil }
        let reply = try await exchange(WattIntentRequest(action: "checkUpdates"), timeout: 2)
        guard reply.ok, let message = reply.updateMessage, let started = reply.updateStarted else {
            WattIntentLog.notice("check for updates forward failed pid=\(getpid())")
            throw WattIntentFailure.notRunning
        }
        WattIntentLog.notice("check for updates via=keeper started=\(started)")
        return WattUpdateIntentOutcome(started: started, message: message)
    }

    static func exchange(_ request: WattIntentRequest, timeout: Int = 2) async throws -> WattIntentReply {
        let path = directory.appendingPathComponent("host.sock").path
        let body = try JSONEncoder().encode(request)
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            WattIntentBridgeQueue.client.async {
                do { continuation.resume(returning: try WattIntentSocket.exchange(path: path, request: body, timeoutSeconds: timeout)) }
                catch { continuation.resume(throwing: error) }
            }
        }
        guard let reply = try? JSONDecoder().decode(WattIntentReply.self, from: data) else { throw WattIntentFailure.notRunning }
        return reply
    }

    private static func liveKeeperPID() -> Int32? {
        guard let pid = readPID(), pid > 0, pid != getpid(), kill(pid, 0) == 0 else { return nil }
        guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == Bundle.main.bundleIdentifier else { return nil }
        return pid
    }

    private static func readPID() -> Int32? {
        guard let text = try? String(contentsOf: directory.appendingPathComponent("host.pid"), encoding: .utf8) else { return nil }
        return Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func handle(_ data: Data) -> Data {
        let reply: WattIntentReply
        if let request = try? JSONDecoder().decode(WattIntentRequest.self, from: data) {
            reply = perform(request)
        } else {
            reply = WattIntentReply(ok: false, intentInFlight: false, failure: "malformed")
        }
        return (try? JSONEncoder().encode(reply)) ?? Data()
    }

    private static func perform(_ request: WattIntentRequest) -> WattIntentReply {
        switch request.action {
        case "probe":
            return WattIntentReply(ok: true, intentInFlight: WattIntentSession.intentSeenRecently)
        case "reading":
            WattIntentSession.noteIntentActivity()
            let reading = WattIntentSession.currentReading()
            return WattIntentReply(ok: true, intentInFlight: true,
                                   summary: reading.summary(precision: WattIntentSession.precision),
                                   available: reading.available, systemDrawWatts: reading.systemDrawWatts,
                                   chargerWatts: reading.chargerWatts, batteryPercentage: reading.batteryPercentage,
                                   batteryState: reading.batteryState)
        case "open":
            WattIntentSession.noteIntentActivity()
            guard let name = request.destination, let destination = destination(named: name) else {
                return WattIntentReply(ok: false, intentInFlight: true, failure: "destination")
            }
            do {
                try WattIntentSession.open(destination)
                return WattIntentReply(ok: true, intentInFlight: true)
            } catch {
                return WattIntentReply(ok: false, intentInFlight: true, failure: "notRunning")
            }
        case "displayMode":
            WattIntentSession.noteIntentActivity()
            guard let raw = request.mode, let mode = WattDisplayMode(rawValue: raw) else {
                return WattIntentReply(ok: false, intentInFlight: true, failure: "mode")
            }
            do {
                let title = try SetMenuBarDisplayIntent.apply(WattMenuBarDisplay(mode))
                return WattIntentReply(ok: true, intentInFlight: true, displayTitle: title)
            } catch {
                return WattIntentReply(ok: false, intentInFlight: true, failure: "notRunning")
            }
        case "checkUpdates":
            WattIntentSession.noteIntentActivity()
            do {
                let outcome = try WattIntentSession.checkForUpdates()
                return WattIntentReply(ok: true, intentInFlight: true, updateStarted: outcome.started, updateMessage: outcome.message)
            } catch {
                return WattIntentReply(ok: false, intentInFlight: true, failure: "notRunning")
            }
        default:
            return WattIntentReply(ok: false, intentInFlight: false, failure: "unknown")
        }
    }

    private static func destinationName(_ destination: AppDestination) -> String {
        switch destination {
        case .statusPanel: return "statusPanel"
        case .settings: return "settings"
        case .softwareUpdate: return "softwareUpdate"
        case .coachMark: return "coachMark"
        case .onboarding: return "onboarding"
        case .update: return "update"
        case .whatsNew: return "whatsNew"
        }
    }

    private static func destination(named name: String) -> AppDestination? {
        switch name {
        case "statusPanel": return .statusPanel
        case "settings": return .settings
        case "softwareUpdate": return .softwareUpdate
        case "coachMark": return .coachMark
        case "onboarding": return .onboarding
        case "update": return .update
        case "whatsNew": return .whatsNew
        default: return nil
        }
    }
}

private enum WattIntentBridgeQueue {
    static let accept = DispatchQueue(label: "io.github.ben-ranford.watt.intents.accept")
    static let client = DispatchQueue(label: "io.github.ben-ranford.watt.intents.client")
}

private enum WattIntentSocket {
    static func listen(path: String) -> Int32? {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        setCommonOptions(fd)
        guard var address = unixAddress(path) else { Darwin.close(fd); return nil }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, Darwin.listen(fd, 8) == 0 else { Darwin.close(fd); return nil }
        chmod(path, 0o600)
        return fd
    }

    static func acceptLoop(fd: Int32, onRequest: @escaping @Sendable (Data, @escaping @Sendable (Data) -> Void) -> Void) {
        while true {
            let client = Darwin.accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                return
            }
            setCommonOptions(client)
            var uid: uid_t = 0
            var gid: gid_t = 0
            guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { Darwin.close(client); continue }
            guard let request = readFrame(client, limit: 65_536) else { Darwin.close(client); continue }
            onRequest(request) { response in
                DispatchQueue.global(qos: .userInitiated).async {
                    writeFrame(client, response)
                    Darwin.close(client)
                }
            }
        }
    }

    static func exchange(path: String, request: Data, timeoutSeconds: Int) throws -> Data {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw WattIntentFailure.notRunning }
        setCommonOptions(fd)
        setTimeout(fd, seconds: timeoutSeconds)
        defer { Darwin.close(fd) }
        guard var address = unixAddress(path) else { throw WattIntentFailure.notRunning }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { throw WattIntentFailure.notRunning }
        writeFrame(fd, request)
        guard let response = readFrame(fd, limit: 65_536) else { throw WattIntentFailure.notRunning }
        return response
    }

    private static func setCommonOptions(_ fd: Int32) {
        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
    }

    private static func setTimeout(_ fd: Int32, seconds: Int) {
        var timeout = timeval()
        timeout.tv_sec = time_t(seconds)
        timeout.tv_usec = 0
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }

    private static func unixAddress(_ path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        let fits = path.withCString { strlen($0) + 1 <= capacity }
        guard fits else { return nil }
        _ = withUnsafeMutablePointer(to: &address.sun_path) { tuple in
            tuple.withMemoryRebound(to: Int8.self, capacity: capacity) { buffer in
                path.withCString { strcpy(buffer, $0) }
            }
        }
        return address
    }

    private static func readFrame(_ fd: Int32, limit: Int) -> Data? {
        var data = Data()
        var byte: UInt8 = 0
        while data.count < limit {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 { return nil }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if byte == 10 { return data }
            data.append(byte)
        }
        return nil
    }

    private static func writeFrame(_ fd: Int32, _ data: Data) {
        var payload = data
        payload.append(10)
        payload.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var sent = 0
            while sent < buffer.count {
                let count = Darwin.write(fd, base.advanced(by: sent), buffer.count - sent)
                if count < 0 {
                    if errno == EINTR { continue }
                    return
                }
                sent += count
            }
        }
    }
}
