import XCTest

@MainActor
final class TrackGradeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFixtureLaunchesIntoDynamicGradeSurface() throws {
        let app = launchFixtureApp()

        XCTAssertTrue(fixtureElement("dynamic-grade-card", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saturation"].exists)
        XCTAssertTrue(app.buttons["bypass-toggle"].exists)
        XCTAssertTrue(app.buttons["secondary-controls-button"].exists)
        XCTAssertTrue(app.buttons["device-sidebar-button"].exists)
    }

    func testDeviceSidebarCanBeOpenedAndClosedFromSurface() throws {
        let app = launchFixtureApp()

        openDeviceDrawer(in: app)
        XCTAssertTrue(fixtureElement("device-sidebar-drawer", in: app).waitForExistence(timeout: 5))

        dismissDeviceDrawer(in: app)
    }

    func testBypassToggleMutatesFixtureState() throws {
        let app = launchFixtureApp()
        let bypassToggle = app.buttons["bypass-toggle"]

        XCTAssertTrue(bypassToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bypassToggle.value as? String, "Off")

        bypassToggle.tap()

        XCTAssertEqual(bypassToggle.value as? String, "On")
    }

    func testBeforeAfterCompareRestoresFixtureBypassState() throws {
        let app = launchFixtureApp()
        let compareButton = app.buttons["before-after-button"]
        let bypassToggle = app.buttons["bypass-toggle"]

        XCTAssertTrue(compareButton.waitForExistence(timeout: 5))
        XCTAssertTrue(bypassToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bypassToggle.value as? String, "Off")

        compareButton.tap()
        XCTAssertEqual(bypassToggle.value as? String, "On")

        compareButton.tap()
        XCTAssertEqual(bypassToggle.value as? String, "Off")
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

    func testPreviewThumbnailTogglesFixturePreviewSource() throws {
        let app = launchFixtureApp()

        let previewSourceLabel = app.staticTexts["preview-source-label"]
        XCTAssertTrue(previewSourceLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(previewSourceLabel.label, "Output Preview")

        app.otherElements["grade-preview-thumbnail"].tap()

        XCTAssertEqual(previewSourceLabel.label, "Input Preview")
    }

    func testExpandedPreviewOverlayOpensFromPreviewControls() throws {
        let app = launchFixtureApp()

        let expandButton = app.buttons["expand-preview-button"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5))
        expandButton.tap()

        let overlayMarker = app.staticTexts["expanded-preview-visible"]
        let doneButton = app.buttons["expanded-preview-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        XCTAssertTrue(overlayMarker.exists)
        doneButton.tap()
        XCTAssertFalse(doneButton.waitForExistence(timeout: 1))
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

    func testPresetRecallShowsConfirmationBeforeApplying() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Presets", in: app)

        let recallButton = app.buttons["Recall"].firstMatch
        XCTAssertTrue(recallButton.waitForExistence(timeout: 5))
        recallButton.tap()

        let confirmButton = app.buttons["Recall Slot 4"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        XCTAssertFalse(confirmButton.waitForExistence(timeout: 1))
    }

    func testPresetRenameUpdatesFixturePresetName() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Presets", in: app)

        let presetTile = fixtureElement("preset-slot-4", in: app)
        XCTAssertTrue(presetTile.waitForExistence(timeout: 5))
        presetTile.press(forDuration: 1.1)
        app.buttons["Rename"].tap()

        let nameField = app.textFields["preset-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.replaceText(with: "Cue B")
        app.buttons["Rename"].tap()

        XCTAssertTrue(app.staticTexts["Cue B"].waitForExistence(timeout: 5))
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

        openDeviceDrawer(in: app)
        let gangBButton = app.buttons["Gang Fixture ColorBox B"]
        let gangCButton = app.buttons["Gang Fixture ColorBox C"]
        XCTAssertTrue(gangBButton.waitForExistence(timeout: 5))
        scrollToElement(gangCButton, in: app)
        XCTAssertTrue(gangCButton.waitForExistence(timeout: 5))

        gangBButton.tap()
        gangCButton.tap()

        dismissDeviceDrawerByTappingOutside(in: app)

        let bypassToggle = app.buttons["bypass-toggle"]
        XCTAssertTrue(bypassToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bypassToggle.value as? String, "Off")
        bypassToggle.tap()
        XCTAssertEqual(bypassToggle.value as? String, "On")

        openDeviceDrawer(in: app)
        let deviceBButton = app.buttons["Fixture ColorBox B"]
        scrollToElement(deviceBButton, in: app)
        deviceBButton.tap()
        XCTAssertEqual(bypassToggle.value as? String, "On")

        openDeviceDrawer(in: app)
        let deviceCButton = app.buttons["Fixture ColorBox C"]
        scrollToElement(deviceCButton, in: app)
        deviceCButton.tap()
        XCTAssertEqual(bypassToggle.value as? String, "On")
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
        XCTAssertTrue(fixtureElement("library-list", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(fixtureElement("library-management-note", in: app).exists)

        let threeDLUTSection = fixtureElement("library-section-threeDLUT", in: app)
        scrollToElement(threeDLUTSection, in: app)
        XCTAssertTrue(threeDLUTSection.waitForExistence(timeout: 5))
    }

    func testLibraryBrowserShowsImportButtonForEmptyFixtureSlot() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Workflow", in: app)

        let showLibraryButton = app.buttons["show-library-button"]
        XCTAssertTrue(showLibraryButton.waitForExistence(timeout: 5))
        showLibraryButton.tap()

        let importButton = fixtureElement("library-import-threeDLUT-3", in: app)
        scrollToElement(importButton, in: app)
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
    }

    func testDeletingFixtureLibraryEntryClearsTheSlot() throws {
        let app = launchFixtureApp()

        let controlsButton = app.buttons["secondary-controls-button"]
        XCTAssertTrue(controlsButton.waitForExistence(timeout: 5))
        controlsButton.tap()
        selectDrawerPanel(named: "Workflow", in: app)

        let showLibraryButton = app.buttons["show-library-button"]
        XCTAssertTrue(showLibraryButton.waitForExistence(timeout: 5))
        showLibraryButton.tap()

        let actionsButton = fixtureElement("library-actions-threeDLUT-1", in: app)
        scrollToElement(actionsButton, in: app)
        XCTAssertTrue(actionsButton.waitForExistence(timeout: 5))
        actionsButton.tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete"].tap()

        let importButton = fixtureElement("library-import-threeDLUT-1", in: app)
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
    }

    func testFixtureControlSurfacePassesAccessibilityAudit() throws {
        let app = launchFixtureApp()

        XCTAssertTrue(fixtureElement("dynamic-grade-card", in: app).waitForExistence(timeout: 5))

        if #available(iOS 17.0, *) {
            var recordedIssues: [String] = []
            try app.performAccessibilityAudit(for: .hitRegion) { issue in
                let elementDescription = issue.element?.debugDescription ?? "No element"
                let message = [
                    issue.compactDescription,
                    issue.detailedDescription,
                    elementDescription,
                ].joined(separator: " | ")
                print("Accessibility audit issue: \(message)")
                recordedIssues.append(message)
                return true
            }
            XCTAssertTrue(recordedIssues.isEmpty, recordedIssues.joined(separator: "\n\n"))
        }
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
        maximumSwipes: Int = 10
    ) {
        guard element.exists == false else {
            return
        }

        let deviceSidebarList = fixtureElement("device-sidebar-list", in: app)
        let identifiedList = fixtureElement("library-list", in: app)
        let tables = app.tables.allElementsBoundByIndex
        let preferredTable = tables.last ?? app.tables.firstMatch
        let collectionViews = app.collectionViews.allElementsBoundByIndex
        let preferredCollectionView = collectionViews.last ?? app.collectionViews.firstMatch
        let scrollContainer: XCUIElement
        if deviceSidebarList.exists {
            scrollContainer = deviceSidebarList
        } else if identifiedList.exists {
            scrollContainer = identifiedList
        } else if preferredTable.exists {
            scrollContainer = preferredTable
        } else {
            scrollContainer = preferredCollectionView
        }

        guard scrollContainer.exists else {
            return
        }

        for _ in 0..<maximumSwipes where element.exists == false {
            scrollContainer.swipeUp()
        }
    }

    private func openDeviceDrawer(in app: XCUIApplication) {
        let button = app.buttons["device-sidebar-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))

        if fixtureElement("device-sidebar-drawer", in: app).exists == false {
            button.tap()
        }
    }

    private func dismissDeviceDrawer(in app: XCUIApplication) {
        let closeButton = app.buttons["device-sidebar-close-button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        XCTAssertFalse(closeButton.waitForExistence(timeout: 1))
    }

    private func dismissDeviceDrawerByTappingOutside(in app: XCUIApplication) {
        let outsideCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        outsideCoordinate.tap()
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
