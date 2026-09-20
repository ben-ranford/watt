import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var powerStore: PowerReadingStore

    var body: some View {
        StatusPanelView(reading: powerStore.currentReading) {
            router.showSettings()
        } onQuit: {
            NSApplication.shared.terminate(nil)
        }
        .frame(width: 320)
    }
}
