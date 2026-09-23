import AppKit
import SwiftUI

struct OnboardingFlowView: View {
    var welcomeVariant: WelcomeView.Variant = .standard
    var closeAction: (() -> Void)? = nil
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if preferences.onboarding.checkpoint == .welcome {
                WelcomeView(variant: welcomeVariant) {
                    Self.continueWelcome(preferences: preferences)
                }
            } else if preferences.onboarding.checkpoint == .picker {
                ChooseMenuReadingView()
            } else if preferences.onboarding.checkpoint == .helperOffer {
                OfferComponentReadingsView()
            } else if preferences.onboarding.checkpoint == .approval {
                WaitingForApprovalView()
            } else if preferences.onboarding.checkpoint == .preview {
                ComponentPreviewView()
            } else if preferences.onboarding.checkpoint == .allSet {
                AllSetView()
            } else {
                routeShell
            }
        }
        .background {
            OnboardingCloseObserver {
                Self.closeWelcome(preferences: preferences, router: router)
            }
        }
        .onExitCommand { close() }
    }

    static func continueWelcome(preferences: PreferencesStore) {
        let previous = preferences.onboarding
        guard !previous.completed, previous.checkpoint == .welcome else { return }
        var next = previous
        next.checkpoint = .picker
        preferences.transitionOnboarding(from: previous, to: next)
    }

    @discardableResult
    static func closeWelcome(preferences: PreferencesStore, router: AppRouter) -> Bool {
        let previous = preferences.onboarding
        guard !previous.completed, previous.checkpoint == .welcome else { return false }
        var next = previous
        next.checkpoint = .welcomeClosed
        next.deferredSetupID = UUID()
        guard preferences.transitionOnboarding(from: previous, to: next, displayMode: .delta) else { return false }
        router.showCoachMark()
        return true
    }

    private var routeShell: some View {
        WattWindowScaffold(title: "Onboarding shell") {
            VStack(alignment: .leading, spacing: WattSpacing.md) {
                Text("The Figma onboarding frames are intentionally tracked as separate stories in SCREEN-BACKLOG.md.")
                    .font(WattTypography.body)
                LabeledContent("Current route", value: preferences.onboarding.checkpoint.label)
                Text("This phase establishes the scene and typed route only; helper approval and screen transitions are not simulated.")
                    .font(WattTypography.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    WattActionButton(title: "Close", action: close)
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(WattSpacing.xl)
        }
        .frame(width: WattSpacing.onboardingWidth)
    }

    private func close() {
        if !preferences.onboarding.completed, preferences.onboarding.checkpoint == .welcome {
            guard Self.closeWelcome(preferences: preferences, router: router) else { return }
        }
        if let closeAction { closeAction() } else { dismiss() }
    }
}

/// Observe only this window's native close. SwiftUI retains ownership of its window delegate.
struct OnboardingCloseObserver: NSViewRepresentable {
    let onClose: () -> Void
    func makeNSView(context: Context) -> OnboardingCloseView {
        let view = OnboardingCloseView()
        view.onClose = onClose
        return view
    }
    func updateNSView(_ view: OnboardingCloseView, context: Context) { view.onClose = onClose }
}

final class OnboardingCloseView: NSView {
    var onClose: (() -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose),
                name: NSWindow.willCloseNotification, object: window)
        }
    }
    @objc private func windowWillClose(_ notification: Notification) { onClose?() }
}

private extension OnboardingCheckpoint {
    var label: String {
        switch self {
        case .welcome: return "welcome"
        case .picker: return "menu-bar reading"
        case .helperOffer: return "component readings"
        case .approval: return "helper approval"
        case .preview: return "component preview"
        case .allSet: return "all set"
        case .coachMark: return "coach mark"
        case .livePanel: return "live panel"
        case .welcomeClosed: return "setup deferred"
        case .runningDefaults: return "running with defaults"
        }
    }
}

/// J1.1: system typography, app-icon placeholder and native default action.
struct WelcomeView: View {
    enum Variant: CaseIterable {
        case standard, desktop
        @MainActor var message: String {
            switch self {
            case .standard: return WelcomeView.message
            case .desktop: return "Watt? sits in your menu bar and shows what your Mac draws. Nothing more."
            }
        }
    }
    var variant: Variant = .standard
    let continueAction: () -> Void
    static let desktopIconAsset = "WattAppIcon"
    static let title = "Know your watts"
    static let message = "Watt? sits in your menu bar and shows what your Mac draws and what it’s charging with. Nothing more."

    var body: some View {
        VStack(spacing: WattSpacing.lg) {
            welcomeIcon
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(Self.title)
                .font(WattTypography.welcomeTitle)
                .accessibilityAddTraits(.isHeader)
            Text(variant.message)
                .font(WattTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Continue", action: continueAction)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("onboarding.welcome.continue")
            }
        }
        .padding(.horizontal, WattSpacing.lg * 2)
        .padding(.vertical, WattSpacing.md * 2)
        .frame(width: WattSpacing.onboardingWidth)
    }

    private var welcomeIcon: Image {
        switch variant {
        case .standard:
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSApplication.shared.applicationIconImage)
        case .desktop:
            Image(Self.desktopIconAsset)
        }
    }
}

/// J1.2 uses the same native radio picker as the shared component specimens.
struct ChooseMenuReadingView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var powerStore: PowerReadingStore

    static let title = "Pick one number for the menu bar"
    static let message = "Change it any time. Right-click Watt? or open Settings."

    enum Variant: Equatable {
        case standard, noBattery

        init(reading: PowerReading) {
            self = reading.batteryState == .noBattery && reading.capabilities.battery == .unsupported
                ? .noBattery : .standard
        }

        var message: String {
            self == .noBattery ? "No battery here, so it’s Draw or Components." : ChooseMenuReadingView.message
        }
    }

    static func unavailableModes(reading: PowerReading) -> Set<WattDisplayMode> {
        guard Variant(reading: reading) == .noBattery else { return [] }
        var modes: Set<WattDisplayMode> = [.delta, .charger]
        if reading.capabilities.components != .available { modes.insert(.components) }
        return modes
    }

    static func prepareSelection(preferences: PreferencesStore, reading: PowerReading) {
        guard preferences.onboarding.checkpoint == .picker,
              Variant(reading: reading) == .noBattery,
              preferences.displayMode == .iconOnly || unavailableModes(reading: reading).contains(preferences.displayMode)
        else { return }
        preferences.displayMode = .draw
    }

    static func options(reading: PowerReading) -> [ReadingPicker.Option] {
        if Variant(reading: reading) == .noBattery {
            return [
                .init(mode: .draw, description: "What your Mac uses right now. " +
                      PowerFormatter.watts(reading.value(for: .draw), signed: false)),
                .init(mode: .components, description: "CPU, GPU and the rest. Needs the helper — next step."),
                .init(mode: .delta, description: "Needs a battery. This Mac doesn’t have one."),
                .init(mode: .charger, description: "Needs a battery. This Mac doesn’t have one.")
            ]
        }
        return [
            .init(mode: .delta, description: "How fast the battery fills or drains. " +
                  PowerFormatter.watts(reading.value(for: .delta))),
            .init(mode: .charger, description: "What the charger is giving. " +
                  PowerFormatter.watts(reading.capabilities.charger == .available ? reading.chargerWatts : nil,
                                       signed: false, precision: .whole)),
            .init(mode: .draw, description: "What your Mac uses right now. " +
                  PowerFormatter.watts(reading.value(for: .draw), signed: false)),
            .init(mode: .components, description: "CPU, GPU and the rest. Needs the helper — next step.")
        ]
    }

    static func back(preferences: PreferencesStore) {
        guard preferences.onboarding.checkpoint == .picker else { return }
        preferences.onboarding.checkpoint = .welcome
    }

    static func advance(preferences: PreferencesStore) {
        guard preferences.onboarding.checkpoint == .picker else { return }
        preferences.onboarding.checkpoint = .helperOffer
    }

    var body: some View {
        VStack(spacing: WattSpacing.md) {
            Text(Self.title)
                .font(WattTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(Variant(reading: powerStore.currentReading).message)
                .font(WattTypography.body)
                .foregroundStyle(.secondary)
            ReadingPicker(selection: $preferences.displayMode,
                          unavailableModes: Self.unavailableModes(reading: powerStore.currentReading),
                          options: Self.options(reading: powerStore.currentReading))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("onboarding.reading.picker")
            HStack {
                Spacer()
                WattActionButton(title: "Back") { Self.back(preferences: preferences) }
                    .accessibilityIdentifier("onboarding.reading.back")
                WattActionButton(title: "Continue", style: .prominent) {
                    Self.advance(preferences: preferences)
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("onboarding.reading.continue")
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(width: WattSpacing.onboardingWidth)
        .onAppear { Self.prepareSelection(preferences: preferences, reading: powerStore.currentReading) }
        .onChange(of: powerStore.currentReading) { reading in
            Self.prepareSelection(preferences: preferences, reading: reading)
        }
    }
}

/// J1.3: informational facts use native form layout, never painted settings rows.
struct OfferComponentReadingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    static let title = "See where the power goes"
    static let message = "Watt? needs a small helper to read CPU, GPU and display power. macOS asks you to approve it once."

    static let facts = [
        (label: "What it reads", value: "Power sensors only"),
        (label: "Network", value: "Never"),
        (label: "Remove it", value: "Any time, in Settings")
    ]
    enum Action: CaseIterable { case notNow, turnOn }

    static func perform(_ action: Action, preferences: PreferencesStore) {
        guard preferences.onboarding.checkpoint == .helperOffer else { return }
        var state = preferences.onboarding
        switch action {
        case .notNow:
            state.helperOptIn = false
            state.checkpoint = .allSet
        case .turnOn:
            // Intent only. Approval/connection must be established by the helper service.
            state.helperOptIn = true
            state.checkpoint = .approval
        }
        preferences.onboarding = state
    }

    var body: some View {
        VStack(spacing: WattSpacing.md) {
            Image("WattAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(Self.title)
                .font(WattTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(Self.message)
                .font(WattTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                ForEach(Self.facts, id: \.label) { fact in
                    LabeledContent(fact.label, value: fact.value)
                }
            }
            .formStyle(.grouped)
            .accessibilityIdentifier("onboarding.helper.facts")
            HStack {
                Spacer()
                Button { Self.perform(.notNow, preferences: preferences) } label: {
                    Text("Not Now")
                }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.helper.notNow")
                Button { Self.perform(.turnOn, preferences: preferences) } label: {
                    Text("Turn On…")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("onboarding.helper.turnOn")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(width: WattSpacing.onboardingWidth)
    }
}

/// J1.4 owns only the pending presentation; macOS owns approval and notifications.
struct WaitingForApprovalView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var router: AppRouter

    static let title = "One switch in System Settings"
    static let message = "Turn on “Watt? Helper” in Login Items & Extensions. This window moves on by itself."

    static func openSettings(preferences: PreferencesStore, router: AppRouter) {
        guard preferences.onboarding.checkpoint == .approval else { return }
        router.openApprovalSettings()
    }

    static func cancel(preferences: PreferencesStore, router: AppRouter) {
        guard preferences.onboarding.checkpoint == .approval else { return }
        router.cancelOnboardingApproval()
        router.approvalNotGiven(.cancelled, preferences: preferences)
    }

    var body: some View {
        VStack(spacing: WattSpacing.lg) {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(Self.title)
                .accessibilityIdentifier("onboarding.approval.progress")
            Text(Self.title)
                .font(WattTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(Self.message)
                .font(WattTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { Self.cancel(preferences: preferences, router: router) }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("onboarding.approval.cancel")
                Button("Open System Settings") { Self.openSettings(preferences: preferences, router: router) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("onboarding.approval.openSettings")
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 24)
        // The native titlebar supplies the remaining 32 points of the 224-point window.
        .frame(width: WattSpacing.onboardingWidth, height: 192)
        .task {
            // Scene-owned deadline: closing cancels it; timeout is local withdrawal, not OS denial.
            do { try await Task.sleep(nanoseconds: 120_000_000_000) } catch { return }
            guard !Task.isCancelled,
                  router.settingsHelperSetup.approvals.checkpoint.origins[.onboarding]?.interested == true else { return }
            router.approvalNotGiven(.timedOut, preferences: preferences)
        }
        .modifier(HelperNotApprovedPresentation(router: router, preferences: preferences, origin: .onboarding))
    }
}

/// J1.6 completes setup; the next coach-mark story owns its separate presentation.
struct AllSetView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    static let title = "That’s it"
    static let message = "Watt? lives in your menu bar. Click it for the detail. Right-click to change the number."

    static func finish(preferences: PreferencesStore, router: AppRouter, dismiss: () -> Void) {
        guard preferences.onboarding.checkpoint == .allSet, !preferences.onboarding.completed else { return }
        let previous = preferences.onboarding
        var state = previous
        state.completed = true
        state.checkpoint = .coachMark
        preferences.onboarding = state
        guard preferences.persistenceFailure == nil else {
            preferences.onboarding = previous
            return
        }
        dismiss()
        router.showCoachMark()
    }

    var body: some View {
        VStack(spacing: WattSpacing.md) {
            Image("WattAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(Self.title)
                .font(WattTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(Self.message)
                .font(WattTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Section {
                    Toggle("Open at login", isOn: $preferences.openAtLogin)
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("onboarding.allSet.openAtLogin")
                }
            }
            .formStyle(.columns)
            HStack {
                if preferences.persistenceFailure != nil {
                    Text("Couldn’t save your preferences. Try again.")
                        .font(WattTypography.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    Self.finish(preferences: preferences, router: router) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("onboarding.allSet.done")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(width: WattSpacing.onboardingWidth)
    }
}

/// J1.5 presents service-supplied readings; navigation never establishes helper approval.
struct ComponentPreviewView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var powerStore: PowerReadingStore

    static let title = "Helper’s on"
    static let message = "Here’s where the power is going right now."

    static let componentNames = ["CPU", "GPU", "Display"]

    static func value(for name: String, reading: PowerReading) -> String {
        guard reading.capabilities.components == .available,
              reading.freshness == .fresh, reading.source != .unavailable else {
            return PowerFormatter.watts(nil, signed: false)
        }
        return PowerFormatter.watts(reading.components.first { $0.name == name }?.watts, signed: false)
    }

    static func advance(preferences: PreferencesStore) {
        guard preferences.onboarding.checkpoint == .preview else { return }
        preferences.onboarding.checkpoint = .allSet
    }

    var body: some View {
        VStack(spacing: WattSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(Self.title)
                .font(WattTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(Self.message)
                .font(WattTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Section {
                    ForEach(Self.componentNames, id: \.self) { name in
                        LabeledContent(name, value: Self.value(for: name, reading: powerStore.currentReading))
                            .accessibilityIdentifier("onboarding.preview." + name.lowercased())
                    }
                }
            }
            .formStyle(.columns)
            .accessibilityIdentifier("onboarding.preview.readings")
            HStack {
                Spacer()
                Button("Continue") { Self.advance(preferences: preferences) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("onboarding.preview.continue")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(width: WattSpacing.onboardingWidth)
    }
}

/// J1.7 / J5.1 content only. NSPopover supplies native chrome and arrow geometry.
struct CoachMarkView: View {
    @ObservedObject var preferences: PreferencesStore
    let router: AppRouter
    let variant: Variant
    private let presentationID: UUID?
    static let title = "Watt? lives here"
    static let message = "Click for the detail. Right-click to change the number."

    @MainActor enum Variant {
        case standard, welcomeClosed
        var title: String { self == .standard ? CoachMarkView.title : "Watt? is on, showing Delta." }
        var message: String {
            self == .standard ? CoachMarkView.message : "Setup can wait. Two steps, whenever you’re ready."
        }
        var size: NSSize {
            self == .standard
                ? NSSize(width: WattSpacing.coachMarkWidth, height: WattSpacing.coachMarkHeight)
                : NSSize(width: WattSpacing.deferredCoachMarkWidth, height: WattSpacing.deferredCoachMarkHeight)
        }
    }

    init(preferences: PreferencesStore, router: AppRouter) {
        self.preferences = preferences
        self.router = router
        variant = preferences.onboarding.checkpoint == .welcomeClosed ? .welcomeClosed : .standard
        presentationID = preferences.onboarding.deferredSetupID
    }

    static func canPresent(_ state: OnboardingState) -> Bool {
        (state.completed && state.checkpoint == .coachMark)
            || (!state.completed && state.checkpoint == .welcomeClosed && state.deferredSetupID != nil)
    }

    static func notNow(preferences: PreferencesStore, router: AppRouter, presentationID: UUID) {
        respondToDeferredSetup(preferences: preferences, router: router, presentationID: presentationID,
                               finish: false)
    }

    static func finishSetup(preferences: PreferencesStore, router: AppRouter, presentationID: UUID) {
        respondToDeferredSetup(preferences: preferences, router: router, presentationID: presentationID,
                               finish: true)
    }

    private static func respondToDeferredSetup(preferences: PreferencesStore, router: AppRouter,
                                               presentationID: UUID, finish: Bool) {
        let previous = preferences.onboarding
        guard !previous.completed, previous.checkpoint == .welcomeClosed,
              previous.deferredSetupID == presentationID else { return }
        var next = previous
        next.checkpoint = finish ? .picker : .runningDefaults
        next.deferredSetupID = nil
        guard preferences.transitionOnboarding(from: previous, to: next) else { return }
        if finish { router.beginOnboarding() } else { router.showStatusPanel() }
    }

    static func acknowledge(preferences: PreferencesStore, router: AppRouter) {
        guard preferences.onboarding.completed, preferences.onboarding.checkpoint == .coachMark else { return }
        let previous = preferences.onboarding
        preferences.onboarding.checkpoint = .livePanel
        guard preferences.persistenceFailure == nil else {
            preferences.onboarding = previous
            return
        }
        router.showStatusPanel()
    }

    static func makePopover(preferences: PreferencesStore, router: AppRouter) -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        let content = CoachMarkView(preferences: preferences, router: router)
        // J5.1 explicitly requests the light native surface, including on a dark desktop.
        if content.variant == .welcomeClosed { popover.appearance = NSAppearance(named: .aqua) }
        popover.contentViewController = NSHostingController(rootView: content)
        popover.contentSize = content.variant.size
        return popover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WattSpacing.xs) {
            Text(variant.title).font(WattTypography.headline).accessibilityAddTraits(.isHeader)
            Text(variant.message).font(WattTypography.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if preferences.persistenceFailure != nil {
                Text("Couldn’t save. Try again.").font(WattTypography.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                if variant == .welcomeClosed {
                    Button("Not Now") {
                        if let presentationID {
                            Self.notNow(preferences: preferences, router: router, presentationID: presentationID)
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("onboarding.deferred.notNow")
                    Button("Finish Setup") {
                        if let presentationID {
                            Self.finishSetup(preferences: preferences, router: router, presentationID: presentationID)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("onboarding.deferred.finishSetup")
                } else {
                    Button("Got It") { Self.acknowledge(preferences: preferences, router: router) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(.top, WattSpacing.sm)
        }
        .padding(WattSpacing.xl)
        .frame(width: variant.size.width)
        .frame(minHeight: variant.size.height)
    }
}
