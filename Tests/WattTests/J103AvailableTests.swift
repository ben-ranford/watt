import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J103AvailableTests: XCTestCase {
    private func offered(storage: InMemoryStorage = InMemoryStorage()) async -> (AppRouter, FakeUpdateService) {
        let service = FakeUpdateService()
        service.availableVersion = .success("1.1")
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: storage))
        XCTAssertTrue(router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation()))
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        return (router, service)
    }

    func testInstallPersistsBothCheckboxChoicesBeforeDownload() async throws {
        for enabled in [true, false] {
            let storage = InMemoryStorage()
            let (router, service) = await offered(storage: storage)
            XCTAssertTrue(router.updates.saveAutomaticInstallChoice(!enabled))
            let generation = router.updates.generation
            XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: enabled))
            XCTAssertEqual(router.updates.state, .downloading(progress: 0))
            XCTAssertEqual(router.updates.installFutureUpdatesAutomatically, enabled)
            XCTAssertEqual(UpdateStore(storage: storage).installFutureUpdatesAutomatically, enabled)
            XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: !enabled))
            XCTAssertEqual(router.updates.installFutureUpdatesAutomatically, enabled)
            for _ in 0..<30 { await Task.yield() }
            XCTAssertFalse(service.transactions.isEmpty)
        }
    }

    func testInstallChoiceFailureIsVisibleAndRetryableWithoutDownloadEffects() async {
        let storage = InMemoryStorage()
        let (router, service) = await offered(storage: storage)
        let generation = router.updates.generation
        storage.failWrites = true
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: true))
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertFalse(router.updates.installFutureUpdatesAutomatically)
        XCTAssertNil(router.updates.downloadReceipt)
        XCTAssertNil(router.updateOfferIntent)
        for _ in 0..<30 { await Task.yield() }
        XCTAssertTrue(service.transactions.isEmpty)
        storage.failWrites = false
        XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: true))
        XCTAssertNil(router.updates.persistenceFailure)
        XCTAssertTrue(UpdateStore(storage: storage).installFutureUpdatesAutomatically)
        for _ in 0..<30 { await Task.yield() }
    }

    func testChoiceIsSavedBeforeDownloadJournalAndJournalFailureCanRetry() async {
        let storage = AutomaticInstallOrderingStorage()
        let store = UpdateStore(storage: storage)
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertTrue(store.accept(.available(version: "1.1"), generation: store.generation))
        let service = FakeUpdateService()
        let router = AppRouter(updateService: service, updates: store)
        storage.rejectDownloadJournal = true
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: store.generation, automaticUpdates: true))
        XCTAssertEqual(storage.choiceAtDownloadJournal, true)
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertEqual(store.state, .available(version: "1.1"))
        XCTAssertNil(store.downloadReceipt)
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertTrue(service.transactions.isEmpty)
        storage.rejectDownloadJournal = false
        XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: store.generation, automaticUpdates: false))
        XCTAssertEqual(storage.choiceAtDownloadJournal, false)
        for _ in 0..<30 { await Task.yield() }
    }

    func testInvalidInstallOfferCannotChangeSavedChoice() async {
        let storage = InMemoryStorage()
        let (router, service) = await offered(storage: storage)
        XCTAssertFalse(router.installOfferedUpdate(version: "wrong", generation: router.updates.generation, automaticUpdates: true))
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: UUID(), automaticUpdates: true))
        XCTAssertFalse(router.updates.installFutureUpdatesAutomatically)
        XCTAssertNil(storage.values["update.automatic-install.v1"])
        XCTAssertTrue(service.transactions.isEmpty)
    }

    func testAutomaticInstallPreferenceDefaultsOffAndNeverRestoresConsent() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        XCTAssertFalse(store.installFutureUpdatesAutomatically)
        XCTAssertTrue(store.saveAutomaticInstallChoice(true))
        let restored = UpdateStore(storage: storage)
        XCTAssertTrue(restored.installFutureUpdatesAutomatically)
        XCTAssertEqual(restored.state, .idle)
        XCTAssertNil(restored.downloadReceipt)
    }

    func testEveryActionHandsOffWithoutInstallationOrHelperEffects() async {
        for action: UpdateOfferAction in [.skip, .remindLater, .install] {
            let (router, service) = await offered()
            let generation = router.updates.generation
            XCTAssertTrue(router.chooseUpdateOffer(action, version: "1.1", generation: generation, automaticUpdates: true))
            XCTAssertEqual(router.updateOfferIntent, UpdateOfferIntent(action: action, version: "1.1", automaticUpdates: true))
            XCTAssertEqual(router.updates.state, action == .install ? .available(version: "1.1") : .idle)
            XCTAssertFalse(router.chooseUpdateOffer(action, version: "1.1", generation: generation, automaticUpdates: true))
            XCTAssertTrue(service.transactions.isEmpty)
            XCTAssertFalse(router.helperUpdate.presented)
        }
    }

    func testStaleWrongVersionAndUnconfiguredActionsFailClosed() async {
        let (router, _) = await offered()
        XCTAssertFalse(router.chooseUpdateOffer(.install, version: "1.2", generation: router.updates.generation, automaticUpdates: false))
        XCTAssertFalse(router.chooseUpdateOffer(.skip, version: "1.1", generation: UUID(), automaticUpdates: false))
        let closed = AppRouter()
        XCTAssertFalse(closed.chooseUpdateOffer(.install, version: "1.1", generation: closed.updates.generation, automaticUpdates: false))
        XCTAssertNil(router.updateOfferIntent)
    }

    func testFailedDismissPersistenceRetainsOfferAndCanRetry() async {
        let storage = InMemoryStorage()
        let (router, _) = await offered(storage: storage)
        let generation = router.updates.generation
        storage.failWrites = true
        XCTAssertFalse(router.chooseUpdateOffer(.remindLater, version: "1.1", generation: generation, automaticUpdates: false))
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        storage.failWrites = false
        XCTAssertTrue(router.chooseUpdateOffer(.remindLater, version: "1.1", generation: generation, automaticUpdates: false))
    }

    func testRestoredOfferRequiresFreshTrustedCheck() async {
        let storage = InMemoryStorage()
        _ = await offered(storage: storage)
        XCTAssertEqual(UpdateStore(storage: storage).state, .failed(.interruptedUpdate, nil))
    }

    func testRetainedReceiptCannotBeOverwrittenByOfferOrActions() throws {
        let storage = InMemoryStorage()
        let receipt = OperationReceipt(createdAt: Date())
        try storage.write(JSONEncoder().encode(UpdateState.staged(receipt)), key: "update.v1")
        let store = UpdateStore(storage: storage)
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        XCTAssertEqual(store.state, .failed(.interruptedUpdate, receipt))
        XCTAssertFalse(store.accept(.available(version: "1.1"), generation: store.generation))
        XCTAssertFalse(store.accept(.idle, generation: store.generation))
        XCTAssertFalse(router.chooseUpdateOffer(.skip, version: "1.1", generation: store.generation, automaticUpdates: false))
        XCTAssertFalse(router.canCheckForUpdates)
        XCTAssertEqual(UpdateStore(storage: storage).state, .failed(.interruptedUpdate, receipt))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureAndPackageIsolation() throws {
        let fixture = try ScenarioRegistry.resolve("J10.3")
        XCTAssertEqual(fixture.story.node, "J10.3")
        XCTAssertEqual(fixture.story.status, "implemented")
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.3/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.3/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.3"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.3/other"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J103FixtureLaunch.requested)
        #endif
    }
    #endif

    func testAvailableOfferCopy() throws {
        XCTAssertEqual(UpdateAvailableContent.headline(version: "1.1"), "Watt? 1.1 is out")
        XCTAssertEqual(UpdateAvailableContent.summary(installedVersion: "1.0"), "You have 1.0. Here’s what changed.")
        XCTAssertEqual(UpdateAvailableContent.changesHeading, "What changed")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/RootSceneView.swift"), encoding: .utf8)
        for token in [
            "Text(SoftwareUpdateWrapping.breakable(Self.headline(version: version)))",
            "Text(SoftwareUpdateWrapping.breakable(Self.summary(installedVersion: router.currentAppVersion)))",
            "Text(Self.changesHeading)",
            ".accessibilityLabel(Self.headline(version: version))",
            ".accessibilityLabel(Self.summary(installedVersion: router.currentAppVersion))",
            ".accessibilityLabel(Self.changesHeading)"
        ] {
            XCTAssertTrue(source.contains(token), token)
        }
        XCTAssertFalse(source.contains("A new version of Watt? is available"))
        XCTAssertFalse(source.contains("What’s New in"))
        XCTAssertFalse(source.contains("Neural Engine"))
        XCTAssertFalse(source.contains("version == \"1.1\""))
        XCTAssertTrue(source.contains("ReleaseNotesBlock(notes: router.promptNotes(version: version))"))
        XCTAssertTrue(source.contains("UpdateReleaseNotes.unavailable"))
    }

    func testAvailableNativeLayout() async {
        _ = NSApplication.shared
        let (router, _) = await offered()
        let host = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        XCTAssertEqual(host.fittingSize.width, SoftwareUpdateWindowMetrics.offerWidth, accuracy: 1)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, 334)
        XCTAssertLessThan(host.fittingSize.height, 500)
    }

    func testShortUpdateCopyIsNotRewrapped() {
        let headline = UpdateAvailableContent.headline(version: "1.4.0")
        XCTAssertEqual(SoftwareUpdateWrapping.breakable(headline), headline)
        XCTAssertFalse(headline.contains("\u{200B}"))
        let summary = UpdateAvailableContent.summary(installedVersion: "1.3.1")
        XCTAssertEqual(SoftwareUpdateWrapping.breakable(summary), summary)
    }

    func testOfferWindowIsWiderThanTheLegacyHost() {
        let legacy = CGSize(width: 420, height: 560)
        let fitted = CGSize(width: SoftwareUpdateWindowMetrics.offerWidth, height: 420)
        let size = SoftwareUpdateWindowMetrics.contentSize(fitting: fitted, visibleHeight: 1000)
        XCTAssertEqual(size.width, fitted.width)
        XCTAssertEqual(size.height, fitted.height)
        XCTAssertGreaterThan(size.width, legacy.width)
        let capped = SoftwareUpdateWindowMetrics.contentSize(
            fitting: CGSize(width: SoftwareUpdateWindowMetrics.offerWidth, height: 4000), visibleHeight: 700)
        XCTAssertEqual(capped.width, SoftwareUpdateWindowMetrics.offerWidth)
        XCTAssertLessThan(capped.height, 700)
        XCTAssertGreaterThanOrEqual(capped.height, SoftwareUpdateWindowMetrics.minimumHeight)
    }

    func testTallNotesScrollVerticallyAndKeepTheOfferWidth() {
        _ = NSApplication.shared
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 2400))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let fitted = CGSize(width: SoftwareUpdateWindowMetrics.offerWidth, height: 2400)
        let size = SoftwareUpdateWindowMetrics.contentSize(fitting: fitted, visibleHeight: 700)
        SoftwareUpdateWindowMetrics.place(host: host, fitted: fitted, in: window, contentSize: size)
        let content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertEqual(content.width, SoftwareUpdateWindowMetrics.offerWidth, accuracy: 1)
        XCTAssertGreaterThan(content.width, 420)
        XCTAssertLessThan(content.height, fitted.height)
        let scroll = window.contentView as? NSScrollView
        XCTAssertNotNil(scroll)
        XCTAssertFalse(scroll?.hasHorizontalScroller ?? true)
        XCTAssertEqual(scroll?.documentView?.frame.width ?? 0, SoftwareUpdateWindowMetrics.offerWidth, accuracy: 1)
        XCTAssertGreaterThan(scroll?.documentView?.frame.height ?? 0, content.height)
    }

    func testProductionFallbackHostFitsTheOffer() async throws {
        _ = NSApplication.shared
        let (router, _) = await offered()
        let fallback = WattFallbackStatusItem(router: router,
                                               powerStore: PowerReadingStore(currentReading: .unavailable),
                                               preferences: PreferencesStore(storage: InMemoryStorage()))
        fallback.install()
        defer { fallback.uninstall() }
        router.present(.softwareUpdate)
        let window = try XCTUnwrap(NSApp.windows.first { $0.identifier == SoftwareUpdateWindowMetrics.identifier })
        defer { window.close() }
        window.contentView?.layoutSubtreeIfNeeded()
        let content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertEqual(content.width, SoftwareUpdateWindowMetrics.offerWidth, accuracy: 2)
        XCTAssertGreaterThan(content.width, 420)
        let host = try XCTUnwrap(SoftwareUpdateWindowMetrics.hostingView(in: window))
        XCTAssertGreaterThanOrEqual(host.bounds.width + 1, SoftwareUpdateWindowMetrics.offerWidth)
        XCTAssertGreaterThanOrEqual(host.bounds.width + 1, host.fittingSize.width)
        assertHorizontallyContained(host)
        let titles = buttonTitles(in: host)
        if titles.contains("Skip This Version") {
            XCTAssertTrue(titles.contains("Remind Me Later"))
            XCTAssertTrue(titles.contains("Install Update"))
        }
    }

    func testCheckingWindowGrowsToTheOfferAndDownloadFitsAgain() async throws {
        _ = NSApplication.shared
        let store = UpdateStore(storage: InMemoryStorage())
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        let service = FakeUpdateService()
        service.availableVersion = .success("1.4.0")
        let router = AppRouter(updateService: service, updates: store)
        let window = SoftwareUpdateWindowMetrics.makeWindow(
            content: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.orderFront(nil)
        var content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertEqual(content.width, SoftwareUpdateWindowMetrics.compactWidth, accuracy: 2)
        let host = try XCTUnwrap(SoftwareUpdateWindowMetrics.hostingView(in: window))
        assertHorizontallyContained(host)

        XCTAssertTrue(store.accept(.available(version: "1.4.0"), generation: store.generation))
        content = waitForWidth(window, expected: SoftwareUpdateWindowMetrics.offerWidth)
        XCTAssertEqual(content.width, SoftwareUpdateWindowMetrics.offerWidth, accuracy: 2)
        XCTAssertGreaterThan(content.width, 420)
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThanOrEqual(host.bounds.width + 1, SoftwareUpdateWindowMetrics.offerWidth)
        assertHorizontallyContained(host)

        XCTAssertTrue(router.startUpdateDownload(version: "1.4.0", generation: store.generation))
        content = waitForWidth(window, expected: SoftwareUpdateWindowMetrics.compactWidth)
        XCTAssertEqual(content.width, SoftwareUpdateWindowMetrics.compactWidth, accuracy: 2)
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThanOrEqual(host.bounds.width + 1, host.fittingSize.width)
        assertHorizontallyContained(host)
    }

    func testLongVersionAndReleaseLineStayInsideTheOfferWindow() async throws {
        _ = NSApplication.shared
        let version = String(repeating: "2026.11.27.", count: 8)
        let url = "https://example.com/watt/notes/" + String(repeating: "release", count: 40)
        let service = FakeUpdateService()
        service.availableVersion = .success(version)
        service.offeredNotes = """
        ### Fixes

        * Read the notes at \(url)
        """
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: InMemoryStorage()))
        XCTAssertTrue(router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation()))
        for _ in 0..<40 {
            if case .available = router.updates.state { break }
            await Task.yield()
        }
        XCTAssertEqual(router.updates.state, .available(version: version))
        let window = SoftwareUpdateWindowMetrics.makeWindow(
            content: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        let content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertEqual(content.width, SoftwareUpdateWindowMetrics.offerWidth, accuracy: 2)
        let host = try XCTUnwrap(SoftwareUpdateWindowMetrics.hostingView(in: window))
        XCTAssertLessThanOrEqual(host.fittingSize.width, SoftwareUpdateWindowMetrics.offerWidth + 1)
        XCTAssertGreaterThanOrEqual(host.bounds.width + 1, host.fittingSize.width)
        assertHorizontallyContained(host)

        let notes = SoftwareUpdateWrapping.breakable(url)
        XCTAssertNotEqual(notes, url)
        let body = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        XCTAssertLessThanOrEqual(
            SoftwareUpdateWrapping.measuredWidth(notes, font: body, wrapping: SoftwareUpdateWindowMetrics.notesWidth),
            SoftwareUpdateWindowMetrics.notesWidth + 1)
        let headline = SoftwareUpdateWrapping.breakable(UpdateAvailableContent.headline(version: version))
        let semibold = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        XCTAssertLessThanOrEqual(
            SoftwareUpdateWrapping.measuredWidth(headline, font: semibold,
                                                 wrapping: SoftwareUpdateWindowMetrics.headlineWidth),
            SoftwareUpdateWindowMetrics.headlineWidth + 1)
        let column = SoftwareUpdateWindowMetrics.compactWidth - SoftwareUpdateWindowMetrics.margin * 2
            - SoftwareUpdateWindowMetrics.iconSide - SoftwareUpdateWindowMetrics.iconGap
        let downloading = SoftwareUpdateWrapping.breakable("Downloading Watt? \(version)…")
        XCTAssertLessThanOrEqual(
            SoftwareUpdateWrapping.measuredWidth(downloading, font: semibold, wrapping: column),
            column + 1)
    }

    private func waitForWidth(_ window: NSWindow, expected: CGFloat) -> NSSize {
        let deadline = Date(timeIntervalSinceNow: 1.5)
        var size = window.contentRect(forFrameRect: window.frame).size
        while abs(size.width - expected) > 2, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            size = window.contentRect(forFrameRect: window.frame).size
        }
        return size
    }

    private func buttonTitles(in view: NSView) -> [String] {
        var titles: [String] = []
        func walk(_ candidate: NSView) {
            if let button = candidate as? NSButton { titles.append(button.title) }
            candidate.subviews.forEach(walk)
        }
        walk(view)
        return titles
    }

    private func assertHorizontallyContained(_ host: NSView, file: StaticString = #filePath, line: UInt = #line) {
        host.layoutSubtreeIfNeeded()
        let limit = host.bounds.width
        func walk(_ view: NSView) {
            let frame = view.convert(view.bounds, to: host)
            XCTAssertGreaterThanOrEqual(frame.minX, -2, "\(type(of: view)) starts at \(frame.minX)", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, limit + 2, "\(type(of: view)) ends at \(frame.maxX) in \(limit)", file: file, line: line)
            view.subviews.forEach(walk)
        }
        host.subviews.forEach(walk)
    }
}

@MainActor
private final class AutomaticInstallOrderingStorage: PreferenceStorage {
    let memory = InMemoryStorage()
    var rejectDownloadJournal = false
    var choiceAtDownloadJournal: Bool?
    func read(key: String) throws -> Data? { try memory.read(key: key) }
    func write(_ data: Data, key: String) throws {
        if key == "update.v1",
           case .failed(.interruptedUpdate, .some) = try JSONDecoder().decode(UpdateState.self, from: data) {
            choiceAtDownloadJournal = try memory.read(key: "update.automatic-install.v1").map {
                try JSONDecoder().decode(Bool.self, from: $0)
            }
            if rejectDownloadJournal { throw ServiceFailure.persistence }
        }
        try memory.write(data, key: key)
    }
}
