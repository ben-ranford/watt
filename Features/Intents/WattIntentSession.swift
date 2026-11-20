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
    /// Shortcuts activates this accessory app, and AppKit turns that into a reopen.
    /// The reopen handler opens Settings. While an intent is on the stack that
    /// would run at the same time as `perform` and the shortcut would not finish.
    private static var intentDepth = 0
    static var shouldPresentOnReopen: Bool { intentDepth == 0 }

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
        intentDepth = 0
    }

    static func beginIntentHandling() { intentDepth += 1 }

    static func endIntentHandling() { intentDepth = max(0, intentDepth - 1) }

    static func handlingIntent<T>(_ body: @MainActor () throws -> T) rethrows -> T {
        beginIntentHandling()
        defer { endIntentHandling() }
        return try body()
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
            // The fallback presenter toggles. An Open action must not close the panel.
            if !router.statusPanelPresented {
                router.showStatusPanel()
            }
        case .settings:
            router.showSettings()
        case .softwareUpdate:
            router.present(.softwareUpdate)
        default:
            router.present(destination)
        }
    }
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
