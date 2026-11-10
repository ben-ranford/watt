import XCTest

/// Deliberate scaffold, not a passing placeholder test or evidence of a story render.
final class F05StoryRenderTests: XCTestCase {
    /// Call only after fixture-aware app composition and story-specific entry assertions.
    /// Caller supplies app.windows[...] or app.statusItems[...], never a desktop screenshot.
    @MainActor
    func attachOwnedSurface(_ surface: XCUIElement, name: String) throws {
        guard surface.elementType == .window || surface.elementType == .statusItem else {
            XCTFail("Only app-owned windows/status items may be captured")
            return
        }
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        guard surface.exists else { return }
        let attachment = XCTAttachment(screenshot: surface.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testC01AppOwnedRender() throws {
        // Explicit opt-in only: normal native unit tests do not request AX/TCC access.
        guard ProcessInfo.processInfo.environment["WATT_C01_UI_TEST"] == "1" else {
            throw XCTSkip("C01 AX test requires an explicitly authorized graphical host")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--watt-fixture", "C01"]
        app.launch()
        defer { app.terminate() }
        let panel = app.windows["Watt C01 StatusPanel Capture"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.buttons["C01.settings"].exists)
        XCTAssertTrue(panel.buttons["C01.quit"].exists)
        try attachOwnedSurface(panel, name: "C01-21-928-dark-panel")
    }

    @MainActor
    func testJ41DesktopWelcomeNativeInteraction() throws {
        guard ProcessInfo.processInfo.environment["WATT_J41_UI_TEST"] == "1" else {
            throw XCTSkip("J4.1 live AX interaction requires an authorized graphical host")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--watt-fixture", "J4.1/base"]
        app.launch()
        defer { app.terminate() }
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Know your watts"].exists)
        XCTAssertTrue(window.staticTexts["Watt? sits in your menu bar and shows what your Mac draws. Nothing more."].exists)
        let button = window.buttons["onboarding.welcome.continue"]
        XCTAssertTrue(button.exists)
        try attachOwnedSurface(window, name: "J4.1-30-2275-dark-native")
        button.click()
        XCTAssertTrue(window.staticTexts["Pick one number for the menu bar"].waitForExistence(timeout: 5))
        window.buttons["onboarding.reading.back"].click()
        window.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(window.staticTexts["Pick one number for the menu bar"].waitForExistence(timeout: 5))
        window.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(window.staticTexts["Know your watts"].waitForExistence(timeout: 5))
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testJ42NoBatteryNativeInteraction() throws {
        guard ProcessInfo.processInfo.environment["WATT_J42_UI_TEST"] == "1" else {
            throw XCTSkip("J4.2 live AX interaction requires an authorized graphical host")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--watt-fixture", "J4.2/base"]
        app.launch()
        defer { app.terminate() }
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["No battery here, so it’s Draw or Components."].exists)
        XCTAssertEqual(window.radioButtons.count, 4)
        XCTAssertTrue(window.radioButtons.element(boundBy: 0).isEnabled)
        XCTAssertEqual(window.radioButtons.element(boundBy: 0).value as? String, "1")
        for index in 1...3 { XCTAssertFalse(window.radioButtons.element(boundBy: index).isEnabled) }
        try attachOwnedSurface(window, name: "J4.2-30-2576-dark-native")
        window.buttons["onboarding.reading.back"].click()
        XCTAssertTrue(window.staticTexts["Know your watts"].waitForExistence(timeout: 5))
        window.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(window.staticTexts["Pick one number for the menu bar"].waitForExistence(timeout: 5))
        window.buttons["onboarding.reading.continue"].click()
        XCTAssertTrue(window.staticTexts["See where the power goes"].waitForExistence(timeout: 5))
        window.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
    }

    func testStoryRenderingRequiresCompositionHookAndImplementedTarget() throws {
        throw XCTSkip("67 F05 stories remain unimplemented. C01 has an app-owned Debug render target and separate capture evidence; no placeholder asserts those other stories.")
    }
}
