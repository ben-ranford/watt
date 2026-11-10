import SwiftUI
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// J3.3: injected boundaries retain responsibility for signed receipts and OS approval.
@MainActor
final class HelperUpdatePrompt: ObservableObject {
    @Published var presented = false {
        didSet { if presented && !oldValue { presentationID = UUID() } }
    }
    private(set) var presentationID = UUID()
    @Published private(set) var busy = false
    @Published private(set) var outcome: ServiceOutcome<HelperState>?
    var verifyRelaunch: () async -> Bool = { false }
    var updateHelper: (OperationReceipt) async -> ServiceOutcome<HelperState> = { _ in .failure(.unknownStatus) }
    private var generation = UUID()
    private var receipt: OperationReceipt?

    func configure(updater: UpdateAdapter, appReceipt: OperationReceipt, helper: HelperLifecycleAdapter) {
        close()
        receipt = nil
        outcome = nil
        verifyRelaunch = {
            guard case .success(.completed(let verified)) = await updater.recover(receipt: appReceipt)
            else { return false }
            return verified == appReceipt
        }
        updateHelper = { await helper.update(receipt: $0) }
    }

    var returnToPanel: () -> Void = {}

    var message: String {
        if busy { return "Verifying helper update…" }
        switch outcome {
        case .success(.awaitingApproval): return "Waiting for macOS approval. Check again after approving in System Settings."
        case .success(.connected): return "Helper update verified."
        case .failure(.incompatibleVersion): return "This helper protocol cannot be updated by this app. An authenticated migration is required."
        case .failure(.adminRequired): return "Administrator installation is required to update the helper."
        case .failure: return "The helper update could not be verified. Try again."
        default: return "Update the helper after the app update."
        }
    }

    func later() { close(); returnToPanel() } // No preference, helper, receipt or OS mutation.
    func close() { generation = UUID(); presentationID = UUID(); busy = false; presented = false }

    func later(presentation: UUID) {
        guard presented, presentationID == presentation else { return }
        later()
    }

    func update(presentation: UUID) async {
        guard presented, presentationID == presentation else { return }
        await update()
    }

    func update() async {
        guard !busy else { return }
        busy = true
        let token = generation
        defer { if token == generation { busy = false } }
        presented = false
        guard await verifyRelaunch() else {
            guard token == generation, !Task.isCancelled else { return }
            outcome = .failure(.interruptedUpdate)
            return
        }
        guard token == generation, !Task.isCancelled else { return }
        // Keep the receipt across retries: ambiguous replies cannot replay installation.
        let operation = receipt ?? OperationReceipt(createdAt: Date())
        receipt = operation
        let result = await updateHelper(operation)
        guard token == generation, !Task.isCancelled else { return }
        switch result {
        case .success(.connected), .success(.awaitingApproval): outcome = result
        case .success: outcome = .failure(.unknownStatus)
        case .failure: outcome = result
        }
        // Never enable readings or synthesize an approval/notification from a button action.
    }
}

enum HelperChangedAlert {
    static let title = "The helper changed"
    static let message = "Watt? 1.1 comes with a new helper. macOS asks you to approve it once more."
    static let primary = "Update Helper"
    static let secondary = "Later"

    @MainActor
    static func make() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primary).keyEquivalent = "\r"
        alert.addButton(withTitle: secondary).keyEquivalent = "\u{1b}"
        return alert
    }
}

struct HelperUpdatePresentation: ViewModifier {
    @ObservedObject var prompt: HelperUpdatePrompt
    func body(content: Content) -> some View {
        content.background(HelperUpdateAlertBridge(prompt: prompt))
            .onDisappear { prompt.close() }
    }
}

private struct HelperUpdateAlertBridge: NSViewRepresentable {
    @ObservedObject var prompt: HelperUpdatePrompt
    final class Coordinator {
        var scheduled = false
        var alert: NSAlert?
        var token: UUID?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        if let alert = coordinator.alert,
           !prompt.presented || coordinator.token != prompt.presentationID {
            NSApp.abortModal()
            alert.window.orderOut(nil)
        }
        guard prompt.presented, !coordinator.scheduled else { return }
        let token = prompt.presentationID
        coordinator.scheduled = true
        DispatchQueue.main.async {
            defer { coordinator.scheduled = false; coordinator.alert = nil }
            guard prompt.presented, prompt.presentationID == token,
                  let window = view.window, window.isVisible else { return }
            window.orderOut(nil)
            let alert = HelperChangedAlert.make()
            coordinator.alert = alert
            coordinator.token = token
            let response = alert.runModal()
            guard prompt.presented, prompt.presentationID == token else { return }
            if response == .alertFirstButtonReturn {
                window.makeKeyAndOrderFront(nil)
                Task { await prompt.update(presentation: token) }
            } else {
                prompt.later(presentation: token)
            }
        }
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let alert = coordinator.alert { NSApp.abortModal(); alert.window.orderOut(nil) }
    }
}

#if DEBUG
@MainActor
enum J108FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.8/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let router = AppRouter()
        // Isolated fixture: no registration, approval settings, or installation effects.
        router.helperUpdate.verifyRelaunch = { true }
        router.helperUpdate.updateHelper = { _ in .success(.awaitingApproval) }
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Watt? Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView().environmentObject(router))
        window.center()
        return window
    }
}
#endif


/// Explicit, one-shot source evidence export through the authenticated helper.
/// The destination is opened by the unprivileged app; it is never sent to the daemon.
@MainActor
enum HelperDiagnosticExport {
    static func capture(connect: () async throws -> Void,
                        request: (HelperRequest) async throws -> HelperReply) async throws -> Data {
        try await connect()
        let command = HelperRequest(command: .diagnosticCapture, generation: UUID())
        let reply = try await request(command)
        // Enforce correlation and bounds even for injected transports.
        let data = try HelperWire.encode(reply)
        let checked = try HelperWire.decodeReply(data, for: command)
        guard checked.capture != nil else { throw ServiceFailure.invalidData }
        return data
    }

    static func present(transport: ProductionHelperIPC) async {
        let panel = NSSavePanel()
        panel.title = "Export Helper Diagnostic"
        panel.message = "Save one raw CPU/GPU source sample for diagnosis. This does not enable component estimates."
        panel.nameFieldStringValue = "watt-helper-diagnostic.json"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let data = try await capture(connect: { _ = try await transport.connect() },
                                         request: { try await transport.request($0) })
            try data.write(to: destination, options: .atomic)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Helper diagnostic could not be saved"
            alert.informativeText = "Check that the helper is approved and connected, then try again."
            alert.runModal()
        }
    }
}
