import Foundation
import SwiftUI

enum StatusPanelState: Equatable {
    case noReading
    case standard
    case optimisedChargingHold(percentage: Int)
    case fullOnAdapter
    case insufficientCharger
}

/// Presentation only: unavailable capabilities never turn into fabricated zero readings.
struct StatusPanelModel {
    let reading: PowerReading
    var chargerDescription: String? = nil
    var helperSwitchedOff = false
    var componentReadingsEnabled = true
    var includesComponents = true
    var setupIncomplete = false
    var setupSaveFailed = false
    var hasReading: Bool {
        reading.hasCurrentSample
    }
    var state: StatusPanelState {
        guard hasReading else { return .noReading }
        // A battery/source status without measured watts is not a power reading.
        // Keep independently valid charger/system telemetry visible while the
        // battery state is temporarily unknown.
        let hasIndependentTelemetry = [.chargerInput, .systemDraw].contains(reading.mode) &&
            (reading.value(for: .charger) != nil || reading.value(for: .draw) != nil)
        guard reading.value(for: isDesktop ? .draw : .delta) != nil ||
                hasIndependentTelemetry ||
                (reading.mode == .perComponent && !components.isEmpty) else { return .noReading }
        if reading.hasInsufficientCharger { return .insufficientCharger }
        guard hasReading, reading.freshness == .fresh,
              reading.capabilities.battery == .available,
              reading.capabilities.charger == .available,
              reading.capabilities.systemDraw == .available,
              reading.watts == 0, reading.chargerWatts != nil, reading.systemWatts != nil,
              let percentage = reading.batteryPercentage,
              (try? reading.validate()) != nil else { return .standard }
        if reading.batteryState == .full, percentage == 100 {
            return .fullOnAdapter
        }
        if reading.batteryState == .chargingHold,
           reading.chargingHoldReason == .optimisedBatteryCharging {
            return .optimisedChargingHold(percentage: percentage)
        }
        return .standard
    }
    var hasOptimisedChargingHold: Bool {
        if case .optimisedChargingHold = state { return true }
        return false
    }
    var hasInsufficientCharger: Bool { state == .insufficientCharger }
    var hasFullOnAdapter: Bool { state == .fullOnAdapter }
    var hasNoReading: Bool { state == .noReading }
    func available(_ capability: Capability) -> Bool { hasReading && capability == .available }
    var battery: String { PowerFormatter.watts(available(reading.capabilities.battery) ? reading.watts : nil).replacingOccurrences(of: "-", with: "−") }
    var charger: String {
        if hasReading && reading.batteryState == .discharging && reading.capabilities.charger == .disconnected {
            return "Unplugged"
        }
        return PowerFormatter.watts(available(reading.capabilities.charger) ? reading.chargerWatts : nil, signed: false)
    }
    var system: String { PowerFormatter.watts(available(reading.capabilities.systemDraw) ? reading.systemWatts : nil, signed: false) }
    var components: [PowerComponent] { !helperSwitchedOff && componentReadingsEnabled && reading.freshness == .fresh && available(reading.capabilities.components) ? reading.components : [] }
    var componentsOff: Bool { helperSwitchedOff || !componentReadingsEnabled }
    var isDesktop: Bool { reading.batteryState == .noBattery && reading.capabilities.battery == .unsupported }
    /// A full battery has no charging delta, so the useful default headline is
    /// the measured draw from the adapter. Keep the battery delta available in
    /// the Battery row and leave explicit menu-bar display modes untouched.
    var headlineValue: String {
        if hasNoReading { return NoReadingPresentation.value }
        if isDesktop || hasFullOnAdapter { return system }
        return battery
    }
    var summaryLabel: String { hasNoReading ? NoReadingPresentation.title : isDesktop ? "System draw status" : "Battery status" }
    var showsComponents: Bool { includesComponents && !setupIncomplete && !hasNoReading && !hasOptimisedChargingHold && !hasFullOnAdapter && !hasInsufficientCharger }
    /// Compact states contain only the three-row power table. Let the native
    /// Form report its content height instead of constraining it to the old
    /// fixed Figma frame, which made the Form's scroll container compete with
    /// the rows for vertical space.
    var usesIntrinsicPowerTableHeight: Bool {
        !setupIncomplete && !isDesktop && (hasNoReading || !showsComponents)
    }
    var panelHeight: CGFloat? {
        if setupIncomplete { return setupSaveFailed ? WattSpacing.setupPanelErrorHeight : WattSpacing.setupPanelHeight }
        // Let the native retry Form size its content without clipping controls.
        if hasNoReading { return nil }
        if usesIntrinsicPowerTableHeight { return nil }
        if hasInsufficientCharger { return WattSpacing.insufficientChargerPanelHeight }
        if hasOptimisedChargingHold { return WattSpacing.chargingHoldPanelHeight }
        if hasFullOnAdapter || !includesComponents { return WattSpacing.compactPanelHeight }
        return isDesktop ? WattSpacing.desktopPanelHeight : componentsOff ? WattSpacing.panelComponentsOffHeight : WattSpacing.panelHeight
    }
    var subtitle: String? {
        if hasNoReading { return NoReadingPresentation.subtitle }
        if hasInsufficientCharger { return reading.insufficientChargerMessage }
        if hasFullOnAdapter { return "100% · running straight off the charger" }
        if hasOptimisedChargingHold {
            return "Because Optimised Battery Charging is on. Charging resumes before you usually unplug."
        }
        if isDesktop { return reading.detail ?? "No battery, so it’s all draw" }
        guard available(reading.capabilities.battery) else { return nil }
        if reading.batteryState == .discharging && reading.watts == nil { return nil }
        return [reading.batteryPercentage.map { "\($0)%" }, reading.detail].compactMap { $0 }.joined(separator: " · ")
    }
    var chargerSubtitle: String? { available(reading.capabilities.charger) ? chargerDescription : nil }
    var title: String {
        if hasNoReading { return NoReadingPresentation.title }
        if hasInsufficientCharger { return InsufficientChargerPresentation.title }
        if hasFullOnAdapter { return "Full" }
        if case .optimisedChargingHold(let percentage) = state { return "Holding at \(percentage)%" }
        if isDesktop { return "Drawing" }
        switch reading.batteryState {
        case .charging: return "Charging"
        case .discharging: return "On battery"
        case .full: return "Fully Charged"
        case .chargingHold: return "Charging Paused"
        case .noBattery: return "No Battery"
        case .unknown: return "Power"
        }
    }
    var accessibilitySummary: String {
        if hasNoReading {
            return [NoReadingPresentation.title, NoReadingPresentation.subtitle,
                    reading.freshness == .stale ? "Stale reading" : nil]
                .compactMap { $0 }.joined(separator: ", ")
        }
        return [title, headlineValue, subtitle, reading.freshness == .stale ? "Stale reading" : nil]
            .compactMap { $0 }.joined(separator: ", ")
    }

    /// VoiceOver reads the panel summary as one phrase. Keep the visible
    /// presentation summary above for existing callers and tests.
    var voiceOverSummary: String {
        if hasNoReading {
            return accessibilitySummary
        }
        let destination: String
        switch reading.batteryState {
        case .charging: destination = "Into battery"
        case .discharging: destination = "From battery"
        default: return accessibilitySummary
        }
        let detail = (subtitle?.isEmpty == false ? subtitle! : "No additional detail")
            .replacingOccurrences(of: "full in about ", with: "full in ")
        return [title, headlineValue, destination + " · " + detail]
            .joined(separator: ", ")
    }

    var accessibilityRows: [StatusPanelAccessibilityRow] {
        var rows: [StatusPanelAccessibilityRow] = []
        if !isDesktop {
            rows += [
                StatusPanelAccessibilityRow(label: "Charger input", value: charger, subtitle: chargerSubtitle),
                StatusPanelAccessibilityRow(label: "System draw", value: system),
                StatusPanelAccessibilityRow(label: "Battery", value: battery)
            ]
        }
        if showsComponents {
            rows += components.isEmpty
                ? [StatusPanelAccessibilityRow(label: "Components", value: "—", subtitle: "Unavailable")]
                : components.map { StatusPanelAccessibilityRow(label: $0.name, value: PowerFormatter.watts($0.watts, signed: false)) }
        }
        return rows
    }
}

struct StatusPanelAccessibilityRow: Equatable {
    let label: String
    let value: String
    let subtitle: String?

    init(label: String, value: String, subtitle: String? = nil) {
        self.label = label
        self.value = value
        self.subtitle = subtitle
    }

    var spokenValue: String {
        [value == "—" ? "Unavailable" : value, subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct StatusPanelView: View {
    let reading: PowerReading
    var chargerDescription: String? = nil
    var helperSwitchedOff = false
    var componentReadingsEnabled = true
    var includesComponents = true
    var setupIncomplete = false
    var setupSaveFailed = false
    var onContinueSetup: () -> Void = {}
    var onRetry: () -> Void = {}
    var isRetrying = false
    let onSettings: () -> Void
    let onQuit: () -> Void
    private var accessibilityPrefix: String { setupIncomplete ? "J5.2" : model.hasNoReading ? "J8.1" : model.hasInsufficientCharger ? "J6.4" : model.hasFullOnAdapter ? "J6.3" : model.hasOptimisedChargingHold ? "J6.2" : !includesComponents ? (reading.batteryState == .discharging ? "J6.5" : "J6.1") : model.isDesktop ? "J4.3" : reading.batteryState == .discharging ? "C02" : "C01" }
    private var model: StatusPanelModel { StatusPanelModel(reading: reading, chargerDescription: chargerDescription, helperSwitchedOff: helperSwitchedOff, componentReadingsEnabled: componentReadingsEnabled, includesComponents: includesComponents, setupIncomplete: setupIncomplete, setupSaveFailed: setupSaveFailed) }

    var body: some View {
        VStack(alignment: .leading, spacing: WattSpacing.md) {
            if setupIncomplete {
                GroupBox {
                    VStack(alignment: .leading, spacing: WattSpacing.xs) {
                        HStack {
                            VStack(alignment: .leading, spacing: WattSpacing.xxs) {
                                Text(SetupPromptPresentation.title).font(WattTypography.body)
                                Text(SetupPromptPresentation.subtitle)
                                    .font(WattTypography.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(SetupPromptPresentation.action, action: onContinueSetup)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("J5.2.continue")
                        }
                        if setupSaveFailed {
                            Text(SetupPromptPresentation.failure)
                                .font(WattTypography.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("J5.2.setup")
                .padding(.horizontal, WattSpacing.xl)
                .padding(.top, WattSpacing.lg)
            }
            VStack(alignment: .leading, spacing: WattSpacing.xs) {
                if model.hasNoReading {
                    Label {
                        Text(model.title)
                    } icon: {
                        Image(systemName: NoReadingPresentation.symbol)
                    }
                    .font(WattTypography.headline)
                } else if model.hasInsufficientCharger {
                    Label(model.title, systemImage: InsufficientChargerPresentation.symbol)
                        .font(WattTypography.bodyEmphasized)
                } else {
                    Text(model.title).font(WattTypography.bodyEmphasized).foregroundStyle(.secondary)
                }
                Text(model.headlineValue).font(WattTypography.largeTitle).monospacedDigit()
                if let subtitle = model.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(WattTypography.subheadline).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.summaryLabel)
            .accessibilityValue(model.voiceOverSummary)
            .accessibilitySortPriority(4)
            .accessibilityIdentifier("\(accessibilityPrefix).summary")
            .padding(.horizontal, WattSpacing.xl)
            .padding(.top, setupIncomplete ? 0 : WattSpacing.lg)

            Form {
                if model.hasNoReading {
                    LabeledContent(NoReadingPresentation.retryLabel) {
                        Button(NoReadingPresentation.retryAction, action: onRetry)
                            .buttonStyle(.bordered)
                            .disabled(isRetrying)
                            .accessibilityIdentifier("J8.1.retry")
                    }
                } else if !model.isDesktop {
                    Section {
                        row("Charger input", value: model.charger, subtitle: model.chargerSubtitle)
                        row("System draw", value: model.system)
                        row("Battery", value: model.battery)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Power")
                    .accessibilitySortPriority(3)
                }

                if model.showsComponents {
                    Section {
                        if model.helperSwitchedOff {
                            LabeledContent {
                                Button(HelperOffPresentation.action, action: onSettings)
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("J3.2.fix")
                            } label: {
                                VStack(alignment: .leading, spacing: WattSpacing.xxs) {
                                    Label(HelperOffPresentation.title, systemImage: HelperOffPresentation.symbol)
                                        .font(WattTypography.body)
                                    Text(HelperOffPresentation.subtitle)
                                        .font(WattTypography.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if model.componentsOff {
                            LabeledContent {
                                Button("Turn On…", action: onSettings)
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("J2.2.turnOn")
                            } label: {
                                VStack(alignment: .leading, spacing: WattSpacing.xxs) {
                                    Text("Off").font(WattTypography.body)
                                    Text("Approve the helper to see CPU/GPU estimates.")
                                        .font(WattTypography.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } else if model.components.isEmpty {
                            row("Components", value: "—", subtitle: "Unavailable")
                        } else {
                            ForEach(model.components) { component in
                                row(component.name, value: PowerFormatter.watts(component.watts, signed: false))
                            }
                            if reading.componentEstimate != nil {
                                Text("Apple’s power estimates. Display, SSD and Other are unavailable.")
                                    .font(WattTypography.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } header: {
                        Text("Components")
                            .accessibilityAddTraits(.isHeader)
                    }
                    .accessibilitySortPriority(2)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(model.usesIntrinsicPowerTableHeight)
            .fixedSize(horizontal: false, vertical: model.usesIntrinsicPowerTableHeight)

            HStack {
                Button("Settings…", action: onSettings)
                    .keyboardShortcut(",", modifiers: .command)
                    .accessibilityIdentifier("\(accessibilityPrefix).settings")
                Spacer()
                Button("Quit Watt?", action: onQuit)
                    .keyboardShortcut("q", modifiers: .command)
                    .accessibilityIdentifier("\(accessibilityPrefix).quit")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, WattSpacing.xl)
            .padding(.bottom, WattSpacing.lg)
            .accessibilitySortPriority(1)
        }
        .frame(width: WattSpacing.panelWidth, height: model.panelHeight)
        // The MenuBarExtra window supplies its own native material and rounded chrome.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Watt? live power panel")
    }

    private func row(_ label: String, value: String, subtitle: String? = nil) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        } label: {
            VStack(alignment: .leading, spacing: WattSpacing.xxs) {
                Text(label)
                if let subtitle {
                    Text(subtitle).font(WattTypography.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(StatusPanelAccessibilityRow(label: label, value: value, subtitle: subtitle).spokenValue)
    }
}

enum SetupPromptPresentation {
    static let title = "Finish setup"
    static let subtitle = "2 steps left"
    static let action = "Continue…"
    static let failure = "Couldn’t save. Try again."

    static func canPresent(_ state: OnboardingState) -> Bool {
        !state.completed && [.welcomeClosed, .runningDefaults].contains(state.checkpoint)
    }
}


// SF Pro's filled warning-triangle glyph in node 29:9749 maps to this native SF Symbol.
enum HelperOffPresentation {
    static let title = "Helper is off"
    static let subtitle = "Showing Delta until it’s back."
    static let action = "Fix…"
    static let symbol = "exclamationmark.triangle.fill"
}
