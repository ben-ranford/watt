import AppKit
import SwiftUI

struct StatusItemContextMenu: View {
    @EnvironmentObject private var router: AppRouter
    let openWindow: OpenWindowAction

    var body: some View {
        Button("Open Watt?", action: router.showStatusPanel)
        Button("Settings…", action: router.showSettings)
        Divider()
        Menu("Show in Menu Bar") {
            Button("Battery Delta") {}
            Button("Charger Input") {}
            Button("System Draw") {}
            Button("Per Component") {}
            Button("Icon Only") {}
        }
        Button("Check for Updates…") {
            router.showUpdate()
            openWindow(id: "update")
        }
        Divider()
        Button("Quit Watt?", role: .destructive) {
            NSApplication.shared.terminate(nil)
        }
    }
}
