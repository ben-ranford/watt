import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var powerStore: PowerReadingStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var setupPresentationID: UUID?

    private var chargerDescription: String? {
        #if DEBUG
        J64FixtureLaunch.requested ? "67 W USB-C charger" : (J111FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J61FixtureLaunch.requested || C01FixtureLaunch.requested || J17FixtureLaunch.requested || J18FixtureLaunch.requested) ? "96 W USB-C charger" : nil
        #else
        nil
        #endif
    }

    private var includesComponents: Bool {
        #if DEBUG
        !J61FixtureLaunch.requested && !J62FixtureLaunch.requested && !J63FixtureLaunch.requested && !J64FixtureLaunch.requested && !J65FixtureLaunch.requested
        #else
        true
        #endif
    }

    var body: some View {
        let expectedSetup = preferences.onboarding
        let presentationID = setupPresentationID
        StatusPanelView(reading: powerStore.statusReading, chargerDescription: chargerDescription,
                        helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff,
                        componentReadingsEnabled: preferences.componentReadings,
                        includesComponents: includesComponents,
                        setupIncomplete: SetupPromptPresentation.canPresent(expectedSetup),
                        setupSaveFailed: preferences.persistenceFailure != nil,
                        helperInstallOffered: router.settingsHelperSetup.canInstallHelper,
                        onInstallHelper: {
                            Task { await router.settingsHelperSetup.installFromInterface() }
                            return
                        },
                        onContinueSetup: {
            router.continuePanelSetup(preferences: preferences, expected: expectedSetup,
                                      presentationID: presentationID)
        }, onRetry: {
            Task { await powerStore.refresh() }
        }, isRetrying: powerStore.isRefreshing) {
            router.showSettings()
        } onQuit: {
            NSApplication.shared.terminate(nil)
        }
        #if DEBUG
        .background { if J111FixtureLaunch.requested || J32FixtureLaunch.requested || J18FixtureLaunch.requested { J18PanelCaptureView() } }
        #endif
        .onAppear { setupPresentationID = router.beginPanelSetupPresentation() }
        .onDisappear {
            router.endPanelSetupPresentation(setupPresentationID)
            setupPresentationID = nil
        }
    }
}
