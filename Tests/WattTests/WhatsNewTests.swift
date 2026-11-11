import XCTest
@testable import Watt

@MainActor
final class WhatsNewTests: XCTestCase {
    private let notes = "### Changes\n\n* staged rollout\n* what’s new"

    func testFreshInstallAndSameVersionStayQuiet() throws {
        let store = WhatsNewStore(storage: InMemoryStorage())
        XCTAssertEqual(try store.launch("1.2.0"), .suppress)
        XCTAssertEqual(store.record()?.launchedVersion, "1.2.0")
        XCTAssertNil(store.record()?.presentedVersion)
        XCTAssertEqual(try store.launch("1.2.0"), .suppress)
    }

    func testUpdateShowsOnceAndASecondLaunchStaysQuietWithoutDismiss() throws {
        let store = WhatsNewStore(storage: InMemoryStorage())
        XCTAssertEqual(try store.launch("1.2.0"), .suppress)
        XCTAssertEqual(try store.launch("1.3.0"), .show)
        XCTAssertEqual(try store.launch("1.3.0"), .show, "a crash before the window appears can show it next time")
        try store.markAppeared(current: "1.3.0")
        XCTAssertEqual(store.record()?.presentedVersion, "1.3.0")
        XCTAssertEqual(try store.launch("1.3.0"), .suppress)
        XCTAssertEqual(try store.launch("1.4.0"), .show)
    }

    func testRouterShowsWhatsNewOnceAfterAnUpdateEvenIfItWasNotDismissed() {
        let router = AppRouter(whatsNewStorage: InMemoryStorage())
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }

        router.considerWhatsNew(version: "1.2.0", notes: notes, onboardingComplete: true)
        router.considerWhatsNew(version: "1.2.0", notes: notes, onboardingComplete: true)
        XCTAssertEqual(routes, [])

        router.considerWhatsNew(version: "1.3.0", notes: notes, onboardingComplete: true)
        XCTAssertEqual(routes, [.whatsNew])
        XCTAssertEqual(router.whatsNewPresentation?.version, "1.3.0")
        XCTAssertEqual(router.whatsNewPresentation?.notes, notes)
        router.whatsNewDidAppear()
        routes.removeAll()

        router.considerWhatsNew(version: "1.3.0", notes: notes, onboardingComplete: true)
        XCTAssertEqual(routes, [], "the second launch must stay quiet when the first one was not dismissed")

        router.showInstalledReleaseNotes()
        XCTAssertEqual(routes, [.whatsNew])
    }

    func testAFreshInstallDoesNotShowAndAnIncompleteSetupWaits() {
        let router = AppRouter(whatsNewStorage: InMemoryStorage())
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        router.considerWhatsNew(version: "1.2.0", notes: notes, onboardingComplete: false)
        router.considerWhatsNew(version: "1.3.0", notes: notes, onboardingComplete: false)
        XCTAssertEqual(routes, [])
        router.considerWhatsNew(version: "1.3.0", notes: notes, onboardingComplete: true)
        XCTAssertEqual(routes, [.whatsNew])
    }

    func testAnUpdateWithoutNotesDoesNotKeepAsking() {
        let router = AppRouter(whatsNewStorage: InMemoryStorage())
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        router.considerWhatsNew(version: "1.2.0", notes: nil, onboardingComplete: true)
        router.considerWhatsNew(version: "1.3.0", notes: "   ", onboardingComplete: true)
        router.considerWhatsNew(version: "1.3.0", notes: notes, onboardingComplete: true)
        XCTAssertEqual(routes, [])
    }
}
