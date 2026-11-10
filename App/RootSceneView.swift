import SwiftUI

/// Separate app-update and helper-update content; macOS owns both scene chrome.
struct UpdateRootView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    var softwareUpdate = false
    var body: some View {
        if softwareUpdate {
            SoftwareUpdateContent(router: router, store: router.updates)
        } else {
            HelperUpdateSceneContent(prompt: router.helperUpdate)
                .onAppear {
                    router.helperUpdate.returnToPanel = { dismiss(); router.showStatusPanel() }
                    router.helperUpdate.presented = true
                }
        }
    }
}

private struct HelperUpdateSceneContent: View {
    @ObservedObject var prompt: HelperUpdatePrompt
    @Environment(\.scenePhase) private var phase
    var body: some View {
        VStack(spacing: WattSpacing.md) {
            Text(prompt.message)
            if case .success(.awaitingApproval) = prompt.outcome {
                Button("Check Approval") { Task { await prompt.update() } }
                    .disabled(prompt.busy)
            } else if case .failure = prompt.outcome {
                Button("Retry") { prompt.presented = true }.disabled(prompt.busy)
            }
        }
        .padding(WattSpacing.xl)
        .modifier(HelperUpdatePresentation(prompt: prompt))
        .onChange(of: phase) { value in
            if value == .active, case .success(.awaitingApproval) = prompt.outcome {
                Task { await prompt.update() }
            }
        }
    }
}


// Keep the checking → available transition inside the same native window.
struct SoftwareUpdateContent: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        content
            .background(UpToDatePresentation(router: router) { dismiss() })
            .background(CouldntCheckPresentation(router: router) { dismiss() })
            .onDisappear { router.closeUpdatePresentation() }
    }

    @ViewBuilder private var content: some View {
        if router.upToDatePresented || router.couldntCheckPresented {
            Color.clear
        } else if case .adminRequired = store.state {
            VStack(alignment: .leading, spacing: 16) {
                Text("The update is ready. Administrator installation is required to update Watt? and its helper together. Use the Watt? installer, then launch the installed app.")
                Button("Discard Download") { Task { if await router.cancelUpdateDownload() { dismiss() } } }
            }.padding(20).frame(width: 420)
        } else if case .handoffAccepted = store.state {
            Text("Watt? will close while the update finishes.").padding(20).frame(width: 420)
        } else if router.pendingProtectedReceipt != nil {
            VStack(alignment: .leading, spacing: 16) {
                Text("An update needs recovery. Resume to verify the installer result and relaunch Watt?.")
                Button("Resume Install and Relaunch") { Task { await router.resumeProtectedUpdate() } }
                    .disabled(router.resumingProtectedUpdate)
            }.padding(20).frame(width: 420)
        } else if let receipt = router.readyReceipt, let version = router.downloadVersion {
            UpdateReadyContent(router: router, store: store, version: version, receipt: receipt)
        } else if let version = router.downloadVersion {
            UpdateDownloadingContent(router: router, store: store, version: version)
        } else if case .available(let version) = store.state {
            UpdateAvailableContent(router: router, store: store, version: version)
        } else {
            UpdateCheckingContent(router: router, store: store)
        }
    }
}

struct UpdateAvailableContent: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    let version: String
    @Environment(\.dismiss) private var dismiss
    @State private var automaticUpdates: Bool

    init(router: AppRouter, store: UpdateStore, version: String) {
        self.router = router
        self.store = store
        self.version = version
        _automaticUpdates = State(initialValue: store.installFutureUpdatesAutomatically)
    }
    @State private var choiceFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Image("WattAppIcon").resizable().frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("A new version of Watt? is available")
                        .font(.body).fontWeight(.semibold)
                    Text("Watt? \(version) is available — you have \(router.currentAppVersion).")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("What’s New in \(version)").font(.headline)
            Form {
                if version == "1.1" {
                    releaseRow("Neural Engine", "Now in Components.")
                    releaseRow("Steadier numbers", "Less jumping when load spikes.")
                    releaseRow("New helper", "macOS asks you to approve it once.")
                } else {
                    Text("Release notes aren’t available for this version.")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            Toggle("Install future updates automatically", isOn: $automaticUpdates)
                .toggleStyle(.checkbox)
            HStack {
                Button("Skip This Version") { choose(.skip) }
                Spacer()
                Button("Remind Me Later") { choose(.remindLater) }
                    .keyboardShortcut(.cancelAction)
                Button("Install Update") { choose(.install) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.bordered)
            .disabled(router.updateOfferIntent != nil)
            if store.persistenceFailure != nil {
                Text("Couldn’t save your choice. Try again.").font(.caption)
            } else if choiceFailed {
                Text("Couldn’t apply your choice. Try again.").font(.caption)
            }
        }
        .padding(20)
        .frame(width: 520)
        .frame(minHeight: 334)
    }

    private func releaseRow(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func choose(_ action: UpdateOfferAction) {
        if action == .install {
            choiceFailed = !router.installOfferedUpdate(version: version, generation: store.generation,
                                                         automaticUpdates: automaticUpdates)
        } else {
            choiceFailed = !router.chooseUpdateOffer(action, version: version, generation: store.generation,
                                                     automaticUpdates: automaticUpdates)
            if !choiceFailed { dismiss() }
        }
    }
}

// J10.5: the OS owns progress, buttons, labels and window chrome.
struct UpdateReadyContent: View {
    static let title = "Ready to install"
    static let footnote = "Watt? quits, updates and comes back to the menu bar. About 5 seconds."
    static let progress = 1.0
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    let version: String
    let receipt: OperationReceipt
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: UUID?
    @State private var generation: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image("WattAppIcon").resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.title).font(WattTypography.headline)
                    ProgressView(value: Self.progress).progressViewStyle(.linear)
                        .accessibilityLabel("Download complete")
                    Text(Self.footnote).font(WattTypography.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Later") { choose(.later) }
                    .buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button("Install and Relaunch") { choose(.installAndRelaunch) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }.font(WattTypography.bodyEmphasized).disabled(router.readyIntent != nil)
            if store.persistenceFailure != nil {
                Text("Couldn’t save your choice. Try again.").font(WattTypography.footnote)
                    .foregroundStyle(.secondary)
            }
        }.padding(20).frame(width: 420).frame(minHeight: 146)
        .onAppear {
            generation = store.generation
            presentation = router.beginReadyPresentation()
        }
        .onDisappear { router.closeReadyPresentation(presentation) }
    }

    private func choose(_ action: AppRouter.ReadyIntent.Action) {
        guard let presentation, let generation else { return }
        if router.chooseReadyUpdate(action, version: version, generation: generation,
                                    receipt: receipt, presentation: presentation) { dismiss() }
    }
}

// Native controls and chrome follow the system, including across OS versions.
struct UpdateDownloadingContent: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    let version: String
    @Environment(\.dismiss) private var dismiss
    @State private var cancelling = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image("WattAppIcon").resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Downloading Watt? \(version)…").font(WattTypography.bodyEmphasized)
                    ProgressView(value: progress).progressViewStyle(.linear)
                        .accessibilityLabel("Download progress")
                    Text(router.downloadProgress?.label ?? "Preparing download…")
                        .font(WattTypography.footnote).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    cancelling = true
                    Task {
                        if await router.cancelUpdateDownload() { dismiss() }
                        cancelling = false
                    }
                }.buttonStyle(.bordered).keyboardShortcut(.cancelAction).disabled(cancelling)
            }
            if store.persistenceFailure != nil {
                Text("Couldn’t save download state. Try Cancel again.").font(.caption)
            } else if case .failed = store.state {
                Text("Download stopped. Cancel to clean up before retrying.").font(.caption)
            }
        }.padding(20).frame(width: 420).frame(minHeight: 146)
        .onDisappear {
            if case .downloading = store.state { Task { _ = await router.cancelUpdateDownload() } }
        }
    }
    private var progress: Double {
        if case .downloading(let value) = store.state { return value }
        if case .staged = store.state { return 1 }
        return router.downloadProgress?.fraction ?? 0
    }
}

// J10.2: macOS owns window chrome, progress animation and button appearance.
struct UpdateCheckingContent: View {
    let router: AppRouter
    @ObservedObject var store: UpdateStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image("WattAppIcon")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Checking for updates…")
                        .font(WattTypography.bodyEmphasized)
                    ProgressView()
                        .progressViewStyle(.linear)
                        .accessibilityLabel("Checking for updates…")
                }
                .frame(maxWidth: .infinity)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    if router.cancelUpdateCheck() { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
            }
            if store.persistenceFailure != nil {
                Text("Couldn’t save cancellation. Try Cancel again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
        .frame(minHeight: 146)
        .onChange(of: store.state) { state in
            // Keep native result alerts in this scene.
            if state != .checking && !router.upToDatePresented && !router.couldntCheckPresented {
                if case .available = state { return }
                dismiss()
            }
        }
        .onDisappear { _ = router.cancelUpdateCheck() }
    }
}

/// AppKit owns the app icon, typography, default button, material and standalone chrome.
/// SwiftUI's sheet-style alert omits the app icon on some supported macOS versions.
private struct UpToDatePresentation: NSViewRepresentable {
    @ObservedObject var router: AppRouter
    let dismiss: () -> Void

    final class Coordinator {
        var scheduled = false
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        guard router.upToDatePresented, !context.coordinator.scheduled else { return }
        context.coordinator.scheduled = true
        let generation = router.upToDateGeneration
        DispatchQueue.main.async {
            defer { context.coordinator.scheduled = false }
            guard router.upToDatePresented, router.upToDateGeneration == generation,
                  let window = view.window, window.isVisible else { return }
            let alert = UpToDateAlert.make(message: router.upToDateMessage)
            window.orderOut(nil)
            _ = alert.runModal()
            router.dismissUpToDate()
            dismiss()
        }
    }
}

enum UpToDateAlert {
    @MainActor static func make(message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primary)
        return alert
    }
    static func message(version: String) -> String { "\(version) is the latest." }
    static let title = "You’re up to date"
    static let primary = "OK"
}

/// No custom icon, material, appearance or geometry: this is the macOS alert component.
enum CouldntCheckAlert {
    static let title = "Couldn’t check for updates"
    static let message = "No connection right now. Watt? checks again later on its own."
    @MainActor static func make() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "OK")
        return alert
    }
}

private struct CouldntCheckPresentation: NSViewRepresentable {
    @ObservedObject var router: AppRouter
    let dismiss: () -> Void
    final class Coordinator { var scheduled = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        guard router.couldntCheckPresented, let token = router.checkFailurePresentation,
              !context.coordinator.scheduled else { return }
        context.coordinator.scheduled = true
        DispatchQueue.main.async {
            defer { context.coordinator.scheduled = false }
            guard router.couldntCheckPresented, router.checkFailurePresentation == token,
                  let window = view.window, window.isVisible else { return }
            window.orderOut(nil)
            let response = CouldntCheckAlert.make().runModal()
            guard router.couldntCheckPresented, router.checkFailurePresentation == token else { return }
            if response == .alertFirstButtonReturn {
                // Restore the host even on a failed persistence write, so retry remains possible.
                window.makeKeyAndOrderFront(nil)
                if !router.retryCouldntCheck(token) {
                    DispatchQueue.main.async { updateNSView(view, context: context) }
                }
            } else if router.dismissCouldntCheck(token) {
                dismiss()
            }
        }
    }
}

#if DEBUG
@MainActor
enum J107FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.7/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let service = FakeUpdateService()
        service.availableVersion = .failure(.network)
        let router = AppRouter(updateService: service)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        return window
    }
}

@MainActor
enum J106FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.6/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let service = FakeUpdateService()
        service.availableVersion = .success(nil)
        let router = AppRouter(updateService: service)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        return window
    }
}

@MainActor
enum J102FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.2/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let router = AppRouter(updateService: CheckingFixtureService())
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 146),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
enum J103FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.3/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let service = FakeUpdateService()
        service.availableVersion = .success("1.1")
        let router = AppRouter(updateService: service)
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 334),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
enum J104FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.4/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let store = UpdateStore()
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let router = AppRouter(updateService: DownloadingFixtureService(), updates: store)
        router.startUpdateDownload(version: "1.1", generation: store.generation)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 146),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
enum J105FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.5/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let store = UpdateStore()
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        router.startUpdateDownload(version: "1.1", generation: store.generation)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 146),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
private final class DownloadingFixtureService: CheckingFixtureService {
    override func download(version: String, receipt: OperationReceipt,
                           progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        progress(UpdateDownloadProgress(received: 2_100_000, total: 4_200_000))
        _ = await check()
        return .failure(.cancelled)
    }
    override func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .success(.failed(.cancelled, receipt)) }
    override func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .success(receipt) }
}

/// Suspends without a fabricated update result; no endpoint, disk or installation effects.
@MainActor
private class CheckingFixtureService: UpdateService {
    func check() async -> ServiceOutcome<String?> {
        do {
            while true { try await Task.sleep(nanoseconds: 60_000_000_000) }
        } catch { return .failure(.cancelled) }
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func download(version: String, receipt: OperationReceipt,
                  progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        await download(version: version, receipt: receipt)
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}
#endif
