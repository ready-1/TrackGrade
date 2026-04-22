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

    func testBeforeAfterCompareRestoresFixtureBypassState() throws {
        let app = launchFixtureApp()
        let compareButton = app.buttons["before-after-button"]
        let bypassToggle = app.switches["bypass-toggle"]

        XCTAssertTrue(compareButton.waitForExistence(timeout: 5))
        XCTAssertTrue(bypassToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bypassToggle.value as? String, "0")

        compareButton.tap()
        XCTAssertEqual(bypassToggle.value as? String, "1")

        compareButton.tap()
        XCTAssertEqual(bypassToggle.value as? String, "0")
    }

    func testSettingsSheetLaunchesFromSurface() throws {
        let app = launchFixtureApp()

        let settingsButton = app.buttons["grade-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let colorSpaceControl = app.segmentedControls["working-color-space-picker"]
        XCTAssertTrue(colorSpaceControl.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Rec.709 SDR"].exists)
        XCTAssertTrue(app.buttons["Rec.709 HLG"].exists)
        app.buttons["Rec.709 HLG"].tap()
    }

    func testSavingPresetAddsFixturePresetCard() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Presets", in: app)

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

    func testSnapshotRecallAppliesStoredSnapshotGrade() throws {
        let app = launchFixtureApp()
        let gradeStateDisplay = fixtureElement("dynamic-grade-card", in: app)

        XCTAssertTrue(gradeStateDisplay.waitForExistence(timeout: 5))
        let initialValue = gradeStateDisplay.value as? String

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Workflow", in: app)

        let showSnapshotsButton = app.buttons["show-snapshots-button"]
        XCTAssertTrue(showSnapshotsButton.waitForExistence(timeout: 5))
        showSnapshotsButton.tap()

        XCTAssertTrue(app.navigationBars["Snapshots"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Lobby Warm-Up"].exists)
        app.buttons["Recall"].firstMatch.tap()

        XCTAssertTrue(gradeStateDisplay.waitForExistence(timeout: 5))
        let valueChanged = NSPredicate(format: "value != %@", initialValue ?? "")
        let expectation = XCTNSPredicateExpectation(predicate: valueChanged, object: gradeStateDisplay)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertNotEqual(gradeStateDisplay.value as? String, initialValue)
    }

    func testSavingSnapshotAddsAnotherSnapshotEntry() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Workflow", in: app)

        let saveSnapshotButton = app.buttons["save-snapshot-button"]
        XCTAssertTrue(saveSnapshotButton.waitForExistence(timeout: 5))
        saveSnapshotButton.tap()

        let showSnapshotsButton = app.buttons["show-snapshots-button"]
        XCTAssertTrue(showSnapshotsButton.waitForExistence(timeout: 5))
        showSnapshotsButton.tap()

        XCTAssertTrue(app.navigationBars["Snapshots"].waitForExistence(timeout: 5))
        let recallButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Recall"))
        let countExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count >= 2"),
            object: recallButtons
        )
        XCTAssertEqual(XCTWaiter().wait(for: [countExpectation], timeout: 5), .completed)
        XCTAssertGreaterThanOrEqual(recallButtons.count, 2)
    }

    func testGangBroadcastsBypassToLinkedPeers() throws {
        let app = launchFixtureApp()

        let gangBButton = app.buttons["Gang Fixture ColorBox B"]
        let gangCButton = app.buttons["Gang Fixture ColorBox C"]
        XCTAssertTrue(gangBButton.waitForExistence(timeout: 5))
        XCTAssertTrue(gangCButton.waitForExistence(timeout: 5))

        gangBButton.tap()
        gangCButton.tap()

        let bypassToggle = app.switches["bypass-toggle"]
        XCTAssertTrue(bypassToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bypassToggle.value as? String, "0")
        bypassToggle.tap()
        XCTAssertEqual(bypassToggle.value as? String, "1")

        app.staticTexts["Fixture ColorBox B"].tap()
        XCTAssertEqual(bypassToggle.value as? String, "1")

        app.staticTexts["Fixture ColorBox C"].tap()
        XCTAssertEqual(bypassToggle.value as? String, "1")
    }

    func testLibraryBrowserShowsFixtureSections() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Workflow", in: app)

        let showLibraryButton = app.buttons["show-library-button"]
        XCTAssertTrue(showLibraryButton.waitForExistence(timeout: 5))
        showLibraryButton.tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3D LUT"].exists)
        XCTAssertTrue(app.staticTexts["Stage Neutral"].waitForExistence(timeout: 5))

        let overlayEntry = app.staticTexts["Lower Third"]
        scrollToElement(overlayEntry, in: app)
        XCTAssertTrue(overlayEntry.waitForExistence(timeout: 5))
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

    private func selectDrawerPanel(
        named title: String,
        in app: XCUIApplication
    ) {
        let panelButton = app.buttons[title]
        XCTAssertTrue(panelButton.waitForExistence(timeout: 5))
        panelButton.tap()
    }

    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 4
    ) {
        guard element.exists == false else {
            return
        }

        let libraryList = app.tables["library-list"].firstMatch
        let scrollContainer = libraryList.exists ? libraryList : app.collectionViews.firstMatch

        guard scrollContainer.exists else {
            return
        }

        for _ in 0..<maximumSwipes where element.exists == false {
            scrollContainer.swipeUp()
        }
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
