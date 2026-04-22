import XCTest
@testable import TrackGradeCore

final class LUTBakerPerformanceTests: XCTestCase {
    func testReleaseBakeCompletesUnderSixteenMilliseconds() throws {
#if DEBUG
        throw XCTSkip("Bake timing threshold is validated with `swift test -c release`.")
#else
        let start = ContinuousClock.now
        _ = LUTBaker.bake(
            cdl: .identity,
            transferFunction: .rec709SDR,
            size: 33,
            title: "Benchmark"
        )
        let elapsed = ContinuousClock.now - start
        XCTAssertLessThan(elapsed, .milliseconds(16))
#endif
    }
}
