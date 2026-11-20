import AppIntents

extension WattIntentFailure: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notRunning: "Watt? isn’t running."
        }
    }
}

extension WattIntentSession {
    static func readingEntity() -> WattPowerReadingEntity {
        GetPowerReadingIntent.entity(from: currentReading(), precision: precision)
    }
}

/// Shortcuts value for one panel snapshot. Missing watts stay nil.
struct WattPowerReadingEntity: AppEntity, Equatable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Power Reading")
    static let defaultQuery = WattPowerReadingQuery()

    var id: String
    var available: Bool
    var systemDrawWatts: Double?
    var chargerWatts: Double?
    var batteryPercentage: Int?
    var batteryState: String
    var summary: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: summary))
    }
}

struct WattPowerReadingQuery: EntityQuery {
    func entities(for identifiers: [WattPowerReadingEntity.ID]) async throws -> [WattPowerReadingEntity] {
        let entity = await WattIntentSession.readingEntity()
        guard identifiers.contains(entity.id) else { return [] }
        return [entity]
    }

    func suggestedEntities() async throws -> [WattPowerReadingEntity] {
        []
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

    @Dependency var host: WattIntentHost

    static func entity(from reading: WattPowerReading, precision: WattPrecision = .decimal) -> WattPowerReadingEntity {
        WattPowerReadingEntity(id: reading.available ? "current" : "unavailable",
                               available: reading.available,
                               systemDrawWatts: reading.systemDrawWatts,
                               chargerWatts: reading.chargerWatts,
                               batteryPercentage: reading.batteryPercentage,
                               batteryState: reading.batteryState,
                               summary: reading.summary(precision: precision))
    }

    func perform() async throws -> some IntentResult & ReturnsValue<WattPowerReadingEntity> & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        // Read the dependency before the first await. After a suspension the
        // intent flow no longer has it, and the access traps.
        let intentHost = host
        let entity = try await WattIntentSession.handlingIntent(action: "reading") {
            if let forwarded = try await WattIntentBridge.forwardReading() { return forwarded }
            let entity = intentHost.readingEntity()
            WattIntentLog.notice("reading via=local summary=\(entity.summary)")
            return entity
        }
        return .result(value: entity, dialog: IntentDialog(stringLiteral: entity.summary))
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

    @Dependency var host: WattIntentHost

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        let intentHost = host
        try await WattIntentSession.handlingIntent(action: "openStatusPanel") {
            if try await WattIntentBridge.forwardOpen(.statusPanel) {
                return
            }
            try intentHost.open(.statusPanel)
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

    @Dependency var host: WattIntentHost

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        let intentHost = host
        try await WattIntentSession.handlingIntent(action: "openSettings") {
            if try await WattIntentBridge.forwardOpen(.settings) {
                return
            }
            try intentHost.open(.settings)
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

    @Dependency var host: WattIntentHost

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
        let intentHost = host
        let title = try await WattIntentSession.handlingIntent(action: "setDisplayMode") {
            if let forwarded = try await WattIntentBridge.forwardDisplayMode(mode.displayMode) { return forwarded }
            let title = try intentHost.setDisplayMode(mode.displayMode)
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

    @Dependency var host: WattIntentHost

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WattIntentHost.registerIfNeeded()
        let intentHost = host
        let outcome = try await WattIntentSession.handlingIntent(action: "checkForUpdates") {
            if let forwarded = try await WattIntentBridge.forwardCheck() { return forwarded }
            let outcome = try intentHost.checkForUpdates()
            WattIntentLog.notice("check for updates via=local started=\(outcome.started)")
            return outcome
        }
        return .result(dialog: IntentDialog(stringLiteral: outcome.message))
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
