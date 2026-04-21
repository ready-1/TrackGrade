import XCTest
@testable import TrackGradeCore

final class TrackGradeCorePlaceholderTests: XCTestCase {
    func testCDLIdentityDefaults() {
        XCTAssertEqual(CDLValues(), .identity)
    }

    func testTrackballMappingRoundTripsRepresentativeControlStates() {
        assertStateRoundTrip(
            state: ColorBoxTrackballState(
                ball: ColorBoxControlPoint(x: 0.42, y: -0.31),
                ring: 0.44
            ),
            kind: .lift
        )
        assertStateRoundTrip(
            state: ColorBoxTrackballState(
                ball: ColorBoxControlPoint(x: -0.27, y: 0.51),
                ring: -0.18
            ),
            kind: .gamma
        )
        assertStateRoundTrip(
            state: ColorBoxTrackballState(
                ball: ColorBoxControlPoint(x: 0.33, y: 0.22),
                ring: 0.19
            ),
            kind: .gain
        )
    }

    func testTrackballMappingPreservesIdentityVectors() {
        XCTAssertEqual(
            ColorBoxTrackballMapping.state(
                for: ColorBoxGradeControlState.identity.lift,
                kind: .lift
            ),
            .zero
        )
        XCTAssertEqual(
            ColorBoxTrackballMapping.state(
                for: ColorBoxGradeControlState.identity.gamma,
                kind: .gamma
            ),
            .zero
        )
        XCTAssertEqual(
            ColorBoxTrackballMapping.state(
                for: ColorBoxGradeControlState.identity.gain,
                kind: .gain
            ),
            .zero
        )
    }

    func testTrackballMappingClampsBallToUnitDisk() {
        let unclamped = ColorBoxTrackballState(
            ball: ColorBoxControlPoint(x: 3, y: 4),
            ring: 0
        )

        let liftVector = ColorBoxTrackballMapping.vector(for: unclamped, kind: .lift)
        let recovered = ColorBoxTrackballMapping.state(for: liftVector, kind: .lift)

        XCTAssertLessThanOrEqual(recovered.ball.magnitude, 1.0001)
    }

    private func assertStateRoundTrip(
        state: ColorBoxTrackballState,
        kind: ColorBoxTrackballKind,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let vector = ColorBoxTrackballMapping.vector(for: state, kind: kind)
        let rebuiltState = ColorBoxTrackballMapping.state(for: vector, kind: kind)

        XCTAssertEqual(rebuiltState.ball.x, state.ball.x, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(rebuiltState.ball.y, state.ball.y, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(rebuiltState.ring, state.ring, accuracy: 0.0001, file: file, line: line)
    }
}
