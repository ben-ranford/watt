import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

#if DEBUG
@MainActor
enum J31FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J3.1/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let router = AppRouter()
        router.openApprovalSettings = {} // No fixture effects on OS settings.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 269),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = SettingsRootView.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsRootView(helperExcerpt: true)
            .environmentObject(preferences).environmentObject(router)
            .task { router.settingsHelperSetup.cancel() })
        window.center()
        return window
    }
}
#endif

#if DEBUG
@MainActor
enum J32FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J3.2/base"
        }
        return false
        #endif
    }
}
#endif

#if DEBUG
@MainActor
enum J33FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J3.3/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        preferences.onboarding.completed = true
        let router = AppRouter()
        router.openApprovalSettings = {} // No fixture effects on OS settings.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 269),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Watt? Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView()
            .environmentObject(preferences).environmentObject(router)
            .task { router.helperUpdate.presented = true })
        window.center()
        return window
    }
}
#endif
