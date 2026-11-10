import AppKit
import Combine

/// Consent and durable retry state only. P05/P02 own inventory, identity and effects.
@MainActor
final class LeftoverHelperPrompt: ObservableObject {
    enum Action: String, Codable { case reconnect, remove }
    struct Intent: Equatable { let generation: UUID; let presentation: UUID }
    private struct Checkpoint: Codable {
        var receipt: OperationReceipt?
        var completed: Action?
        var delivered: Bool?
    }
    @Published private(set) var intent: Intent?
    @Published private(set) var busy = false
    @Published private(set) var failure: ServiceFailure?
    private var generation = UUID()
    private var activeIntent: Intent?
    private var checkpoint = Checkpoint()
    private let storage: any PreferenceStorage
    private let key: String
    var detect: () async throws -> Bool = { false }
    var reconnect: () async -> HelperReconciliation = { .unknown }
    var remove: (OperationReceipt) async -> RemovalOutcome = { _ in .failed(.unknownStatus) }
    var onCompleted: (Action) throws -> Void = { _ in }

    init(storage: any PreferenceStorage, installationID: UUID) {
        self.storage = storage
        key = "leftover-helper-" + installationID.uuidString
    }

    func configure(adapter: ScopedRemovalAdapter, installationID: UUID) {
        close()
        detect = { try await adapter.hasLeftoverHelper(currentInstallationID: installationID) }
        reconnect = { await adapter.reconnect() }
        remove = { await adapter.removeHelper(receipt: $0) }
    }

    func discover() async {
        guard !busy, intent == nil else { return }
        busy = true
        let token = generation
        defer { busy = false }
        do {
            checkpoint = try storage.read(key: key).map { try JSONDecoder().decode(Checkpoint.self, from: $0) } ?? Checkpoint()
            guard checkpoint.completed == nil || checkpoint.delivered == false else { return }
            let found = try await detect()
            guard token == generation, !Task.isCancelled, found else { return }
            failure = nil
            intent = Intent(generation: token, presentation: UUID())
        } catch { if token == generation { failure = (error as? ServiceFailure) ?? .persistence } }
    }

    func close() { generation = UUID(); intent = nil }

    func close(_ expected: Intent) {
        guard intent == expected || activeIntent == expected else { return }
        close()
    }

    private func persist() throws {
        try storage.write(JSONEncoder().encode(checkpoint), key: key)
    }

    func perform(_ action: Action, intent expected: Intent) async {
        guard intent == expected, expected.generation == generation, !busy else { return }
        activeIntent = expected
        intent = nil // Consume consent before suspension; double-clicks cannot replay.
        busy = true
        defer { busy = false; activeIntent = nil }
        do {
            if checkpoint.completed == nil {
                checkpoint.receipt = checkpoint.receipt ?? OperationReceipt(createdAt: Date())
                try persist() // Reconnect also requires a durable operation receipt.
                if action == .remove {
                    checkpoint.receipt = checkpoint.receipt ?? OperationReceipt(createdAt: Date())
                    try persist() // No removal unless receipt is durable.
                    let result = await remove(checkpoint.receipt!)
                    guard expected.generation == generation, !Task.isCancelled else { return }
                    guard result == .verifiedAbsent else {
                        if case .failed(let reason) = result { throw reason }
                        throw ServiceFailure.interruptedRemoval
                    }
                } else {
                    let result = await reconnect()
                    guard expected.generation == generation, !Task.isCancelled else { return }
                    guard case .connected = result else {
                        if case .failed(let reason) = result { throw reason }
                        throw ServiceFailure.unknownStatus
                    }
                }
                checkpoint.completed = action
                checkpoint.delivered = false
            }
            // A failed acknowledgement write retries persistence, not the helper effect.
            try persist()
            failure = nil
            if let completed = checkpoint.completed { try onCompleted(completed) }
            checkpoint.delivered = true
            try persist()
        } catch {
            guard expected.generation == generation, !Task.isCancelled else { return }
            failure = (error as? ServiceFailure) ?? .persistence
            intent = Intent(generation: generation, presentation: UUID())
        }
    }
}

enum LeftoverHelperAlert {
    @MainActor static func make() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "A helper from your last install"
        alert.informativeText = "Reconnect it and Components pick up where they left off. Or remove it."
        alert.addButton(withTitle: "Reconnect").keyEquivalent = "\r"
        alert.addButton(withTitle: "Remove Helper")
        // Escape/close must never mean destructive consent. No custom icon or styling.
        return alert
    }

    @MainActor static func present(_ prompt: LeftoverHelperPrompt) async {
        await prompt.discover()
        while let intent = prompt.intent {
            let alert = make()
            let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
                MainActor.assumeIsolated {
                    if prompt.intent != intent { NSApp.abortModal(); alert.window.orderOut(nil) }
                }
            }
            RunLoop.main.add(timer, forMode: .modalPanel)
            let response = alert.runModal()
            timer.invalidate()
            alert.window.orderOut(nil)
            switch response {
            case .alertFirstButtonReturn: await prompt.perform(.reconnect, intent: intent)
            case .alertSecondButtonReturn: await prompt.perform(.remove, intent: intent)
            default: prompt.close(intent)
            }
            // Failed attempts retain a fresh intent for an explicit later retry, no modal loop.
            if prompt.failure != nil { return }
        }
    }
}
