import SwiftUI
import Combine
import ServiceManagement

enum UpdateOfferAction: Equatable { case skip, remindLater, install }
struct UpdateOfferIntent: Equatable {
    let action: UpdateOfferAction
    let version: String
    let automaticUpdates: Bool
}

/// Presentation requests only. Feature progress belongs to PreferencesStore.
@MainActor
final class AppRouter: ObservableObject {
    struct UninstallIntent: Equatable {
        let presentation: UUID
        let generation = UUID()
        let destination = "J12.2"
    }
    @Published private(set) var uninstallIntent: UninstallIntent?
    private var uninstallPresentation: UUID?
    @Published private(set) var uninstallInFlight = false
    @Published private(set) var uninstallCompleted = false
    /// The app composition supplies native termination; unit tests observe without exiting.
    var onUninstalled: () -> Void = {}

    /// P05 owns effects and evidence. No presentation-supplied paths or broad cleanup.
    func configureUninstall(adapter: ScopedRemovalAdapter) {
        var uninstallReceipt: OperationReceipt?
        let previousRemoval = removeFromSettings
        removeFromSettings = { target in
            guard target == .uninstall else { return await previousRemoval(target) }
            guard Set(adapter.manifest.resources.map(\.kind)) == Set(RemovalManifest.Kind.allCases) else {
                return .failed(.invalidData)
            }
            let receipt = uninstallReceipt ?? OperationReceipt(createdAt: Date())
            uninstallReceipt = receipt
            return await adapter.removeOwnedResources(receipt: receipt)
        }
    }

    func beginUninstallPresentation() -> UUID {
        let token = UUID()
        uninstallPresentation = token
        uninstallIntent = nil
        return token
    }

    func canRequestUninstall(presentation: UUID?, removing: Bool) -> Bool {
        presentation != nil && presentation == uninstallPresentation
            && uninstallIntent == nil && !removing && !uninstallInFlight && !uninstallCompleted
    }

    /// J12.1 is consent to open confirmation, never consent to remove anything.
    /// No receipt, preference write, helper call or cleanup belongs at this boundary.
    @discardableResult
    func requestUninstall(presentation: UUID?, removing: Bool) -> Bool {
        guard let presentation, canRequestUninstall(presentation: presentation, removing: removing) else { return false }
        uninstallIntent = UninstallIntent(presentation: presentation)
        return true
    }

    /// Consume exact explicit consent once, before crossing any asynchronous boundary.
    /// Dismissal, reopening and retries cannot reuse an old generation.
    func confirmUninstall(_ intent: UninstallIntent) async -> RemovalOutcome? {
        guard uninstallIntent == intent, uninstallPresentation == intent.presentation,
              !uninstallInFlight, !uninstallCompleted else { return nil }
        uninstallIntent = nil
        uninstallInFlight = true
        defer { uninstallInFlight = false }
        let result = await removeFromSettings(.uninstall)
        if case .verifiedAbsent = result {
            uninstallCompleted = true
            uninstallIntent = nil
            uninstallPresentation = nil
            statusPanelPresented = false
            onUninstalled()
        }
        return result
    }

    func cancelUninstall(_ intent: UninstallIntent) {
        guard uninstallIntent == intent else { return }
        uninstallIntent = nil
    }

    func isCurrentUninstallPresentation(_ presentation: UUID?) -> Bool {
        presentation != nil && presentation == uninstallPresentation
    }

    func dismissUninstallIntent(presentation: UUID?) {
        guard let presentation, presentation == uninstallPresentation else { return }
        uninstallIntent = nil
    }

    func closeUninstallPresentation(_ presentation: UUID?) {
        guard let presentation, presentation == uninstallPresentation else { return }
        uninstallIntent = nil
        uninstallPresentation = nil
    }

    private(set) var leftoverHelper: LeftoverHelperPrompt?

    func configureLeftoverHelper(adapter: ScopedRemovalAdapter, storage: any PreferenceStorage,
                                 installationID: UUID, preferences: PreferencesStore, onCompleted: @escaping (LeftoverHelperPrompt.Action) -> Void = { _ in }) {
        leftoverHelper?.close()
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: installationID)
        prompt.configure(adapter: adapter, installationID: installationID)
        settingsHelperSetup.service = adapter.helper
        prompt.onCompleted = { [weak self] action in
            if action == .reconnect, let self {
                try self.completeLeftoverReconnect(preferences: preferences)
            }
            onCompleted(action)
        }
        leftoverHelper = prompt
    }

    func completeLeftoverReconnect(preferences: PreferencesStore) throws {
        if settingsHelperSetup.reconnectedFromLastInstall && preferences.onboarding.checkpoint == .allSet { return }
        let previous = preferences.onboarding
        var next = previous
        next.checkpoint = .allSet
        next.completed = false
        next.helperOptIn = true
        guard preferences.transitionOnboarding(from: previous, to: next) else { throw ServiceFailure.persistence }
        settingsHelperSetup.acceptVerifiedReconnect()
        present(.onboarding)
    }

    func presentLeftoverHelperAfterReinstall() async {
        guard let leftoverHelper else { return } // No untrusted/default live driver.
        await LeftoverHelperAlert.present(leftoverHelper)
    }

    let helperUpdate = HelperUpdatePrompt()
    let settingsHelperSetup = SettingsHelperSetup()
    @Published var helperNotApprovedPresented = false
    private(set) var failureOrigin: ApprovalOrigin = .settings

    private var helperObservation: AnyCancellable?

    let updates: UpdateStore
    private let updateService: (any UpdateService)?
    private var updateCheck: Task<Void, Never>?
    @Published private(set) var updateOfferIntent: UpdateOfferIntent?
    @Published private(set) var upToDateGeneration: UUID?
    var upToDatePresented: Bool {
        upToDateGeneration == updates.generation && updates.state == .idle
    }
    var upToDateMessage: String { UpToDateAlert.message(version: currentAppVersion) }

    func dismissUpToDate() { upToDateGeneration = nil }

    struct CheckFailurePresentation: Equatable {
        let id: UUID
        let generation: UUID
        let reason: ServiceFailure
    }
    @Published private(set) var checkFailurePresentation: CheckFailurePresentation?
    var couldntCheckPresented: Bool {
        guard let token = checkFailurePresentation else { return false }
        return token.generation == updates.generation && updates.state == .failed(token.reason, nil)
            && updates.downloadReceipt == nil
    }

    @discardableResult
    func dismissCouldntCheck(_ token: CheckFailurePresentation) -> Bool {
        guard couldntCheckPresented, checkFailurePresentation == token else { return false }
        checkFailurePresentation = nil
        return true
    }

    @discardableResult
    func retryCouldntCheck(_ token: CheckFailurePresentation) -> Bool {
        guard couldntCheckPresented, checkFailurePresentation == token else { return false }
        return checkForUpdatesFromMenu(presentationID: beginMenuSetupPresentation())
    }

    func closeUpdatePresentation() {
        checkFailurePresentation = nil
        dismissUpToDate()
        _ = cancelUpdateCheck()
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Version-scoped handoff only. Later stories own scheduling, skip persistence and download.
    /// A checkbox preference is not installation consent and no receipt is created here.
    @discardableResult
    func chooseUpdateOffer(_ action: UpdateOfferAction, version: String, generation: UUID,
                           automaticUpdates: Bool) -> Bool {
        guard updateService != nil, updateOfferIntent == nil,
              updates.generation == generation, updates.state == .available(version: version) else { return false }
        if action != .install {
            guard updates.accept(.idle, generation: generation) else { return false }
            updates.renewGeneration()
        }
        updateOfferIntent = UpdateOfferIntent(action: action, version: version, automaticUpdates: automaticUpdates)
        return true
    }

    /// Save the native offer choice before creating a download receipt or calling the service.
    @discardableResult
    func installOfferedUpdate(version: String, generation: UUID, automaticUpdates: Bool) -> Bool {
        guard updateService != nil, updateOfferIntent == nil, downloadTask == nil, !cancellationPending,
              updates.generation == generation, updates.state == .available(version: version),
              updates.saveAutomaticInstallChoice(automaticUpdates) else { return false }
        return startUpdateDownload(version: version, generation: generation)
    }

    struct ReadyIntent: Equatable {
        enum Action: Equatable { case later, installAndRelaunch }
        let action: Action
        let version: String
        let generation: UUID
        let receipt: OperationReceipt
    }
    @Published private(set) var readyIntent: ReadyIntent?
    private var readyPresentation: UUID?

    var readyReceipt: OperationReceipt? {
        guard downloadVersion != nil, case .staged(let receipt) = updates.state,
              updates.downloadReceipt == receipt else { return nil }
        return receipt
    }

    func beginReadyPresentation() -> UUID? {
        guard readyReceipt != nil, readyIntent?.action != .installAndRelaunch else { return nil }
        readyIntent = nil
        let token = UUID()
        readyPresentation = token
        return token
    }

    func closeReadyPresentation(_ token: UUID?) {
        guard let token, readyPresentation == token else { return }
        readyPresentation = nil
    }

    /// Handoff only: never translates a preference or restored receipt into install consent.
    /// Persist the staged recovery marker before accepting either intent. Failure is retryable.
    @discardableResult
    func chooseReadyUpdate(_ action: ReadyIntent.Action, version: String, generation: UUID,
                           receipt: OperationReceipt, presentation: UUID) -> Bool {
        guard updateService != nil, readyIntent == nil, !cancellationPending,
              readyPresentation == presentation, updates.generation == generation,
              downloadVersion == version, readyReceipt == receipt,
              updates.checkpointStaged(receipt, generation: generation) else { return false }
        readyIntent = ReadyIntent(action: action, version: version, generation: generation, receipt: receipt)
        readyPresentation = nil
        updates.renewGeneration()
        return true
    }

    @Published private(set) var downloadVersion: String?
    @Published private(set) var downloadProgress: UpdateDownloadProgress?
    private var downloadTask: Task<Void, Never>?
    private var cancellationPending = false
    private var discardedDownload: OperationReceipt?

    @discardableResult
    func startUpdateDownload(version: String, generation: UUID) -> Bool {
        guard let updateService, downloadTask == nil, !cancellationPending,
              updates.beginDownload(version: version, receipt: OperationReceipt(createdAt: Date()), generation: generation),
              let receipt = updates.downloadReceipt else { return false }
        downloadVersion = version
        readyIntent = nil; readyPresentation = nil
        downloadProgress = nil
        downloadTask = Task { [weak self] in
            let outcome = await updateService.download(version: version, receipt: receipt) { [weak self] progress in
                guard let self, self.updates.generation == generation,
                      self.updates.downloadReceipt == receipt, progress.isValid,
                      case .downloading = self.updates.state else { return }
                if let prior = self.downloadProgress,
                   (progress.total != prior.total || progress.received < prior.received) { return }
                if self.updates.accept(.downloading(progress: progress.fraction), generation: generation) {
                    self.downloadProgress = progress
                }
            }
            guard let self else { return }
            self.downloadTask = nil
            guard self.updates.generation == generation else { return }
            switch outcome {
            case .success(.staged(let returned)) where returned == receipt:
                self.updates.accept(.staged(receipt), generation: generation)
            case .failure(let reason):
                self.updates.accept(.failed(reason, receipt), generation: generation)
            default:
                self.updates.accept(.failed(.invalidData, receipt), generation: generation)
            }
        }
        return true
    }

    /// Invalidate first even when persistence fails. Keep receipt until exact discard acknowledgement.
    func cancelUpdateDownload() async -> Bool {
        guard !cancellationPending, let receipt = updates.downloadReceipt else { return false }
        switch updates.state {
        case .downloading, .staged, .failed: break
        default: return false
        }
        cancellationPending = true
        defer { cancellationPending = false }
        let generation = updates.renewGeneration()
        downloadTask?.cancel()
        if discardedDownload == receipt {
            return finishDownloadDiscard(receipt, generation: generation)
        }
        guard updates.accept(.failed(.cancelled, receipt), generation: generation), let updateService else { return false }
        guard case .success(.failed(.cancelled, let returned)) = await updateService.cancel(receipt: receipt),
              returned == receipt, updates.generation == generation else { return false }
        // Drain non-cooperative work before cleanup/retry can reuse the adapter.
        await downloadTask?.value
        guard updates.generation == generation,
              case .success(let discarded) = await updateService.discard(receipt: receipt), discarded == receipt else { return false }
        discardedDownload = receipt
        return finishDownloadDiscard(receipt, generation: generation)
    }

    private func finishDownloadDiscard(_ receipt: OperationReceipt, generation: UUID) -> Bool {
        let saved = updates.acknowledgeDiscard(receipt, generation: generation)
        if saved {
            downloadVersion = nil; downloadProgress = nil; updateOfferIntent = nil
            discardedDownload = nil
        }
        return saved
    }

    init(updateService: (any UpdateService)? = nil, updates: UpdateStore? = nil) {
        self.updateService = updateService
        self.updates = updates ?? UpdateStore()
        helperObservation = settingsHelperSetup.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        settingsHelperSetup.onNotApproved = { [weak self] _ in
            self?.failureOrigin = .settings
            self?.helperNotApprovedPresented = true
        }
    }

    /// Async adapter replies must retain the original presentation token, not infer authority from a route.
    func receiveOnboardingApprovalFailure(_ reason: ServiceFailure, token: ApprovalToken,
                                          preferences: PreferencesStore) {
        guard token.origin == .onboarding, settingsHelperSetup.approvals.canNavigate(token) else { return }
        approvalNotGiven(reason, preferences: preferences)
    }

    func approvalNotGiven(_ reason: ServiceFailure, preferences: PreferencesStore,
                          origin: ApprovalOrigin = .onboarding) {
        guard [.denied, .cancelled, .timedOut].contains(reason) else { return }
        guard origin != .onboarding || preferences.onboarding.checkpoint == .approval else { return }
        do { try settingsHelperSetup.approvals.withdraw(origin, reason: reason) }
        catch { return } // Do not present a successful withdrawal after persistence failure.
        preferences.componentReadings = false
        failureOrigin = origin
        helperNotApprovedPresented = true
    }

    func openSettingsAfterApprovalFailure(preferences: PreferencesStore) {
        preferences.componentReadings = false
        helperNotApprovedPresented = false
        openApprovalSettings() // Opening the OS pane is never proof of approval.
    }

    func skipUnapprovedHelper(preferences: PreferencesStore) {
        do { try settingsHelperSetup.approvals.withdraw(failureOrigin) }
        catch { return }
        preferences.componentReadings = false
        helperNotApprovedPresented = false
        if failureOrigin == .onboarding {
            preferences.onboarding.helperOptIn = false
            preferences.onboarding.checkpoint = .allSet
        }
        // Settings stays available for a fresh, explicitly requested retry.
    }
    var present: (AppDestination) -> Void = { _ in }
    enum SettingsRemoval: String, Identifiable {
        case helper, uninstall
        var id: String { rawValue }
    }
    // Installed composition may inject verified service adapters. Never simulate success.
    var removeFromSettings: (SettingsRemoval) async -> RemovalOutcome = { _ in .failed(.unknownStatus) }
    // Adapter-owned effects; pending UI never synthesizes approval or cancellation success.
    var openApprovalSettings: () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    var cancelOnboardingApproval: () -> Void = {}
    // Observed runtime authorization, never persisted as user preference or inferred from delivery.
    @Published var notificationAuthorization: NotificationAuthorization?
    var statusPanelPresented = false {
        didSet { if !statusPanelPresented { panelSetupPresentationID = nil } }
    }
    private var panelSetupPresentationID: UUID?
    private var menuSetupPresentationID: UUID?
    private var launched = false

    /// Reverify before removal and apply only verified absence to shared preferences/presentation.
    func removeVerifiedHelper(preferences: PreferencesStore) async -> RemovalOutcome {
        await settingsHelperSetup.refreshStatus()
        guard settingsHelperSetup.helperOn else { return .failed(.unknownStatus) }
        let result = await removeFromSettings(.helper)
        if case .verifiedAbsent = result {
            preferences.componentReadings = false
            preferences.displayMode = .delta
            settingsHelperSetup.resetAfterVerifiedRemoval()
        } else {
            // A failed removal is not proof that the helper is still connected.
            await settingsHelperSetup.refreshStatus()
        }
        return result
    }

    func launch(setupComplete: Bool) {
        guard !launched else { return }
        launched = true
        if !setupComplete { beginOnboarding() }
    }

    func reopen(setupComplete: Bool) {
        if setupComplete { showSettings() }
        else { beginOnboarding() }
    }

    func launch(preferences: PreferencesStore) {
        guard !launched else { return }
        launched = true
        let state = preferences.onboarding
        if CoachMarkView.canPresent(state) { showCoachMark() }
        else if state.completed { showSettings() }
        else if !state.completed && state.checkpoint != .runningDefaults { beginOnboarding() }
    }

    func reopen(preferences: PreferencesStore) {
        if !preferences.onboarding.completed,
           [.welcomeClosed, .runningDefaults].contains(preferences.onboarding.checkpoint) {
            resumeDeferredSetup(preferences: preferences)
        } else {
            reopen(setupComplete: preferences.onboarding.completed)
        }
    }

    @discardableResult
    func resumeDeferredSetup(preferences: PreferencesStore, expected: OnboardingState? = nil) -> Bool {
        let previous = expected ?? preferences.onboarding
        guard SetupPromptPresentation.canPresent(previous) else { return false }
        return resumeIncompleteSetup(preferences: preferences, expected: previous)
    }

    /// Shared persisted transition for the deferred prompt and the explicit menu action.
    private func resumeIncompleteSetup(preferences: PreferencesStore, expected previous: OnboardingState) -> Bool {
        guard !previous.completed, preferences.onboarding == previous else { return false }
        var next = previous
        next.checkpoint = .picker
        next.deferredSetupID = nil
        guard preferences.transitionOnboarding(from: previous, to: next) else { return false }
        statusPanelPresented = false
        beginOnboarding()
        return true
    }

    func beginMenuSetupPresentation() -> UUID {
        let id = UUID()
        menuSetupPresentationID = id
        return id
    }

    func endMenuSetupPresentation(_ id: UUID) {
        guard id == menuSetupPresentationID else { return }
        menuSetupPresentationID = nil
    }

    /// One attempt per menu, including failed writes. Reopening provides a fresh action.
    @discardableResult
    func finishSetupFromMenu(preferences: PreferencesStore, expected: OnboardingState,
                             presentationID: UUID) -> Bool {
        guard presentationID == menuSetupPresentationID else { return false }
        menuSetupPresentationID = nil
        return resumeIncompleteSetup(preferences: preferences, expected: expected)
    }

    /// A closed or replaced panel cannot resume setup using a retained button callback.
    func beginPanelSetupPresentation() -> UUID {
        let id = UUID()
        panelSetupPresentationID = id
        statusPanelPresented = true
        return id
    }

    func endPanelSetupPresentation(_ id: UUID?) {
        guard let id, id == panelSetupPresentationID else { return }
        statusPanelPresented = false
    }

    @discardableResult
    func continuePanelSetup(preferences: PreferencesStore, expected: OnboardingState,
                            presentationID: UUID?) -> Bool {
        guard statusPanelPresented, let presentationID,
              presentationID == panelSetupPresentationID else { return false }
        return resumeDeferredSetup(preferences: preferences, expected: expected)
    }

    func beginOnboarding() { menuSetupPresentationID = nil; present(.onboarding) }
    func showCoachMark() { menuSetupPresentationID = nil; present(.coachMark) }
    func showStatusPanel() { menuSetupPresentationID = nil; present(.statusPanel) }
    func showSettings() { menuSetupPresentationID = nil; present(.settings) }
    /// No production endpoint/trust composition is configured by default. Fail closed.
    var canCheckForUpdates: Bool {
        guard !upToDatePresented, updateService != nil, updateCheck == nil, downloadTask == nil, !cancellationPending else { return false }
        switch updates.state {
        case .idle, .completed, .failed(_, nil): return true
        default: return false // Do not overwrite an offer or an unreconciled transaction.
        }
    }

    /// Synchronous admission prevents two native actions from scheduling duplicate checks.
    /// A retained item from a closed/replaced menu is not a fresh user intent.
    @discardableResult
    func checkForUpdatesFromMenu(presentationID: UUID) -> Bool {
        guard presentationID == menuSetupPresentationID,
              canCheckForUpdates, let updateService else { return false }
        menuSetupPresentationID = nil
        guard updates.accept(.checking, generation: updates.generation) else { return false }
        let generation = updates.renewGeneration()
        updateOfferIntent = nil
        checkFailurePresentation = nil
        updateCheck = Task { [weak self] in
            let outcome = await updateService.check()
            guard let self else { return }
            defer { self.updateCheck = nil }
            guard !Task.isCancelled else { return }
            let next: UpdateState
            switch outcome {
            case .success(let version): next = version.map { .available(version: $0) } ?? .idle
            case .failure(let reason): next = .failed(reason, nil)
            }
            guard self.updates.accept(next, generation: generation) else { return }
            if case .success(nil) = outcome {
                self.upToDateGeneration = generation
            } else if case .failure(let reason) = outcome, reason != .cancelled {
                self.checkFailurePresentation = CheckFailurePresentation(id: UUID(), generation: generation, reason: reason)
            }
        }
        present(.softwareUpdate)
        return true
    }

    /// Invalidate before signalling cancellation, including non-cooperative services.
    @discardableResult
    func cancelUpdateCheck() -> Bool {
        guard updates.state == .checking else { return false }
        let saved = updates.cancel()
        updateCheck?.cancel()
        return saved
    }

    func showUpdate() { menuSetupPresentationID = nil; present(.update) }
}


/// J3.1: all alert chrome, icon, typography and button layout belong to macOS.
enum HelperNotApprovedAlert {
    static let title = "Helper not approved"
    static let message = "Watt? can’t read components without it. Delta, Charger and Draw still work. Turn it on any time in Settings."
    static let primary = "Open System Settings"
    static let secondary = "Skip for Now"
}

struct HelperNotApprovedPresentation: ViewModifier {
    @ObservedObject var router: AppRouter
    let preferences: PreferencesStore
    let origin: ApprovalOrigin

    func body(content: Content) -> some View {
        content.alert(HelperNotApprovedAlert.title, isPresented: Binding(
            get: { router.helperNotApprovedPresented && router.failureOrigin == origin },
            set: { if !$0 && router.failureOrigin == origin { router.helperNotApprovedPresented = false } }
        )) {
            Button(HelperNotApprovedAlert.primary) {
                router.openSettingsAfterApprovalFailure(preferences: preferences)
            }
            .keyboardShortcut(.defaultAction)
            Button(HelperNotApprovedAlert.secondary, role: .cancel) {
                router.skipUnapprovedHelper(preferences: preferences)
            }
        } message: {
            Text(HelperNotApprovedAlert.message)
        }
        .onDisappear {
            router.settingsHelperSetup.approvals.close(origin)
            if router.failureOrigin == origin { router.helperNotApprovedPresented = false }
        }
    }
}
