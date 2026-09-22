import XCTest

@MainActor
final class NativeHostTests: XCTestCase {
    func testMenuBarPanelCapture() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), app.debugDescription)
        statusItem.click()
        XCTAssertTrue(app.buttons["Quit Watt?"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.buttons["Settings…"].exists)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "native-shell-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "native-shell-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
