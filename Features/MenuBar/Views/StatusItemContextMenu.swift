import AppKit

/// Native secondary-click menu attached to the single SwiftUI status item.
@MainActor
enum StatusItemContextMenu {
    // These are native NSMenu metrics, not custom row geometry. AppKit owns
    // the menu material, typography, separators, hit targets, keyboard
    // navigation and accessibility semantics.
    static let referenceMenuWidth: CGFloat = 230
    static let referenceReadingsMenuWidth: CGFloat = 190
    static let unavailableReadingsMenuWidth: CGFloat = 250

    static func makeMenu(
        router: AppRouter, preferences: PreferencesStore,
        componentsAvailable: @escaping () -> Bool = { false },
        onAbout: @escaping () -> Void = { NSApplication.shared.orderFrontStandardAboutPanel(nil) },
        onQuit: @escaping () -> Void = { NSApplication.shared.terminate(nil) }
    ) -> NSMenu {
        let presentationID = router.beginMenuSetupPresentation()
        let menu = SetupContextMenu { router.endMenuSetupPresentation(presentationID) }
        menu.minimumWidth = referenceMenuWidth
        menu.showsStateColumn = true
        func add(_ title: String, key: String = "", to menu: NSMenu, action: @escaping () -> Void) {
            let item = ActionMenuItem(title: title) {
                defer { router.endMenuSetupPresentation(presentationID) }
                action()
            }
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = key.isEmpty ? [] : .command
            menu.addItem(item)
        }
        if !preferences.onboarding.completed {
            let expected = preferences.onboarding
            add("Finish Setup…", to: menu) {
                router.finishSetupFromMenu(preferences: preferences, expected: expected,
                                           presentationID: presentationID)
            }
            menu.addItem(.separator())
        }
        let effectiveMode: WattDisplayMode = router.settingsHelperSetup.helperSwitchedOff ? .delta : preferences.displayMode
        let componentsCanBeSelected = !router.settingsHelperSetup.helperSwitchedOff
            && preferences.componentReadings && componentsAvailable()
        let readings = NSMenu()
        // Unavailable component readings use the wider menu (250pt). Available
        // readings use the compact menu (190pt). AppKit still owns all row
        // metrics and material.
        if componentsCanBeSelected {
            readings.minimumWidth = referenceReadingsMenuWidth
        } else {
            readings.minimumWidth = unavailableReadingsMenuWidth
        }
        readings.showsStateColumn = true
        readings.autoenablesItems = false
        for mode in WattDisplayMode.allCases {
            if mode == .iconOnly { readings.addItem(.separator()) }
            add(mode.title, to: readings) {
                guard mode != .components || (!router.settingsHelperSetup.helperSwitchedOff
                    && preferences.componentReadings && componentsAvailable()) else { return }
                preferences.displayMode = mode
            }
            readings.items.last?.isEnabled = mode != .components || componentsCanBeSelected
            readings.items.last?.state = effectiveMode == mode ? .on : .off
            readings.items.last?.setAccessibilityLabel(mode.title)
        }
        if router.settingsHelperSetup.helperSwitchedOff || !preferences.componentReadings || !componentsAvailable() {
            readings.addItem(.separator())
            add("Turn On Helper…", to: readings, action: router.showSettings)
        }
        let parent = NSMenuItem(title: "Show in Menu Bar", action: nil, keyEquivalent: "")
        parent.keyEquivalentModifierMask = []
        parent.submenu = readings
        menu.addItem(parent)
        menu.addItem(.separator())
        add("Open Watt?", to: menu, action: router.showStatusPanel)
        add("Settings…", key: ",", to: menu, action: router.showSettings)
        menu.addItem(.separator())
        add("About Watt?", to: menu, action: onAbout)
        let check = ActionMenuItem(title: "Check for Updates…", isEnabled: { router.canCheckForUpdates }) {
            router.checkForUpdatesFromMenu(presentationID: presentationID)
        }
        check.keyEquivalentModifierMask = []
        check.isEnabled = router.canCheckForUpdates
        menu.addItem(check)
        menu.addItem(.separator())
        add("Quit Watt?", key: "q", to: menu, action: onQuit)
        return menu
    }

    /// Call after synchronous native popup tracking returns, including cancellation.
    /// menuDidClose can precede the selected item's action, so it is not this boundary.
    static func endPresentation(_ menu: NSMenu) {
        (menu as? SetupContextMenu)?.endPresentation()
    }
}

private final class SetupContextMenu: NSMenu {
    let endPresentation: () -> Void

    init(endPresentation: @escaping () -> Void) {
        self.endPresentation = endPresentation
        super.init(title: "")
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

private final class ActionMenuItem: NSMenuItem, NSMenuItemValidation {
    private let handler: () -> Void
    private let isActionEnabled: () -> Bool

    init(title: String, isEnabled: @escaping () -> Bool = { true }, action: @escaping () -> Void) {
        handler = action
        isActionEnabled = isEnabled
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { isActionEnabled() }
    @objc private func invoke() { guard isActionEnabled() else { return }; handler() }
}
