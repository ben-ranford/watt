import AppKit
import SwiftUI

/// A real popup with independent checked items. AppKit owns rendering and interaction.
struct ComponentSelectionMenu: NSViewRepresentable {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var powerStore: PowerReadingStore
    @ObservedObject var helper: SettingsHelperSetup

    func makeCoordinator() -> Coordinator {
        Coordinator(preferences: preferences) {
            helper.helperSwitchedOff ? [] : powerStore.availableComponentIDs
        }
    }

    func makeNSView(context: Context) -> NSPopUpButton { context.coordinator.makeButton() }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.refresh()
    }

    @MainActor
    final class Coordinator: NSObject, NSMenuDelegate {
        static let componentNames = ["CPU", "GPU", "Display", "SSD", "Other"]
        private let preferences: PreferencesStore
        private let availableIDs: () -> [String]
        private weak var button: NSPopUpButton?

        init(preferences: PreferencesStore, availableIDs: @escaping () -> [String]) {
            self.preferences = preferences
            self.availableIDs = availableIDs
        }

        func makeButton() -> NSPopUpButton {
            let button = NSPopUpButton(frame: .zero, pullsDown: false)
            let cell = button.cell as? NSPopUpButtonCell
            cell?.usesItemFromMenu = false
            cell?.altersStateOfSelectedItem = false
            let menu = NSMenu(title: "Components")
            menu.autoenablesItems = false
            menu.showsStateColumn = true
            menu.delegate = self
            for name in Self.componentNames {
                let item = NSMenuItem(title: name, action: #selector(toggle(_:)), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            button.menu = menu
            button.setAccessibilityLabel("Components")
            button.setAccessibilityHelp(SettingsRootView.componentSelectionSubtitle)
            button.setAccessibilityIdentifier("settings.components")
            self.button = button
            refresh()
            return button
        }

        func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

        func refresh() {
            guard let button else { return }
            let available = preferences.componentReadings ? availableIDs() : []
            for item in button.itemArray {
                let id = available.first { $0.lowercased() == item.title.lowercased() }
                let selected = preferences.selectedComponents.contains { $0.lowercased() == item.title.lowercased() }
                item.state = selected ? .on : .off
                item.isEnabled = id != nil && (selected || preferences.selectedComponents.count < 2)
            }
            let value = preferences.selectedComponents.map { id in
                Self.componentNames.first { $0.lowercased() == id.lowercased() } ?? id
            }.joined(separator: ", ")
            // A separate native cell item keeps the summary independent of clicked menu items.
            (button.cell as? NSPopUpButtonCell)?.menuItem = NSMenuItem(
                title: value.isEmpty ? "None" : value, action: nil, keyEquivalent: "")
            button.setAccessibilityValue(value.isEmpty ? "None" : value)
            button.invalidateIntrinsicContentSize()
        }

        @objc func toggle(_ sender: NSMenuItem) {
            guard let id = availableIDs().first(where: { $0.lowercased() == sender.title.lowercased() }) else {
                refresh()
                return
            }
            preferences.toggleComponent(id, availableIDs: availableIDs())
            refresh()
        }
    }
}
