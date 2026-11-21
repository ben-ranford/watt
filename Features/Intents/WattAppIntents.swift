import AppIntents

extension WattIntentFailure: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notRunning: "Watt? isn’t running."
        }
    }
}

/// The Settings "Show" choices. Raw values are the labels already used in the menu.
enum WattMenuBarDisplay: String, AppEnum, CaseIterable {
    case batteryDelta = "Battery Delta"
    case chargerInput = "Charger Input"
    case systemDraw = "System Draw"
    case perComponent = "Per Component"
    case iconOnly = "Icon Only"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Menu Bar Display")
    static let caseDisplayRepresentations: [WattMenuBarDisplay: DisplayRepresentation] = [
        .batteryDelta: "Battery Delta",
        .chargerInput: "Charger Input",
        .systemDraw: "System Draw",
        .perComponent: "Per Component",
        .iconOnly: "Icon Only"
    ]

    var displayMode: WattDisplayMode {
        switch self {
        case .batteryDelta: return .delta
        case .chargerInput: return .charger
        case .systemDraw: return .draw
        case .perComponent: return .components
        case .iconOnly: return .iconOnly
        }
    }

    init(_ mode: WattDisplayMode) {
        switch mode {
        case .delta: self = .batteryDelta
        case .charger: self = .chargerInput
        case .draw: self = .systemDraw
        case .components: self = .perComponent
        case .iconOnly: self = .iconOnly
        }
    }
}

/// Shortcuts must not foreground this accessory app. Foregrounding runs
/// `applicationShouldHandleReopen`, which opens Settings and leaves the shortcut
/// waiting on a process LinkDaemon never registers.
enum WattIntentActivation {
    static var openAppWhenRun: Bool { false }
    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    #endif
}

struct GetPowerReadingIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Power Reading"
    static let description = IntentDescription("Read system draw, charger watts, and battery.")
    static var openAppWhenRun: Bool { WattIntentActivation.openAppWhenRun }
    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    #endif

    /// A plain string and no dialog. `shortcuts run` pauses until an alert or
    /// a requested value is dismissed, and an `AppEntity` never produces that
    /// dismissal in a headless run.
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        WattIntentHost.registerIfNeeded()
        let summary = try await WattIntentSession.handlingIntent(action: "reading") {
            if let forwarded = try await WattIntentBridge.forwardReading() { return forwarded }
            let summary = WattIntentHost.shared.readingSummary()
            WattIntentLog.notice("reading via=local summary=\(summary)")
            return summary
        }
        return .result(value: summary)
    }
}

struct OpenStatusPanelIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Status Panel"
    static let description = IntentDescription("Open the power panel.")
    static var openAppWhenRun: Bool { WattIntentActivation.openAppWhenRun }
    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        try await WattIntentSession.handlingIntent(action: "openStatusPanel") {
            if try await WattIntentBridge.forwardOpen(.statusPanel) {
                return
            }
            try WattIntentHost.shared.open(.statusPanel)
            WattIntentLog.notice("open via=local destination=statusPanel")
        }
        return .result(dialog: "Opened the power panel.")
    }
}

struct OpenSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Settings"
    static let description = IntentDescription("Open Watt? settings.")
    static var openAppWhenRun: Bool { WattIntentActivation.openAppWhenRun }
    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        try await WattIntentSession.handlingIntent(action: "openSettings") {
            if try await WattIntentBridge.forwardOpen(.settings) {
                return
            }
            try WattIntentHost.shared.open(.settings)
            WattIntentLog.notice("open via=local destination=settings")
        }
        return .result(dialog: "Opened Settings.")
    }
}

struct SetMenuBarDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Menu Bar Display"
    static let description = IntentDescription("Choose what the menu bar shows.")
    static var openAppWhenRun: Bool { WattIntentActivation.openAppWhenRun }
    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    #endif

    @Parameter(title: "Display")
    var mode: WattMenuBarDisplay

    /// Shortcuts fills `mode` and calls `perform`. Tests call this with each existing mode.
    @MainActor
    static func apply(_ mode: WattMenuBarDisplay) throws -> String {
        try WattIntentSession.setDisplayMode(mode.displayMode)
        return mode.displayMode.title
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        let title = try await WattIntentSession.handlingIntent(action: "setDisplayMode") {
            if let forwarded = try await WattIntentBridge.forwardDisplayMode(mode.displayMode) { return forwarded }
            let title = try WattIntentHost.shared.setDisplayMode(mode.displayMode)
            WattIntentLog.notice("display mode via=local title=\(title)")
            return title
        }
        return .result(dialog: IntentDialog(stringLiteral: "Menu bar shows \(title)."))
    }
}

struct CheckForUpdatesIntent: AppIntent {
    static let title: LocalizedStringResource = "Check for Updates"
    static let description = IntentDescription("Check for an update. Signature and hash verification stay on.")
    static var openAppWhenRun: Bool { WattIntentActivation.openAppWhenRun }
    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    #endif

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        WattIntentHost.registerIfNeeded()
        let outcome = try await WattIntentSession.handlingIntent(action: "checkForUpdates") {
            if let forwarded = try await WattIntentBridge.forwardCheck() { return forwarded }
            let outcome = try WattIntentHost.shared.checkForUpdates()
            WattIntentLog.notice("check for updates via=local started=\(outcome.started) status=\(outcome.message)")
            return outcome
        }
        return .result(value: outcome.message)
    }
}

struct WattShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: GetPowerReadingIntent(), phrases: [
            "Get the power reading in \(.applicationName)",
            "What's the power draw in \(.applicationName)"
        ], shortTitle: "Power Reading", systemImageName: "bolt.fill")
        AppShortcut(intent: OpenStatusPanelIntent(), phrases: [
            "Open \(.applicationName)",
            "Show the \(.applicationName) panel"
        ], shortTitle: "Open Panel", systemImageName: "rectangle.inset.filled")
        AppShortcut(intent: OpenSettingsIntent(), phrases: [
            "Open \(.applicationName) settings"
        ], shortTitle: "Settings", systemImageName: "gearshape")
        AppShortcut(intent: SetMenuBarDisplayIntent(), phrases: [
            "Set \(.applicationName) menu bar to \(\.$mode)",
            "Show \(\.$mode) in \(.applicationName)"
        ], shortTitle: "Menu Bar Display", systemImageName: "rectangle.split.3x1")
        AppShortcut(intent: CheckForUpdatesIntent(), phrases: [
            "Check for \(.applicationName) updates"
        ], shortTitle: "Check for Updates", systemImageName: "arrow.clockwise")
    }
}
