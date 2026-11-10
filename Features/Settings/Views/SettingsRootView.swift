import SwiftUI
import Combine

#if SWIFT_PACKAGE
import WattHelperShared
#endif

enum HelperUnavailableReason: Equatable {
    case missingBundle, signingRequired, verificationFailed, configurationFailed, installationRequired

    static func configurationFailure(_ error: Error, packagedHelperPresent: Bool) -> Self {
        guard packagedHelperPresent else { return .missingBundle }
        if error is ProtectedTrustError { return .installationRequired }
        if let signing = error as? HelperSigningError {
            switch signing {
            case .missingTeam: return .signingRequired
            case .invalidRequirement, .invalidSignature: return .verificationFailed
            }
        }
        if let failure = error as? ServiceFailure, [.untrustedIdentity, .invalidData].contains(failure) {
            return .verificationFailed
        }
        return .configurationFailed
    }

    var message: String {
        switch self {
        case .missingBundle:
            return "This build does not include Watt? Helper. Install a complete build to enable CPU/GPU estimates."
        case .signingRequired:
            return "This build selected certificate-based helper trust but has no signing team configured. Use the GitHub administrator installer for the ad-hoc build."
        case .verificationFailed:
            return "Watt? Helper could not pass package or code-identity verification. Reinstall the verified GitHub build with the administrator installer."
        case .configurationFailed:
            return "Watt? Helper could not be configured. Relaunch Watt? or reinstall a complete build."
        case .installationRequired:
            return "Install Watt? Helper with the administrator installer, then launch the installed app. No Apple certificate is required."
        }
    }
}

/// C05: system-owned grouped form and window chrome; shared preference bindings.
struct SettingsRootView: View {
    var helperExcerpt = false
    var componentsExcerpt = false
    var menuBarExcerpt = false
    /// J8.3's native launch fixture shows only the configured Menu Bar and General rows.
    /// Production Settings continues to use the complete shared preferences surface.
    var relaunchExcerpt = false
    var removalExcerpt = false
    var removedExcerpt = false
    var uninstallExcerpt = false
    var confirmUninstallExcerpt = false
    static let uninstallMessage = "Removes the helper, your settings and the login item, then moves Watt? to the Trash. Nothing is left behind."
    static let removeHelperTitle = "Remove the helper?"
    static let removeHelperMessage = "Components stop and the menu bar switches to Delta. Turn it back on any time."
    static let componentsSubtitle = "Two fit."
    static let componentSelectionSubtitle = "Two fit. More crowd the menu bar."
    static let fullSettingsComponentSubtitle = "In Components mode. Two fit; more crowd the menu bar."
    static let title = "Watt? Settings"
    private enum FocusedControl: Hashable { case show }
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var powerStore: PowerReadingStore
    @State private var removal: AppRouter.SettingsRemoval?
    @State private var removalMessage: String?
    @State private var removing = false
    @State private var uninstallPresentation: UUID?
    @FocusState private var focusedControl: FocusedControl?

    var body: some View {
        let intent = router.uninstallIntent
        let showsRemovedExcerpt = (removalExcerpt || removedExcerpt) && router.settingsHelperSetup.wasRemoved
        Form {
            if uninstallExcerpt {
                generalSection
            } else if showsRemovedExcerpt {
                Section("Menu Bar") {
                    Picker("Show", selection: $preferences.displayMode) {
                        ForEach(WattDisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("settings.show")
                }
                SettingsHelperRows(setup: router.settingsHelperSetup, removing: removing,
                                   sectionTitle: "Helper",
                                   remove: { removal = .helper })
            } else if removalExcerpt {
                SettingsHelperRows(setup: router.settingsHelperSetup, removing: removing,
                                   sectionTitle: "Helper",
                                   remove: { removal = .helper })
            } else if relaunchExcerpt {
                Section("Menu Bar") {
                    Picker("Show", selection: $preferences.displayMode) {
                        ForEach(WattDisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("settings.show")
                    Toggle("Show symbol", isOn: $preferences.showSymbol)
                        .accessibilityIdentifier("settings.showSymbol")
                }
                Section("General") {
                    Toggle("Open at login", isOn: $preferences.openAtLogin)
                        .accessibilityIdentifier("settings.openAtLogin")
                    LabeledContent("Version", value: version)
                        .accessibilityIdentifier("settings.version")
                }
            } else {
                Section {
                    Picker("Show", selection: $preferences.displayMode) {
                        ForEach(WattDisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("settings.show")
                    .focused($focusedControl, equals: .show)
                    if menuBarExcerpt {
                        LabeledContent {
                            ComponentSelectionMenu(preferences: preferences, powerStore: powerStore,
                                                   helper: router.settingsHelperSetup)
                        } label: {
                            Text("Components")
                            Text(componentsExcerpt || menuBarExcerpt
                                 ? Self.componentSelectionSubtitle
                                 : Self.fullSettingsComponentSubtitle)
                        }
                    }
                    if !helperExcerpt {
                        if !menuBarExcerpt {
                            Toggle("Show symbol", isOn: $preferences.showSymbol)
                                .accessibilityIdentifier("settings.showSymbol")
                        }
                        Picker("Precision", selection: $preferences.precision) {
                            ForEach(WattPrecision.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .accessibilityIdentifier("settings.precision")
                    }
                    if !menuBarExcerpt && (!helperExcerpt || componentsExcerpt) {
                        LabeledContent {
                            ComponentSelectionMenu(preferences: preferences, powerStore: powerStore,
                                                   helper: router.settingsHelperSetup)
                        } label: {
                            Text("Components")
                            Text(componentsExcerpt
                                 ? Self.componentsSubtitle
                                 : Self.fullSettingsComponentSubtitle)
                        }
                    }
                } header: {
                    Text("Menu Bar")
                } footer: {
                    if !helperExcerpt && !menuBarExcerpt { Text("Menu bar full? Choose Icon and Watt? stays put.") }
                }
                if !helperExcerpt && !menuBarExcerpt {
                    Section("Readings") {
                        LabeledContent {
                            Picker("Update", selection: $preferences.updateInterval) {
                                ForEach(updateChoices, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .accessibilityIdentifier("settings.update")
                            .accessibilityValue(preferences.updateInterval)
                            .accessibilityHint("Faster uses a little more energy.")
                        } label: {
                            Text("Update")
                            Text("Faster uses a little more energy.")
                        }
                        Toggle(isOn: $preferences.smoothReadings) {
                            Text("Smooth readings")
                            Text(preferences.smoothReadings
                                 ? "On — averages the last 5 seconds, so the number doesn’t jump."
                                 : "Off — shows each reading without averaging.")
                        }
                        .accessibilityIdentifier("settings.smoothReadings")
                    }
                }
                if !menuBarExcerpt {
                    SettingsHelperRows(setup: router.settingsHelperSetup,
                                       removing: removing,
                                       sectionTitle: helperExcerpt ? "Helper" : "Component Readings",
                                       remove: { removal = .helper })
                }
                if helperExcerpt, let removalMessage {
                    Text(removalMessage).accessibilityIdentifier("settings.removalResult")
                }
                if !helperExcerpt && !menuBarExcerpt {
                    Section("Notifications") {
                        Toggle(isOn: $preferences.chargerNotification) {
                            Text("Charger can’t keep up")
                            Text("When your Mac draws more than the charger gives for 5 minutes.")
                        }
                        Toggle("Fully charged", isOn: $preferences.fullyChargedNotification)
                        if router.notificationAuthorization == .denied {
                            Text("Notifications unavailable. Allow Watt? in System Settings.")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("settings.notificationsUnavailable")
                        }
                    }
                    generalSection
                }
            }
        }
        .modifier(HelperNotApprovedPresentation(router: router, preferences: preferences, origin: .settings))
        .formStyle(.grouped)
        .pickerStyle(.menu)
        .toggleStyle(.switch)
        .buttonStyle(.bordered)
        .navigationTitle(Self.title)
        .defaultFocus($focusedControl, .show)
        .frame(width: uninstallExcerpt || (removalExcerpt && router.settingsHelperSetup.reconnectedFromLastInstall) ? 540 : helperExcerpt || menuBarExcerpt || relaunchExcerpt || removalExcerpt || showsRemovedExcerpt ? WattSpacing.settingsExcerptWidth : WattSpacing.settingsWidth)
        .fixedSize(horizontal: false, vertical: uninstallExcerpt || menuBarExcerpt || relaunchExcerpt || removalExcerpt || showsRemovedExcerpt)
        .frame(minHeight: uninstallExcerpt || menuBarExcerpt || relaunchExcerpt || removalExcerpt || showsRemovedExcerpt ? nil : helperExcerpt ? (componentsExcerpt ? 330 : WattSpacing.settingsExcerptHeight) : WattSpacing.settingsContentHeight,
               idealHeight: uninstallExcerpt || menuBarExcerpt || relaunchExcerpt || removalExcerpt || showsRemovedExcerpt ? nil : helperExcerpt ? (componentsExcerpt ? 330 : WattSpacing.settingsExcerptHeight) : WattSpacing.settingsContentHeight,
               maxHeight: uninstallExcerpt || menuBarExcerpt || relaunchExcerpt || removalExcerpt || showsRemovedExcerpt ? nil : helperExcerpt ? (componentsExcerpt ? 330 : WattSpacing.settingsExcerptHeight) : WattSpacing.settingsContentHeight)
        .alert(removal == .helper ? Self.removeHelperTitle : "Uninstall Watt?", isPresented: Binding(
            get: { removal != nil }, set: { if !$0 { removal = nil } }
        ), presenting: removal) { target in
            Button("Cancel", role: .cancel) {
                if let intent { router.cancelUninstall(intent) }
            }
            .keyboardShortcut(.cancelAction)
            Button(target == .helper ? "Remove" : "Uninstall", role: .destructive) {
                let presentation = uninstallPresentation
                removing = true
                Task {
                    let outcome: RemovalOutcome
                    if target == .helper {
                        outcome = await router.removeVerifiedHelper(preferences: preferences)
                    } else {
                        guard let intent, let confirmed = await router.confirmUninstall(intent) else {
                            removing = false
                            return
                        }
                        outcome = confirmed
                    }
                    guard router.isCurrentUninstallPresentation(presentation) else { return }
                    if target == .uninstall {
                        // The adapter owns cleanup; never rewrite preferences after uninstall.
                        switch outcome {
                        case .verifiedAbsent: removalMessage = "Watt? removed."
                        case .cancelled: removalMessage = nil
                        case .adminRequired: removalMessage = "Administrator access is required. Use the Watt? installer to remove this installation."
                        case .handoffAccepted: removalMessage = "Watt? will close while removal finishes."
                        default: removalMessage = "Removal could not be verified. No successful removal has been reported."
                        }
                    } else if case .verifiedAbsent = outcome {
                        preferences.componentReadings = false
                        router.settingsHelperSetup.resetAfterVerifiedRemoval()
                        removalMessage = target == .helper ? "Helper removed." : "Watt? removed."
                    } else if case .adminRequired = outcome {
                        removalMessage = "Administrator access is required. Use the Watt? installer to remove the helper."
                    } else if case .cancelled = outcome {
                        removalMessage = nil
                    } else {
                        removalMessage = "Removal could not be verified. No successful removal has been reported."
                    }
                    removing = false
                }
            }
        } message: { target in
            Text(target == .helper ? Self.removeHelperMessage : Self.uninstallMessage)
        }
        .onAppear {
            removing = false
            uninstallPresentation = router.beginUninstallPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window.title == Self.title else { return }
            router.closeUninstallPresentation(uninstallPresentation)
            uninstallPresentation = nil
            removal = nil
        }
        .onDisappear {
            router.closeUninstallPresentation(uninstallPresentation)
            uninstallPresentation = nil
            removal = nil
        }
        .task {
            #if DEBUG
            if J122FixtureLaunch.requested || J113FixtureLaunch.requested,
               router.requestUninstall(presentation: uninstallPresentation, removing: removing) {
                removal = .uninstall
            }
            if J91FixtureLaunch.requested {
                // Fixture preparation verifies its injected helper before opening Settings.
                // Presenting confirmation itself must never perform removal or registration.
                removal = .helper
            }
            #endif
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Open at login", isOn: $preferences.openAtLogin)
                .accessibilityIdentifier("settings.openAtLogin")
            if !confirmUninstallExcerpt {
                Toggle("Check for updates automatically", isOn: $preferences.checkForUpdatesAutomatically)
                    .accessibilityIdentifier("settings.automaticUpdates")
            }
            LabeledContent {
                Button("Uninstall…", role: .destructive) {
                    if router.requestUninstall(presentation: uninstallPresentation, removing: removing) {
                        removalMessage = nil
                        removal = .uninstall
                    }
                }
                    .disabled(!router.canRequestUninstall(presentation: uninstallPresentation, removing: removing))
                    .accessibilityIdentifier("settings.uninstall")
            } label: {
                Text("Uninstall Watt?")
                Text(confirmUninstallExcerpt ? Self.uninstallMessage : "Removes the helper and your settings, then moves Watt? to the Trash.")
            }
            if !confirmUninstallExcerpt {
                LabeledContent("Version", value: version)
                    .accessibilityIdentifier("settings.version")
            }
            if let removalMessage { Text(removalMessage).accessibilityIdentifier("settings.removalResult") }
            if preferences.persistenceFailure != nil { Text("Your settings could not be saved.").foregroundStyle(.secondary) }
        }
    }

    private var updateChoices: [String] {
        let choices = ["Every second", "Every 2 seconds", "Every 5 seconds"]
        return choices.contains(preferences.updateInterval) ? choices : [preferences.updateInterval] + choices
    }
    private var version: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))"
    }
}

/// Shared native rows for Settings and the J2.3/J2.4 excerpt fixtures.
struct SettingsHelperRows: View {
    static let reconnectNote = "Reconnected from your last install."
    static let helperTitle = "Helper"
    static let statusTitle = "Status"
    static let pendingSubtitle = "Turn on “Watt? Helper” in Login Items & Extensions."
    static let pendingStatus = "Waiting for approval…"
    static let openSettings = "Open System Settings"
    static let statusSubtitle = "CPU/GPU estimates appear only when both are available. Display, SSD and Other are unavailable."
    static let privacy = "Reads Apple’s CPU/GPU power estimates. No network, nothing leaves this Mac."
    static let turnOn = "Turn On…"
    static let approvalNote = "Administrator approval is required in Login Items & Extensions."
    @ObservedObject var setup: SettingsHelperSetup
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    let removing: Bool
    let sectionTitle: String
    let remove: () -> Void

    var body: some View {
        Section {
            LabeledContent {
                Text(setup.statusTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.helper.status")
            } label: {
                Text(Self.statusTitle)
                Text(setup.statusSubtitle)
            }
            LabeledContent {
                if setup.state == .requiresApproval {
                    Button(Self.openSettings) { router.openApprovalSettings() }
                        .buttonStyle(.borderedProminent)
                        .disabled(removing)
                        .accessibilityIdentifier("settings.helper.openSettings")
                }
                if setup.canRepairHelper {
                    Button("Repair Helper…") { Task { await setup.repairHelper() } }
                        .disabled(removing || setup.isLoading)
                        .accessibilityIdentifier("settings.helper.repair")
                }
                if setup.canRemoveHelper {
                    Button("Remove…", action: remove)
                        .buttonStyle(.bordered)
                        .disabled(removing || setup.isLoading)
                        .accessibilityIdentifier("settings.helper.remove")
                } else if !setup.helperServiceAvailable {
                    Text(setup.actionTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.helper.turnOn")
                } else {
                    if setup.wasRemoved {
                        Button(setup.actionTitle) { Task { await setup.turnOn(preferences: preferences) } }
                            .buttonStyle(.bordered)
                            .disabled(removing || !setup.canTurnOn)
                            .accessibilityIdentifier("settings.helper.turnOn")
                    } else {
                        Button(setup.actionTitle) { Task { await setup.turnOn(preferences: preferences) } }
                        .buttonStyle(.borderedProminent)
                        .disabled(removing || !setup.canTurnOn)
                        .accessibilityIdentifier("settings.helper.turnOn")
                    }
                }
            } label: {
                Text(Self.helperTitle)
                if setup.helperServiceAvailable && !setup.wasRemoved && setup.state != .requiresApproval {
                    Text(Self.privacy)
                }
            }
            if setup.helperOn, let captureDiagnostic = setup.captureDiagnostic {
                Button("Export Helper Diagnostic…") { Task { await captureDiagnostic() } }
                    .accessibilityIdentifier("settings.helper.diagnostic")
            }
            if setup.isLoading { ProgressView().accessibilityLabel("Checking helper") }
            if let message = setup.message { Text(message).accessibilityIdentifier("settings.helper.result") }
            if setup.state == .denied {
                Button("Open System Settings") { router.openApprovalSettings() }
            }
            if setup.isLoading {
                Button("Cancel", role: .cancel) { setup.cancel() }
            }
        } header: {
            if sectionTitle == "Component Readings" {
                // Keep the full Settings section title explicit for source-level
                // contracts; the setup excerpt uses the title Helper.
                Text("Component Readings")
            } else {
                Text(sectionTitle)
            }
        } footer: {
            if setup.helperOn && setup.reconnectedFromLastInstall {
                Text(Self.reconnectNote).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.helper.reconnected")
            } else if setup.helperServiceAvailable && !setup.wasRemoved && !setup.helperOn
                        && setup.state != .requiresApproval { Text(Self.approvalNote) }
        }
        .onExitCommand {
            if setup.isLoading || setup.state == .requiresApproval { setup.cancel() }
        }
        .task { await setup.refreshStatus(preferences: preferences) }
        .onDisappear { setup.close() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await setup.refreshStatus(preferences: preferences) } }
        }
    }
}

/// Settings presentation over the shared approval coordinator. No OS approval is synthesized.
@MainActor
final class SettingsHelperSetup: ObservableObject {
    enum State: Equatable { case notDetermined, loading, requiresApproval, denied, connected, cancelled, failed(ServiceFailure) }
    @Published private(set) var state: State = .notDetermined {
        didSet {
            guard state != oldValue else { return }
            if state != .requiresApproval && state != .loading {
                approvalDeadline?.cancel()
                approvalDeadline = nil
            }
            if state == .connected {
                wasRemoved = false
                hasVerifiedConnection = true
                authenticatedAt = Date()
            }
            // Only verified loss after an authenticated connection is J3.2, not first setup.
            if hasVerifiedConnection && (state == .denied || state == .requiresApproval
                || state == .failed(.disconnected)) {
                helperSwitchedOff = true
                failureReported = true // Runtime revocation is a panel state, not J3.1.
            }
            let reason: ServiceFailure
            switch state {
            case .denied: reason = .denied
            case .cancelled: reason = .cancelled
            case .failed(.timedOut): reason = .timedOut
            default: return
            }
            if !helperSwitchedOff { activePreferences?.componentReadings = false }
            if !failureReported {
                failureReported = true
                onNotApproved(reason)
            }
        }
    }
    /// Set only after the removal adapter has verified absence, never by a registration reply.
    @Published private(set) var wasRemoved = false
    @Published private(set) var helperSwitchedOff = false
    @Published private(set) var reconnectedFromLastInstall = false
    func acceptVerifiedReconnect() {
        attempt = UUID()
        activeToken = nil
        approvals.reconcileEffective(.connected)
        state = .connected
        reconnectedFromLastInstall = true
    }
    private var hasVerifiedConnection = false
    private var authenticatedAt: Date?
    /// Called only with a validated telemetry-store update, not registration acknowledgement.
    func confirmRecoveredComponents(_ reading: PowerReading) {
        guard helperSwitchedOff, helperOn, let authenticatedAt,
              reading.source == .helper, reading.freshness == .fresh,
              reading.timestamp >= authenticatedAt, reading.timestamp <= Date(),
              reading.capabilities.components == .available, !reading.components.isEmpty,
              (try? reading.validate()) != nil else { return }
        helperSwitchedOff = false
    }
    private var failureReported = false
    var onNotApproved: (ServiceFailure) -> Void = { _ in }
    private weak var activePreferences: PreferencesStore?
    let approvals: HelperApprovalStore
    @Published var service: (any HelperService)? {
        didSet {
            attempt = UUID()
            activeToken = nil
            approvals.close(.settings)
            state = .notDetermined
            observeLifecycle()
        }
    }
    private var lifecycleObservation: AnyCancellable?
    private var activeToken: ApprovalToken?
    private var attempt = UUID()
    private var approvalDeadline: Task<Void, Never>?
    var approvalTimeoutNanoseconds: UInt64 = 120_000_000_000

    private func awaitApprovalDeadline() {
        guard activeToken != nil, approvalDeadline == nil else { return }
        approvalDeadline = Task { [weak self, delay = approvalTimeoutNanoseconds] in
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            guard let self, self.activeToken != nil else { return }
            self.attempt = UUID() // Invalidate any foreground query that is still in flight.
            self.applyStatus(.failed(.timedOut))
        }
    }
    init(service: (any HelperService)? = nil, approvals: HelperApprovalStore? = nil) {
        self.service = service
        self.approvals = approvals ?? HelperApprovalStore()
        observeLifecycle()
    }
    var captureDiagnostic: (() async -> Void)?
    private var repairReceipt: (() -> OperationReceipt)?
    private var pendingRepair: () -> Bool = { false }

    func configureRepair(receipt: @escaping () -> OperationReceipt, pending: @escaping () -> Bool = { false }) {
        repairReceipt = receipt
        pendingRepair = pending
    }

    var canRepairHelper: Bool {
        repairReceipt != nil && (canRemoveHelper || pendingRepair()) && !helperOn
            && state != .requiresApproval && !isLoading
    }

    func repairHelper() async {
        guard canRepairHelper, let lifecycle = service as? HelperLifecycleAdapter,
              let repairReceipt else { return }
        let current = UUID(); attempt = current
        state = .loading
        let result = await lifecycle.update(receipt: repairReceipt())
        guard current == attempt else { return }
        switch result {
        case .success(.connected): applyStatus(.connected)
        case .success(.awaitingApproval): applyStatus(.pending)
        case .failure(let error): applyStatus(.failed(error))
        default: applyStatus(.unknown)
        }
    }

    var canRemoveHelper: Bool {
        helperOn || (service as? HelperLifecycleAdapter)?.registrationPresent == true
    }
    @Published var unavailableReason: HelperUnavailableReason = .missingBundle
    var helperServiceAvailable: Bool { service != nil || helperOn }
    var statusTitle: String {
        guard helperServiceAvailable else { return "Unavailable" }
        return state == .requiresApproval ? SettingsHelperRows.pendingStatus : helperOn ? "On" : "Off"
    }
    var statusSubtitle: String {
        guard helperServiceAvailable else { return unavailableReason.message }
        return state == .requiresApproval ? SettingsHelperRows.pendingSubtitle : SettingsHelperRows.statusSubtitle
    }
    var isLoading: Bool { state == .loading }
    // Preferences and telemetry samples are not evidence that a helper is installed/alive.
    var helperOn: Bool {
        guard state == .connected, hasVerifiedConnection else { return false }
        if let lifecycle = service as? HelperLifecycleAdapter { return lifecycle.state == .connected }
        return true // Verified P05 reconnect is also evidence, even without a Settings-owned service.
    }
    // Unsigned builds have no registration-capable service.
    var canTurnOn: Bool { service != nil && !isLoading && !helperOn }

    private func observeLifecycle() {
        lifecycleObservation = nil
        guard let lifecycle = service as? HelperLifecycleAdapter else { return }
        lifecycleObservation = lifecycle.$state.sink { [weak self] updated in
            guard let self, self.state == .connected, updated != .connected else { return }
            // Adapter publishes on its MainActor, including disconnect/IPC failure/revocation.
            self.attempt = UUID()
            self.helperSwitchedOff = true // Loss stays visible even if withdrawing intent cannot persist.
            self.failureReported = true
            self.applyStatus(updated == .awaitingApproval ? .pending :
                updated == .disabled ? .failed(.denied) : .failed(.disconnected))
        }
    }

    // Refresh never registers or grants approval. Only a still-active Settings token may opt in.
    // HelperService has no event contract; query-only injected services refresh on appearance/activation.
    func refreshStatus(preferences: PreferencesStore? = nil) async {
        guard !isLoading else { return }
        if let preferences { activePreferences = preferences }
        let current = UUID(); attempt = current
        guard let service else { state = .notDetermined; return }
        if state != .connected { state = .loading }
        let status = await service.reconcile(receipt: approvals.checkpoint.receipt)
        guard attempt == current else { return }
        if let lifecycle = service as? HelperLifecycleAdapter,
           case .connected = status, lifecycle.state != .connected {
            applyStatus(.failed(.disconnected))
        } else {
            if case .connected = status, let token = activeToken, let preferences {
                do {
                    let eligible = try approvals.receive(status, operationID: token.operationID,
                                                         generation: token.generation, origin: .settings)
                    if eligible.contains(token) { preferences.componentReadings = true }
                    activeToken = nil
                } catch {
                    state = .failed(.persistence)
                    return
                }
            }
            applyStatus(status)
        }
    }

    /// Closing detaches only presentation; durable shared interest survives.
    func close() {
        failureReported = true
        approvalDeadline?.cancel()
        approvalDeadline = nil
        attempt = UUID()
        activeToken = nil
        approvals.close(.settings)
        if isLoading { state = .notDetermined }
    }

    private func applyStatus(_ status: HelperReconciliation) {
        if hasVerifiedConnection {
            switch status {
            case .absent, .pending, .failed(.denied), .failed(.disconnected):
                helperSwitchedOff = true
                failureReported = true
            default: break
            }
        }
        switch status {
        case .connected: state = .connected
        case .pending:
            state = .requiresApproval
            awaitApprovalDeadline()
        case .absent: state = .notDetermined
        case .unknown: state = .failed(.unknownStatus)
        case .failed(let reason):
            activeToken = nil
            do { try approvals.withdraw(.settings, reason: reason) }
            catch { state = .failed(.persistence); return }
            state = reason == .denied ? .denied : reason == .cancelled ? .cancelled : .failed(reason)
        }
    }
    var actionTitle: String {
        guard service != nil || helperOn else { return "Unavailable" }
        switch state {
        case .failed, .denied, .cancelled: return "Retry"
        case .requiresApproval: return "Check Approval"
        default: return SettingsHelperRows.turnOn
        }
    }
    var message: String? {
        switch state {
        case .notDetermined: return !helperServiceAvailable
            ? unavailableReason.message
            : nil
        case .loading: return "Checking helper…"
        case .requiresApproval: return nil // The status row owns pending copy; no duplicate footer.
        case .denied: return "Helper access is denied. Allow Watt? Helper in System Settings, then retry."
        case .connected: return nil
        case .cancelled: return "Setup cancelled. macOS approval has not been changed."
        case .failed(.adminRequired): return "Administrator installation is required. Use the Watt? installer, then retry."
        case .failed: return "Helper setup could not be verified. Try again."
        }
    }
    func resetAfterVerifiedRemoval() {
        wasRemoved = true
        reconnectedFromLastInstall = false
        hasVerifiedConnection = false
        helperSwitchedOff = false
        close()
        state = .notDetermined
    }
    func cancel() {
        attempt = UUID() // Late replies may not enable preferences or update this presentation.
        activeToken = nil
        do { try approvals.withdraw(.settings); state = .cancelled }
        catch { state = .failed(.persistence) }
    }
    func turnOn(preferences: PreferencesStore) async {
        guard canTurnOn else { return }
        activePreferences = preferences
        failureReported = false
        approvalDeadline?.cancel()
        approvalDeadline = nil
        let current = UUID(); attempt = current; state = .loading
        guard let service else { state = .failed(.unknownStatus); return }
        do {
            let status = await service.reconcile(receipt: approvals.checkpoint.receipt)
            guard attempt == current else { return }
            let request = try approvals.join(.settings, reconciled: status)
            activeToken = request.token
            if request.registrationRequired {
                if case .failure(let reason) = await service.register(receipt: request.receipt) {
                    throw reason
                }
            }
            guard attempt == current else { return }
            // Registration acknowledgement alone never establishes an authenticated connection.
            let confirmed = await service.reconcile(receipt: request.receipt)
            guard attempt == current else { return }
            if case .failed(let reason) = confirmed { throw reason }
            let eligible = try approvals.receive(confirmed, operationID: request.token.operationID,
                                               generation: request.token.generation, origin: .settings)
            switch confirmed {
            case .connected:
                guard eligible.contains(request.token) else { throw ServiceFailure.unknownStatus }
                if let lifecycle = service as? HelperLifecycleAdapter, lifecycle.state != .connected {
                    throw ServiceFailure.disconnected
                }
                preferences.componentReadings = true
                activeToken = nil
                state = .connected
            case .pending:
                state = .requiresApproval
                awaitApprovalDeadline()
            case .failed(let reason): throw reason
            case .absent, .unknown: throw ServiceFailure.unknownStatus
            }
        } catch {
            guard attempt == current else { return }
            let reason = (error as? ServiceFailure) ?? .unknownStatus
            activeToken = nil
            do { try approvals.withdraw(.settings, reason: reason) }
            catch { state = .failed(.persistence); return }
            state = reason == .denied ? .denied : reason == .cancelled ? .cancelled : .failed(reason)
        }
    }
}
