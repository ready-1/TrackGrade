import XCTest

final class TrackGradeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesTrackGradeApp() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["TrackGrade"].waitForExistence(timeout: 5))
    }
}
