import SwiftUI

@main
struct WattApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var powerStore = PowerReadingStore.preview
    @StateObject private var preferences = PreferencesStore.preview
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
        } label: {
            MenuBarStatusLabel(reading: powerStore.currentReading)
                .contextMenu {
                    StatusItemContextMenu(openWindow: openWindow)
                        .environmentObject(router)
                }
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to Watt?", id: "onboarding") {
            RootSceneView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
                .frame(minWidth: 480, idealWidth: 480, minHeight: 308)
        }
        .windowResizability(.contentSize)

        Window("Watt? Update", id: "update") {
            RootSceneView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
                .frame(minWidth: 360, idealWidth: 420, minHeight: 180)
        }

        Settings {
            SettingsRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
        }
    }
}
