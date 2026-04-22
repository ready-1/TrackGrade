import XCTest

@MainActor
final class TrackGradeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFixtureLaunchesIntoDynamicGradeSurface() throws {
        let app = launchFixtureApp()

        XCTAssertTrue(fixtureElement("dynamic-grade-card", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Control Surface"].exists)
        XCTAssertTrue(app.staticTexts["Saturation"].exists)
        XCTAssertTrue(app.switches["bypass-toggle"].exists)
        XCTAssertTrue(app.buttons["secondary-controls-button"].exists)
    }

    func testBypassToggleMutatesFixtureState() throws {
        let app = launchFixtureApp()
        let bypassToggle = app.switches["bypass-toggle"]

        XCTAssertTrue(bypassToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bypassToggle.value as? String, "0")

        bypassToggle.tap()

        XCTAssertEqual(bypassToggle.value as? String, "1")
    }

    func testSettingsSheetLaunchesFromSurface() throws {
        let app = launchFixtureApp()

        let settingsButton = app.buttons["grade-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testSavingPresetAddsFixturePresetCard() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()

        let savePresetButton = app.buttons["save-preset-button"]
        XCTAssertTrue(savePresetButton.waitForExistence(timeout: 5))
        savePresetButton.tap()

        let nameField = app.textFields["preset-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.replaceText(with: "Offline Save")
        app.buttons["Save"].tap()

        XCTAssertTrue(fixtureElement("preset-slot-1", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Offline Save"].exists)
    }

    private func launchFixtureApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-fixture")
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        return app
    }

    private func fixtureElement(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }
}

private extension XCUIElement {
    func replaceText(with text: String) {
        tap()

        if let currentValue = value as? String,
           currentValue.isEmpty == false {
            let deleteSequence = String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: currentValue.count
            )
            typeText(deleteSequence)
        }

        typeText(text)
    }
}
