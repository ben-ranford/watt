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
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Power Reading")
    static var defaultQuery = WattPowerReadingQuery()

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

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Menu Bar Display")
    static var caseDisplayRepresentations: [WattMenuBarDisplay: DisplayRepresentation] = [
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

struct GetPowerReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Power Reading"
    static var description = IntentDescription("Read system draw, charger watts, and battery.")
    static var openAppWhenRun: Bool { false }

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
        let entity = await WattIntentSession.readingEntity()
        return .result(value: entity, dialog: IntentDialog(stringLiteral: entity.summary))
    }
}

struct OpenStatusPanelIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Status Panel"
    static var description = IntentDescription("Open the power panel.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WattIntentSession.open(.statusPanel)
        return .result(dialog: "Opened the power panel.")
    }
}

struct OpenSettingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Settings"
    static var description = IntentDescription("Open Watt? settings.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WattIntentSession.open(.settings)
        return .result(dialog: "Opened Settings.")
    }
}

struct SetMenuBarDisplayIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Menu Bar Display"
    static var description = IntentDescription("Choose what the menu bar shows.")
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Display")
    var mode: WattMenuBarDisplay

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WattIntentSession.setDisplayMode(mode.displayMode)
        return .result(dialog: IntentDialog(stringLiteral: "Menu bar shows \(mode.displayMode.title)."))
    }
}

struct CheckForUpdatesIntent: AppIntent {
    static var title: LocalizedStringResource = "Check for Updates"
    static var description = IntentDescription("Check for an update. Signature and hash verification stay on.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = try await WattIntentSession.checkForUpdates()
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
