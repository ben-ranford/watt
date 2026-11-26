import AppKit
import Combine
import SwiftUI
import UserNotifications
#if SWIFT_PACKAGE
import WattHelperShared
#endif

@main
struct WattApp: App {
    @NSApplicationDelegateAdaptor(WattApplicationDelegate.self) private var applicationDelegate
    @StateObject private var router: AppRouter
    @StateObject private var powerStore: PowerReadingStore
    @StateObject private var preferences: PreferencesStore

    private static var isHarnessLaunch: Bool {
        ProcessInfo.processInfo.arguments.dropFirst().contains { $0.hasPrefix("--watt-") && $0 != "--watt-update-handshake" }
    }

    init() {
        if Array(ProcessInfo.processInfo.arguments.dropFirst()) == ["--watt-update-handshake"] {
            do { try UpdateLaunchAcknowledgementService.acknowledge() }
            catch { exit(EXIT_FAILURE) }
        }
        #if DEBUG
        if let rejection = WattFixtureLaunchGate.rejection(arguments: ProcessInfo.processInfo.arguments.filter { $0 != "--watt-update-handshake" }) {
            FileHandle.standardError.write(Data((rejection + "\n").utf8))
            // Exit before constructing stores or allowing SwiftUI to evaluate any scene.
            exit(EXIT_FAILURE)
        }
        #endif
        #if DEBUG && !SWIFT_PACKAGE
        // Controlled empty-state launch: exit before stores, scenes or status items exist.
        if J123FixtureLaunch.requested { exit(EXIT_SUCCESS) }
        #endif
        #if DEBUG && !SWIFT_PACKAGE
        if J125FixtureLaunch.requested || J124FixtureLaunch.requested || (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested) || J108FixtureLaunch.requested || J107FixtureLaunch.requested || J106FixtureLaunch.requested || J105FixtureLaunch.requested || J104FixtureLaunch.requested || J103FixtureLaunch.requested || J102FixtureLaunch.requested || J93FixtureLaunch.requested || J92FixtureLaunch.requested || J91FixtureLaunch.requested || J83FixtureLaunch.requested || J112FixtureLaunch.requested || J82FixtureLaunch.requested || J81FixtureLaunch.requested || J74FixtureLaunch.requested || J73FixtureLaunch.requested || J72FixtureLaunch.requested || J71FixtureLaunch.requested || J65FixtureLaunch.requested || J64FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J61FixtureLaunch.requested || J111FixtureLaunch.requested || J53FixtureLaunch.requested || J52FixtureLaunch.requested || J51FixtureLaunch.requested || J43FixtureLaunch.requested || J42FixtureLaunch.requested || J41FixtureLaunch.requested || J33FixtureLaunch.requested || J32FixtureLaunch.requested || J31FixtureLaunch.requested || J25FixtureLaunch.requested || J24FixtureLaunch.requested || J23FixtureLaunch.requested || J22FixtureLaunch.requested || J21FixtureLaunch.requested || J18FixtureLaunch.requested || J17FixtureLaunch.requested || J16FixtureLaunch.requested || J15FixtureLaunch.requested || J14FixtureLaunch.requested || J13FixtureLaunch.requested || J12FixtureLaunch.requested || J11FixtureLaunch.requested || C05FixtureLaunch.requested || C01FixtureLaunch.requested || C02FixtureLaunch.requested || C03FixtureLaunch.requested || C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
            let appRouter = AppRouter()
            appRouter.onUninstalled = { NSApplication.shared.terminate(nil) }
            AboutPanel.presentWhatsNew = { [weak appRouter] in
                appRouter?.showInstalledReleaseNotes()
            }
            _router = StateObject(wrappedValue: appRouter)
            let fixturePowerStore = (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested)
                ? J121FixtureLaunch.makeStore()
                : J108FixtureLaunch.requested
                ? J61FixtureLaunch.makeStore()
                : J93FixtureLaunch.requested
                ? J93FixtureLaunch.makeStore()
                : J125FixtureLaunch.requested
                ? J125FixtureLaunch.makeStore()
                : J92FixtureLaunch.requested
                ? J92FixtureLaunch.makeStore()
                : J91FixtureLaunch.requested
                ? J91FixtureLaunch.makeStore()
                : J83FixtureLaunch.requested
                ? J83FixtureLaunch.makeStore()
                : J82FixtureLaunch.requested
                ? J82FixtureLaunch.makeStore()
                : J81FixtureLaunch.requested
                ? J81FixtureLaunch.makeStore()
                : J74FixtureLaunch.requested
                ? J74FixtureLaunch.makeStore()
                : J73FixtureLaunch.requested
                ? J73FixtureLaunch.makeStore()
                : J72FixtureLaunch.requested
                ? J72FixtureLaunch.makeStore()
                : J71FixtureLaunch.requested
                ? J71FixtureLaunch.makeStore()
                : J65FixtureLaunch.requested
                ? J65FixtureLaunch.makeStore()
                : J64FixtureLaunch.requested
                ? J64FixtureLaunch.makeStore()
                : J63FixtureLaunch.requested
                ? J63FixtureLaunch.makeStore()
                : J62FixtureLaunch.requested
                ? J62FixtureLaunch.makeStore()
                : J61FixtureLaunch.requested
                ? J61FixtureLaunch.makeStore()
                : J112FixtureLaunch.requested
                ? J112FixtureLaunch.makeStore()
                : J111FixtureLaunch.requested
                ? J111FixtureLaunch.makeStore()
                : J43FixtureLaunch.requested
                ? J43FixtureLaunch.makeStore()
                : C049FixtureLaunch.requested
                ? C049FixtureLaunch.makeStore()
                : C048FixtureLaunch.requested
                ? C048FixtureLaunch.makeStore()
                : C047FixtureLaunch.requested
                ? C047FixtureLaunch.makeStore()
                : C046FixtureLaunch.requested
                ? C046FixtureLaunch.makeStore()
                : C045FixtureLaunch.requested
                ? C045FixtureLaunch.makeStore()
                : C044FixtureLaunch.requested
                ? C044FixtureLaunch.makeStore()
                : C043FixtureLaunch.requested
                ? C043FixtureLaunch.makeStore()
                : (C042FixtureLaunch.requested || C0412FixtureLaunch.requested)
                ? C042FixtureLaunch.makeStore()
                : C02FixtureLaunch.requested
                    ? PowerReadingStore(currentReading: .sampleOnBattery, clock: FakeWattClock(now: PowerReading.sampleOnBattery.timestamp))
                    : PowerReadingStore.preview
            _powerStore = StateObject(wrappedValue: fixturePowerStore)
            let fixturePreferences = (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested)
                ? J121FixtureLaunch.makePreferences()
                : J108FixtureLaunch.requested
                ? J61FixtureLaunch.makePreferences()
                : J93FixtureLaunch.requested
                ? J93FixtureLaunch.makePreferences()
                : J125FixtureLaunch.requested
                ? J125FixtureLaunch.makePreferences()
                : J92FixtureLaunch.requested
                ? J92FixtureLaunch.makePreferences()
                : J91FixtureLaunch.requested
                ? J91FixtureLaunch.makePreferences()
                : J83FixtureLaunch.requested
                ? J83FixtureLaunch.makePreferences()
                : J82FixtureLaunch.requested
                ? J82FixtureLaunch.makePreferences()
                : J81FixtureLaunch.requested
                ? J81FixtureLaunch.makePreferences()
                : J74FixtureLaunch.requested
                ? J74FixtureLaunch.makePreferences()
                : J73FixtureLaunch.requested
                ? J73FixtureLaunch.makePreferences()
                : J72FixtureLaunch.requested
                ? J72FixtureLaunch.makePreferences()
                : J71FixtureLaunch.requested
                ? J71FixtureLaunch.makePreferences()
                : J65FixtureLaunch.requested
                ? J65FixtureLaunch.makePreferences()
                : J64FixtureLaunch.requested
                ? J64FixtureLaunch.makePreferences(variant: J64FixtureLaunch.variant)
                : J63FixtureLaunch.requested
                ? J63FixtureLaunch.makePreferences()
                : J62FixtureLaunch.requested
                ? J62FixtureLaunch.makePreferences()
                : J61FixtureLaunch.requested
                ? J61FixtureLaunch.makePreferences()
                : J112FixtureLaunch.requested
                ? J112FixtureLaunch.makePreferences()
                : J111FixtureLaunch.requested
                ? J111FixtureLaunch.makePreferences()
                : PreferencesStore(storage: InMemoryStorage())
            if J65FixtureLaunch.requested || J64FixtureLaunch.requested || J63FixtureLaunch.requested || J62FixtureLaunch.requested || J111FixtureLaunch.requested || J61FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J61FixtureLaunch.appearanceName)
            }
            if J112FixtureLaunch.requested || J113FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J112FixtureLaunch.appearanceName)
            }
            if J82FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J82FixtureLaunch.appearanceName)
            }
            if J92FixtureLaunch.requested || J91FixtureLaunch.requested || J83FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J83FixtureLaunch.appearanceName)
            }
            if J81FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J81FixtureLaunch.appearanceName)
            }
            if J74FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J74FixtureLaunch.appearanceName)
            }
            if J73FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J73FixtureLaunch.appearanceName)
            }
            if J72FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J72FixtureLaunch.appearanceName)
            }
            if J71FixtureLaunch.requested {
                NSApplication.shared.appearance = NSAppearance(named: J71FixtureLaunch.appearanceName)
            }
            if J51FixtureLaunch.requested { J51FixtureLaunch.prepare(preferences: fixturePreferences) }
            if J52FixtureLaunch.requested { J52FixtureLaunch.prepare(preferences: fixturePreferences) }
            if J53FixtureLaunch.requested { J53FixtureLaunch.prepare(preferences: fixturePreferences) }
            if J32FixtureLaunch.requested || J21FixtureLaunch.requested || J22FixtureLaunch.requested {
                fixturePreferences.componentReadings = false
                fixturePreferences.onboarding = .init(checkpoint: .livePanel, completed: true)
            }
            if J43FixtureLaunch.requested {
                J43FixtureLaunch.prepare(preferences: fixturePreferences)
            }
            if J18FixtureLaunch.requested {
                fixturePreferences.onboarding = .init(checkpoint: .livePanel, completed: true)
            }
            if J17FixtureLaunch.requested {
                fixturePreferences.onboarding = .init(checkpoint: .coachMark, completed: true)
            }
            if C05FixtureLaunch.requested { fixturePreferences.onboarding.completed = true }
            if C03FixtureLaunch.requested || C041FixtureLaunch.requested || C042FixtureLaunch.requested || C043FixtureLaunch.requested || C044FixtureLaunch.requested || C045FixtureLaunch.requested || C046FixtureLaunch.requested || C047FixtureLaunch.requested || C048FixtureLaunch.requested || C049FixtureLaunch.requested || C0410FixtureLaunch.requested || C0411FixtureLaunch.requested || C0412FixtureLaunch.requested {
                fixturePreferences.onboarding.completed = true
                fixturePreferences.displayMode = C048FixtureLaunch.requested ? .iconOnly : C047FixtureLaunch.requested ? .components : C046FixtureLaunch.requested ? .draw : (C044FixtureLaunch.requested || C045FixtureLaunch.requested) ? .charger : .delta
                fixturePreferences.showSymbol = !C047FixtureLaunch.requested
                C03FixtureLaunch.preferences = fixturePreferences
            }
            _preferences = StateObject(wrappedValue: fixturePreferences)
            if J18FixtureLaunch.requested {
                // MenuBarExtra is intentionally not relied on as the launch
                // trigger for this status-item fixture. Some macOS hosts do
                // not materialise its embedded bridge until the item is
                // clicked, which makes a first-open capture impossible. The
                // fixture still uses the same native NSStatusItem and
                // NSPopover implementation as production; this only starts it
                // from the app lifecycle for deterministic verification.
                DispatchQueue.main.async {
                    J18FixtureLaunch.launch(preferences: fixturePreferences,
                                            store: fixturePowerStore,
                                            router: appRouter)
                }
            }
            if J22FixtureLaunch.requested {
                // Start the same native status-item/popover harness directly.
                // This fixture must not depend on SwiftUI MenuBarExtra creating
                // its bridge before the panel can be opened on a host that has
                // no visible status-bar compositor slot.
                DispatchQueue.main.async {
                    J22FixtureLaunch.launch(preferences: fixturePreferences,
                                            store: fixturePowerStore,
                                            router: appRouter)
                }
            }
            if J21FixtureLaunch.requested {
                // J2.1 is a native menu interaction. Use an app-owned anchor
                // for deterministic capture rather than waiting for
                // MenuBarExtra's system compositor slot, which is unavailable
                // on some verification hosts. The menu itself remains the
                // production NSMenu/submenu implementation.
                DispatchQueue.main.async {
                    J21FixtureLaunch.launch(router: appRouter, preferences: fixturePreferences)
                }
            }
            if J112FixtureLaunch.requested {
                // The MenuBarExtra label is not guaranteed to materialise its
                // embedded bridge before Settings is opened. Prepare the
                // isolated helper fixture at composition time instead.
                Task { await J112FixtureLaunch.prepare(router: appRouter) }
            }
            return
        }
        #endif
        let bundleURL = Bundle.main.bundleURL
        // Desktop, Documents, Downloads, and iCloud Drive stall openat on the main
        // thread until a TCC dialog this accessory app cannot show. Do not open the
        // bundle, the update journal, or staging from here. Updates stay fail-closed
        // and no staged payload is touched.
        let protectedFolder = !Self.isHarnessLaunch && LaunchPathPolicy.isPrivacyProtected(bundleURL)
        // The helper's protected copy updates and removes itself. Another copy of the
        // same pinned build hands launch over to it; any other copy says why updates are off.
        let managedPlacement: ManagedCopyPolicy.Placement = Self.isHarnessLaunch || protectedFolder
            ? .noProtectedInstallation : ManagedCopyPolicy.current()
        let productionUpdate: ProductionUpdateComposition?
        let updateFailure: ServiceFailure?
        if Self.isHarnessLaunch || protectedFolder { productionUpdate = nil; updateFailure = protectedFolder ? .untrustedIdentity : nil }
        else {
            do { productionUpdate = try ProductionUpdateComposition.configured(); updateFailure = nil }
            catch { productionUpdate = nil; updateFailure = error as? ServiceFailure ?? .untrustedIdentity }
        }
        #if DEBUG
        // The menu fixture shows an enabled Check for Updates… row. Keep
        // that deterministic fixture state without composing an updater into
        // the real app, which remains fail-closed until a trusted P04 service
        // is configured.
        let updateStorage = UserDefaultsStorage(defaults: .standard)
        let appRouter = C03FixtureLaunch.requested
            ? AppRouter(updateService: FakeUpdateService(), whatsNewStorage: updateStorage)
            : AppRouter(updateService: productionUpdate?.adapter,
                updates: UpdateStore(storage: updateStorage), updateConfigurationFailure: updateFailure,
                whatsNewStorage: updateStorage)
        #else
        let updateStorage = UserDefaultsStorage(defaults: .standard)
        let appRouter = AppRouter(updateService: productionUpdate?.adapter,
            updates: UpdateStore(storage: updateStorage), updateConfigurationFailure: updateFailure,
            whatsNewStorage: updateStorage)
        #endif
        appRouter.updateUnavailableCause = protectedFolder
            ? .privacyProtectedFolder : ManagedCopyPolicy.updateCause(for: managedPlacement)
        AboutPanel.presentWhatsNew = { [weak appRouter] in
            appRouter?.showInstalledReleaseNotes()
        }
        if let update = productionUpdate {
            appRouter.configureUpdateInstallation(adapter: update.adapter)
            Task {
                await appRouter.recoverUpdateStartup(adapter: update.adapter)
                UpdateLaunchAcknowledgementService.retireHandshakeEvidence()
            }
        } else {
            UpdateLaunchAcknowledgementService.retireHandshakeEvidence()
        }
        let productionHelper: ProductionHelperComposition?
        if Self.isHarnessLaunch || protectedFolder {
            productionHelper = nil
            if protectedFolder {
                appRouter.settingsHelperSetup.unavailableReason = .configurationFailed
            }
        } else {
            do { productionHelper = try ProductionHelperComposition.configured() }
            catch {
                productionHelper = nil
                let bundle = Bundle.main.bundleURL
                let helper = bundle.appendingPathComponent("Contents/MacOS/" + HelperIdentity.executableName)
                let plist = bundle.appendingPathComponent("Contents/Library/LaunchDaemons/" + HelperIdentity.daemonPlist)
                appRouter.settingsHelperSetup.unavailableReason = .configurationFailure(error,
                    packagedHelperPresent: FileManager.default.fileExists(atPath: helper.path)
                        && FileManager.default.fileExists(atPath: plist.path))
                appRouter.settingsHelperSetup.presenceProbe = { HelperInstallPresence.current() }
                appRouter.settingsHelperSetup.installPresence = HelperInstallPresence.current()
            }
        }
        if let helper = productionHelper {
            appRouter.helperChangedAfterUpdate = helper.hasPendingUpdate
            appRouter.settingsHelperSetup.service = helper.service
            appRouter.settingsHelperSetup.configureRepair(receipt: helper.updateReceipt, pending: helper.hasPendingUpdate)
            appRouter.settingsHelperSetup.captureDiagnostic = {
                await HelperDiagnosticExport.present(transport: helper.transport)
            }
            let previousRemoval = appRouter.removeFromSettings
            var helperRemovalReceipt: OperationReceipt?
            appRouter.removeFromSettings = { target in
                guard target == .helper else { return await previousRemoval(target) }
                let receipt = helperRemovalReceipt ?? helper.removalReceipt()
                helperRemovalReceipt = receipt
                let result = await helper.service.remove(receipt: receipt)
                if case .verifiedAbsent = result { helperRemovalReceipt = nil }
                return result
            }
        }
        if !Self.isHarnessLaunch && !protectedFolder {
            do {
                let removal = try ProductionRemovalComposition.configured(helper: productionHelper?.service)
                appRouter.configureUninstall(coordinator: removal)
            } catch {
                let previous = appRouter.removeFromSettings
                appRouter.removeFromSettings = { target in
                    target == .uninstall ? .failed((error as? ServiceFailure) ?? .untrustedIdentity) : await previous(target)
                }
            }
        }
        appRouter.onUninstalled = { NSApplication.shared.terminate(nil) }
        appRouter.onMaintenanceHandoff = { WattApplicationDelegate.quitAfterUpdateHandoff() }
        _router = StateObject(wrappedValue: appRouter)
        let appPowerStore = PowerReadingStore(currentReading: .unavailable,
            telemetry: SystemPowerSourceTelemetryService(),
            componentTelemetry: productionHelper.map { ProductionHelperTelemetry(transport: $0.transport) })
        productionHelper?.transport.onInvalidated = { [weak appPowerStore, weak service = productionHelper?.service] in
            service?.connectionLost()
            appPowerStore?.invalidateComponents()
        }
        if productionHelper == nil, !Self.isHarnessLaunch, !protectedFolder,
           appRouter.settingsHelperSetup.unavailableReason == .installationRequired {
            let installer = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/WattHelperInstaller")
            if FileManager.default.isExecutableFile(atPath: installer.path) {
                appRouter.settingsHelperSetup.installHelper = { [weak appRouter, weak appPowerStore] in
                    guard let appRouter else { return .unknownStatus }
                    let source = Bundle.main.bundleURL
                    let rotate = FileManager.default.fileExists(atPath: ProtectedHelperRecord.publicURL.path)
                    if let failure = await HelperBundleInstall.install(installer: installer, source: source, rotate: rotate) {
                        return failure
                    }
                    let helper: ProductionHelperComposition
                    do { helper = try ProductionHelperComposition.adoptInstalled() }
                    catch { return (error as? ServiceFailure) ?? .untrustedIdentity }
                    appRouter.helperChangedAfterUpdate = helper.hasPendingUpdate
                    appRouter.settingsHelperSetup.service = helper.service
                    appRouter.settingsHelperSetup.configureRepair(receipt: helper.updateReceipt, pending: helper.hasPendingUpdate)
                    appRouter.settingsHelperSetup.captureDiagnostic = {
                        await HelperDiagnosticExport.present(transport: helper.transport)
                    }
                    let previousRemoval = appRouter.removeFromSettings
                    var helperRemovalReceipt: OperationReceipt?
                    appRouter.removeFromSettings = { target in
                        guard target == .helper else { return await previousRemoval(target) }
                        let receipt = helperRemovalReceipt ?? helper.removalReceipt()
                        helperRemovalReceipt = receipt
                        let result = await helper.service.remove(receipt: receipt)
                        if case .verifiedAbsent = result { helperRemovalReceipt = nil }
                        return result
                    }
                    appPowerStore?.attachComponentTelemetry(ProductionHelperTelemetry(transport: helper.transport))
                    helper.transport.onInvalidated = { [weak appPowerStore, weak service = helper.service] in
                        service?.connectionLost()
                        appPowerStore?.invalidateComponents()
                    }
                    await appRouter.settingsHelperSetup.refreshStatus()
                    return nil
                }
            }
        }
        let appPreferences = PreferencesStore(storage: UserDefaultsStorage(defaults: .standard))
        _powerStore = StateObject(wrappedValue: appPowerStore)
        _preferences = StateObject(wrappedValue: appPreferences)
        // The fallback owns the visible production status item on hosts where
        // MenuBarExtra does not materialise, so keep reopen routing alive there
        // as well as in the SwiftUI scene bridge.
        applicationDelegate.onReopen = { [weak appRouter] in
            appRouter?.reopen(preferences: appPreferences)
        }
        // MenuBarExtra is the preferred SwiftUI path, but it is not materialising
        // an item on some macOS hosts (including the local verification host). Keep
        // the user-facing app usable with the public AppKit status-item API while
        // retaining MenuBarExtra for all fixture launches.
        if !Self.isHarnessLaunch {
            let notificationBridge = SystemNotificationBridge(driver: NativeNotificationDriver(center: .current()))
            appRouter.notificationBridge = notificationBridge
            appRouter.powerNotificationEffects = PowerNotificationEffects(bridge: notificationBridge, preferences: appPreferences)
            Task { @MainActor in
                appRouter.notificationAuthorization = await notificationBridge.authorization()
            }
            // App.init can run before NSApplication has finished registering its
            // status-bar scene. The delegate installs the public NSStatusItem
            // from applicationDidFinishLaunching instead.
            applicationDelegate.scheduleFallbackStatusItem(router: appRouter,
                                                            powerStore: appPowerStore,
                                                            preferences: appPreferences)
            if protectedFolder { ApplicationsFolderGuidance.presentIfNeeded(bundleURL: bundleURL) }
            // After the handshake has returned, drop any older Watt that did
            // not exit. The next turn is late enough that this process is no
            // longer inside the parent's launch wait.
            Task { @MainActor in
                if case .sameBuildElsewhere(let managed) = managedPlacement,
                   await ManagedCopyPolicy.openManagedCopy(managed) {
                    NSApplication.shared.terminate(nil)
                    return
                }
                SingleInstanceClaim.becomeOnlyInstance(managedBundle: managedPlacement == .managed ? bundleURL : nil)
            }
        }
    }

    private var menuBarExtraInserted: Binding<Bool> {
        #if DEBUG
        if J124FixtureLaunch.requested { return .constant(false) }
        if J42FixtureLaunch.requested || J41FixtureLaunch.requested || J33FixtureLaunch.requested || J31FixtureLaunch.requested || J25FixtureLaunch.requested || J24FixtureLaunch.requested || J23FixtureLaunch.requested || J17FixtureLaunch.requested || J16FixtureLaunch.requested || J15FixtureLaunch.requested || J14FixtureLaunch.requested || J13FixtureLaunch.requested || J12FixtureLaunch.requested || J11FixtureLaunch.requested || C05FixtureLaunch.requested { return .constant(false) }
        if C041FixtureLaunch.captureRequested || C042FixtureLaunch.captureRequested || C043FixtureLaunch.captureRequested || C044FixtureLaunch.captureRequested || C045FixtureLaunch.captureRequested || C046FixtureLaunch.captureRequested || C047FixtureLaunch.captureRequested || C048FixtureLaunch.captureRequested || C049FixtureLaunch.captureRequested || C0410FixtureLaunch.captureRequested || C0411FixtureLaunch.captureRequested || C0412FixtureLaunch.captureRequested { return .constant(false) }
        #endif
        // The normal launch uses the explicit AppKit status item fallback. SwiftUI
        // MenuBarExtra remains the production fixture path and is still exercised
        // by the visual/native evidence harnesses.
        return .constant(Self.isHarnessLaunch)
    }

    private var statusLabel: MenuBarStatusLabel {
        MenuBarStatusLabel(reading: powerStore.statusReading, preferences: preferences,
                           helperSwitchedOff: router.settingsHelperSetup.helperSwitchedOff)
    }

    private var settingsMenuBarExcerpt: Bool {
        #if DEBUG
        J73FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsRelaunchExcerpt: Bool {
        #if DEBUG
        J83FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsConfirmUninstallExcerpt: Bool {
        #if DEBUG
        J122FixtureLaunch.requested || J113FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsUninstallExcerpt: Bool {
        #if DEBUG
        (J121FixtureLaunch.requested || J122FixtureLaunch.requested || J113FixtureLaunch.requested)
        #else
        false
        #endif
    }

    private var settingsRemovedExcerpt: Bool {
        #if DEBUG
        J92FixtureLaunch.requested
        #else
        false
        #endif
    }

    private var settingsRemovalExcerpt: Bool {
        #if DEBUG
        J91FixtureLaunch.requested || J125FixtureLaunch.requested
        #else
        false
        #endif
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarExtraInserted) {
            MenuBarRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
        } label: {
            statusLabel
                // The task identity is the preference value so changing the
                // native Settings picker cancels the old sleep immediately and
                // starts the sampler with the new cadence.
                .task(id: preferences.updateInterval) {
                    await powerStore.runSampling(interval: { preferences.updateIntervalSeconds })
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                    guard powerStore.observesSystemWake else { return }
                    powerStore.handleWake()
                    Task { await powerStore.refresh() }
                }
                .onReceive(powerStore.$componentEstimate) { pair in
                    if let pair { router.settingsHelperSetup.confirmRecoveredComponents(PowerReading.unavailable.presenting(pair)) }
                }
                .onReceive(powerStore.$currentReading) { reading in
                    router.settingsHelperSetup.confirmRecoveredComponents(reading)
                    Task { await PowerNotificationDelivery.deliver(store: powerStore, router: router) }
                }
                .background {
                    ScenePresentationBridge(router: router, preferences: preferences, powerStore: powerStore,
                                            applicationDelegate: applicationDelegate)
                }
        }
        .menuBarExtraStyle(.window)

        Window("", id: "onboarding") {
            OnboardingFlowView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
                .frame(minWidth: WattSpacing.onboardingWidth, idealWidth: WattSpacing.onboardingWidth)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Window("Software Update", id: "software-update") {
            UpdateRootView(softwareUpdate: true)
                .environmentObject(router)
        }
        .windowResizability(.contentSize)

        Window("Watt? Update", id: "update") {
            UpdateRootView()
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
                .frame(minWidth: 360, idealWidth: 420, minHeight: 180)
        }

        Window("What’s New", id: "whats-new") {
            WhatsNewScene()
                .environmentObject(router)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsRootView(menuBarExcerpt: settingsMenuBarExcerpt,
                             relaunchExcerpt: settingsRelaunchExcerpt, removalExcerpt: settingsRemovalExcerpt,
                             removedExcerpt: settingsRemovedExcerpt,
                             uninstallExcerpt: settingsUninstallExcerpt,
                             confirmUninstallExcerpt: settingsConfirmUninstallExcerpt)
                .environmentObject(router)
                .environmentObject(powerStore)
                .environmentObject(preferences)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class WattApplicationDelegate: NSObject, NSApplicationDelegate {
    var onReopen: (() -> Void)?
    var onTerminate: (() -> Void)?
    private(set) var isTerminating = false
    /// Set before an update handoff quit so a confirm-quit or a window cannot cancel it.
    static var handoffRequiresQuit = false

    /// Quits on the main actor. Windows cannot keep a modal session or a
    /// delegate from swallowing the update handoff.
    static func quitAfterUpdateHandoff() {
        handoffRequiresQuit = true
        let app = NSApplication.shared
        for window in app.windows {
            window.preventsApplicationTerminationWhenModal = false
            window.delegate = nil
        }
        app.reply(toApplicationShouldTerminate: true)
        app.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        UpdateHandoffQuit.reply(handoffRequiresQuit: Self.handoffRequiresQuit,
                                confirmationAllowsQuit: !Self.handoffRequiresQuit)
    }
    private var fallbackStatusItem: WattFallbackStatusItem?
    private var pendingFallbackInstall: (() -> Void)?

    @MainActor
    func scheduleFallbackStatusItem(router: AppRouter, powerStore: PowerReadingStore,
                                    preferences: PreferencesStore) {
        pendingFallbackInstall = { [weak self] in
            self?.installFallbackStatusItem(router: router, powerStore: powerStore,
                                            preferences: preferences)
        }
    }

    @MainActor
    func installFallbackStatusItem(router: AppRouter, powerStore: PowerReadingStore,
                                   preferences: PreferencesStore) {
        guard fallbackStatusItem == nil else { return }
        fallbackStatusItem = WattFallbackStatusItem(router: router, powerStore: powerStore,
                                                    preferences: preferences)
        fallbackStatusItem?.install()
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !isTerminating else { return }
        isTerminating = true
        onReopen = nil
        let cleanup = onTerminate
        onTerminate = nil
        cleanup?()
        fallbackStatusItem?.uninstall()
        fallbackStatusItem = nil
        // SwiftUI owns the MenuBarExtra/NSStatusItem. Process termination removes it;
        // do not remove a borrowed status item behind SwiftUI's back.
        NSApplication.shared.windows.forEach { $0.orderOut(nil) }
    }
    #if DEBUG
    private let capture = NativeCaptureDelegate()
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        let install = pendingFallbackInstall
        pendingFallbackInstall = nil
        // On some hosts NSStatusBar has a zero-height window during the
        // applicationDidFinishLaunching callback. Defer one run-loop turn so
        // the system menu bar has finished materialising before creating the
        // public status item.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            install?()
        }
        #if DEBUG
        capture.applicationDidFinishLaunching(notification)
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isTerminating else { return false }
        onReopen?()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct ScenePresentationBridge: View {
    let router: AppRouter
    let preferences: PreferencesStore
    let powerStore: PowerReadingStore
    let applicationDelegate: WattApplicationDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if #available(macOS 14, *) {
            ModernScenePresentationBridge(router: router, preferences: preferences, powerStore: powerStore,
                                          applicationDelegate: applicationDelegate)
        } else {
            StatusItemAdapter(router: router, preferences: preferences, powerStore: powerStore,
                              applicationDelegate: applicationDelegate, openWindow: openWindow) {
                NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}

@available(macOS 14, *)
private struct ModernScenePresentationBridge: View {
    let router: AppRouter
    let preferences: PreferencesStore
    let powerStore: PowerReadingStore
    let applicationDelegate: WattApplicationDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        StatusItemAdapter(router: router, preferences: preferences, powerStore: powerStore,
                          applicationDelegate: applicationDelegate, openWindow: openWindow) {
            openSettings()
        }
    }
}
