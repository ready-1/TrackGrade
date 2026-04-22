import XCTest
import simd
@testable import TrackGradeCore

final class ColorMathTests: XCTestCase {
    func testTransferFunctionsRoundTripAcrossSampleRamp() {
        for transferFunction in TransferFunction.allCases {
            for index in 0 ... 1024 {
                let value = Float(index) / 1024
                let linear = transferFunction.toLinear(value)
                let rebuilt = transferFunction.fromLinear(linear)
                XCTAssertEqual(
                    rebuilt,
                    value,
                    accuracy: 0.00001,
                    "\(transferFunction.rawValue) failed at sample \(index)"
                )
            }
        }
    }

    func testTransferFunctionsClampValuesOutsideUnitInterval() {
        for transferFunction in TransferFunction.allCases {
            XCTAssertEqual(transferFunction.toLinear(-0.5), 0, accuracy: 0.000001)
            XCTAssertEqual(transferFunction.fromLinear(-0.5), 0, accuracy: 0.000001)
            XCTAssertEqual(transferFunction.toLinear(1.5), 1, accuracy: 0.000001)
            XCTAssertEqual(transferFunction.fromLinear(1.5), 1, accuracy: 0.000001)
        }
    }

    func testCDLIdentityPreservesLinearSamples() {
        let input = SIMD3<Float>(0.18, 0.42, 0.73)
        let output = CDLValues.identity.applyingToLinearRGB(input)
        XCTAssertEqual(output.x, input.x, accuracy: 0.000001)
        XCTAssertEqual(output.y, input.y, accuracy: 0.000001)
        XCTAssertEqual(output.z, input.z, accuracy: 0.000001)
    }

    func testCDLApplyingUsesTransferFunctionRoundTrip() {
        let cdl = CDLValues(
            slope: SIMD3<Float>(1.05, 0.95, 1.1),
            offset: SIMD3<Float>(0.01, -0.01, 0.02),
            power: SIMD3<Float>(1.25, 0.9, 1.1),
            saturation: 1.2
        )
        let encoded = SIMD3<Float>(0.22, 0.47, 0.81)

        let expected = SIMD3<Float>(
            TransferFunction.rec709HLG.fromLinear(
                cdl.applyingToLinearRGB(
                    SIMD3<Float>(
                        TransferFunction.rec709HLG.toLinear(encoded.x),
                        TransferFunction.rec709HLG.toLinear(encoded.y),
                        TransferFunction.rec709HLG.toLinear(encoded.z)
                    )
                ).x
            ),
            TransferFunction.rec709HLG.fromLinear(
                cdl.applyingToLinearRGB(
                    SIMD3<Float>(
                        TransferFunction.rec709HLG.toLinear(encoded.x),
                        TransferFunction.rec709HLG.toLinear(encoded.y),
                        TransferFunction.rec709HLG.toLinear(encoded.z)
                    )
                ).y
            ),
            TransferFunction.rec709HLG.fromLinear(
                cdl.applyingToLinearRGB(
                    SIMD3<Float>(
                        TransferFunction.rec709HLG.toLinear(encoded.x),
                        TransferFunction.rec709HLG.toLinear(encoded.y),
                        TransferFunction.rec709HLG.toLinear(encoded.z)
                    )
                ).z
            )
        )
        let actual = cdl.applying(
            to: encoded,
            transferFunction: .rec709HLG
        )

        XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.000001)
        XCTAssertEqual(actual.z, expected.z, accuracy: 0.000001)
    }

    func testCDLAppliesInversePowerAndSaturationInLinearDomain() {
        let cdl = CDLValues(
            slope: SIMD3<Float>(1.2, 1.1, 0.95),
            offset: SIMD3<Float>(0.05, -0.02, 0.03),
            power: SIMD3<Float>(2.0, 1.0, 0.5),
            saturation: 0.8
        )
        let input = SIMD3<Float>(0.25, 0.5, 0.75)

        let graded = simd_clamp((input * cdl.slope) + cdl.offset, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
        let powered = SIMD3<Float>(
            Foundation.pow(graded.x, 1 / 2.0),
            Foundation.pow(graded.y, 1 / 1.0),
            Foundation.pow(graded.z, 1 / 0.5)
        )
        let luma = simd_dot(powered, CDLValues.rec709LumaWeights)
        let expected = simd_clamp(
            SIMD3<Float>(
                luma + (0.8 * (powered.x - luma)),
                luma + (0.8 * (powered.y - luma)),
                luma + (0.8 * (powered.z - luma))
            ),
            SIMD3<Float>(repeating: 0),
            SIMD3<Float>(repeating: 1)
        )

        let actual = cdl.applyingToLinearRGB(input)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.000001)
        XCTAssertEqual(actual.z, expected.z, accuracy: 0.000001)
    }

    func testCDLClampsPowerAndSaturationBoundaries() {
        let cdl = CDLValues(
            slope: SIMD3<Float>(repeating: 1),
            offset: SIMD3<Float>(repeating: 0),
            power: SIMD3<Float>(0.01, 6.0, 1.5),
            saturation: 3.0
        )

        XCTAssertEqual(cdl.clampedPower.x, 0.2, accuracy: 0.000001)
        XCTAssertEqual(cdl.clampedPower.y, 5.0, accuracy: 0.000001)
        XCTAssertEqual(cdl.clampedPower.z, 1.5, accuracy: 0.000001)
        XCTAssertEqual(cdl.clampedSaturation, 2.0, accuracy: 0.000001)
    }

    func testControlStateClampedBallNormalizesValuesOutsideUnitDisk() {
        let state = CDLControlState(
            ball: SIMD2<Float>(3, 4),
            ring: 0
        )

        XCTAssertEqual(state.clampedBall.x, 0.6, accuracy: 0.000001)
        XCTAssertEqual(state.clampedBall.y, 0.8, accuracy: 0.000001)
    }

    func testGradeStateNeutralMapsToIdentityCDL() {
        let cdl = GradeState().toCDL()
        XCTAssertEqual(cdl, .identity)
    }

    func testGradeStateMapsLiftGammaGainRangesIntoCDL() {
        let state = GradeState(
            lift: CDLControlState(
                ball: SIMD2<Float>(0.6, -0.2),
                ring: 0.5
            ),
            gamma: CDLControlState(
                ball: SIMD2<Float>(-0.35, 0.45),
                ring: -0.3
            ),
            gain: CDLControlState(
                ball: SIMD2<Float>(0.25, 0.4),
                ring: 0.7
            ),
            saturation: 1.3
        )

        let cdl = state.toCDL()
        XCTAssertTrue((0.0 ... 4.0).contains(cdl.slope.x))
        XCTAssertTrue((0.0 ... 4.0).contains(cdl.slope.y))
        XCTAssertTrue((0.0 ... 4.0).contains(cdl.slope.z))
        XCTAssertTrue((0.2 ... 5.0).contains(cdl.power.x))
        XCTAssertTrue((0.2 ... 5.0).contains(cdl.power.y))
        XCTAssertTrue((0.2 ... 5.0).contains(cdl.power.z))
        XCTAssertTrue((-0.2 ... 0.2).contains(cdl.offset.x))
        XCTAssertTrue((-0.2 ... 0.2).contains(cdl.offset.y))
        XCTAssertTrue((-0.2 ... 0.2).contains(cdl.offset.z))
        XCTAssertEqual(cdl.saturation, 1.3, accuracy: 0.000001)
    }

    func testGradeStateInitializesFromGradeControlAndUsesExtensionHelpers() {
        let gradeControl = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: 0.18, green: -0.06, blue: -0.12),
            gamma: ColorBoxRGBVector(red: 0.12, green: -0.08, blue: -0.04),
            gain: ColorBoxRGBVector(red: 1.4, green: 1.1, blue: 0.9),
            saturation: 1.4
        )

        let state = GradeState(gradeControl: gradeControl)
        XCTAssertEqual(state.saturation, 1.4, accuracy: 0.000001)

        let directCDL = state.toCDL()
        let extensionCDL = gradeControl.toCDL()
        XCTAssertEqual(extensionCDL, directCDL)

        let baked = gradeControl.bakeLUT(
            transferFunction: .rec709SDR,
            size: 3
        )
        XCTAssertEqual(baked.size, 3)
        XCTAssertEqual(baked.entryCount, 27)
    }

    func testCubeLUTSerializationParsesBackSymmetrically() throws {
        let cube = LUTBaker.bake(
            cdl: CDLValues(
                slope: SIMD3<Float>(1.1, 0.95, 1.05),
                offset: SIMD3<Float>(0.01, -0.02, 0.03),
                power: SIMD3<Float>(0.9, 1.2, 1.1),
                saturation: 1.15
            ),
            transferFunction: .rec709SDR,
            size: 5,
            title: "RoundTrip"
        )

        let parsed = try CubeLUT.parse(cube.serialize())
        XCTAssertEqual(parsed.title, cube.title)
        XCTAssertEqual(parsed.size, cube.size)
        XCTAssertEqual(parsed.serialize(), cube.serialize())
    }

    func testCubeLUTDynamicColorBoxPayloadUsesExpectedHeaderAndQuantization() {
        let cube = CubeLUT(
            title: "Payload",
            size: 2,
            values: [
                SIMD3<Float>(0, 0.5, 1),
                SIMD3<Float>(0.25, 0.75, 1),
                SIMD3<Float>(1, 0.5, 0.25),
                SIMD3<Float>(0.125, 0.625, 0.875),
                SIMD3<Float>(0.9, 0.1, 0.2),
                SIMD3<Float>(0.3, 0.4, 0.5),
                SIMD3<Float>(0.6, 0.7, 0.8),
                SIMD3<Float>(1, 1, 1),
            ]
        )

        let payload = cube.dynamicColorBoxPayload()
        XCTAssertEqual(String(decoding: payload.prefix(4), as: UTF8.self), "3DL1")
        XCTAssertEqual(payload.count, 4 + (cube.entryCount * 6))

        let firstRed = payload.dropFirst(4).prefix(2)
        let firstGreen = payload.dropFirst(6).prefix(2)
        let firstBlue = payload.dropFirst(8).prefix(2)
        XCTAssertEqual(firstRed.map { $0 }, [0x00, 0x00])
        XCTAssertEqual(firstGreen.map { $0 }, [0x00, 0x80])
        XCTAssertEqual(firstBlue.map { $0 }, [0xFF, 0xFF])
    }

    func testCubeLUTParseRejectsMissingSize() {
        XCTAssertThrowsError(
            try CubeLUT.parse(
                """
                TITLE "Broken"
                0.000000 0.000000 0.000000
                """
            )
        ) { error in
            XCTAssertEqual(error as? CubeLUTParseError, .missingSize)
        }
    }

    func testCubeLUTParseRejectsInvalidHeadersAndValues() {
        XCTAssertThrowsError(
            try CubeLUT.parse(
                """
                TITLE "Broken"
                LUT_3D_SIZE nope
                """
            )
        ) { error in
            XCTAssertEqual(error as? CubeLUTParseError, .invalidHeader("LUT_3D_SIZE nope"))
        }

        XCTAssertThrowsError(
            try CubeLUT.parse(
                """
                TITLE "Broken"
                LUT_3D_SIZE 2
                DOMAIN_MIN 0.0 0.0
                """
            )
        ) { error in
            XCTAssertEqual(error as? CubeLUTParseError, .invalidHeader("DOMAIN_MIN 0.0 0.0"))
        }

        XCTAssertThrowsError(
            try CubeLUT.parse(
                """
                TITLE "Broken"
                LUT_3D_SIZE 2
                DOMAIN_MIN 0.0 0.0 0.0
                DOMAIN_MAX 1.0 1.0 1.0
                invalid row
                """
            )
        ) { error in
            XCTAssertEqual(error as? CubeLUTParseError, .invalidValueLine("invalid row"))
        }

        XCTAssertThrowsError(
            try CubeLUT.parse(
                """
                TITLE "Broken"
                LUT_3D_SIZE 2
                DOMAIN_MIN 0.0 0.0 0.0
                DOMAIN_MAX 1.0 1.0 1.0
                0.0 0.0 0.0
                """
            )
        ) { error in
            XCTAssertEqual(
                error as? CubeLUTParseError,
                .unexpectedEntryCount(expected: 8, actual: 1)
            )
        }
    }

    func testLUTBakerIdentityBakePreservesCubeCorners() throws {
        let cube = LUTBaker.bake(
            cdl: .identity,
            transferFunction: .rec709SDR,
            size: 3,
            title: "Identity"
        )
        let first = try XCTUnwrap(cube.values.first)
        let last = try XCTUnwrap(cube.values.last)

        XCTAssertEqual(cube.entryCount, 27)
        XCTAssertEqual(first.x, 0, accuracy: 0.000001)
        XCTAssertEqual(first.y, 0, accuracy: 0.000001)
        XCTAssertEqual(first.z, 0, accuracy: 0.000001)
        XCTAssertEqual(last.x, 1, accuracy: 0.000001)
        XCTAssertEqual(last.y, 1, accuracy: 0.000001)
        XCTAssertEqual(last.z, 1, accuracy: 0.000001)

        let rebuilt = try CubeLUT.parse(cube.serialize())
        XCTAssertEqual(rebuilt.values[13], cube.values[13])
    }

    func testLUTBakerUsesTimestampTitleWhenOmitted() {
        let cube = LUTBaker.bake(
            cdl: .identity,
            transferFunction: .rec709SDR,
            size: 2
        )

        XCTAssertTrue(cube.title.hasPrefix("TrackGrade "))
        XCTAssertFalse(cube.title.isEmpty)
    }
}
