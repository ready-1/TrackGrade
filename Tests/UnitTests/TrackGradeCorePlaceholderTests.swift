import XCTest
@testable import TrackGradeCore

final class TrackGradeCorePlaceholderTests: XCTestCase {
    func testCDLIdentityDefaults() {
        XCTAssertEqual(CDLValues(), .identity)
    }
}
