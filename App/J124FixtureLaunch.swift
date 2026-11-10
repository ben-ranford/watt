#if DEBUG
import AppKit

@MainActor
enum J124FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J12.4/base"
        }
        return false
        #endif
    }
    static func makePrompt() -> LeftoverHelperPrompt {
        let prompt = LeftoverHelperPrompt(storage: InMemoryStorage(), installationID: UUID())
        prompt.detect = { true }
        prompt.reconnect = { .connected }
        prompt.remove = { _ in .verifiedAbsent }
        return prompt
    }
    static func launch() {
        NSApp.activate(ignoringOtherApps: true)
        Task { await LeftoverHelperAlert.present(makePrompt()) }
    }
}
#endif
