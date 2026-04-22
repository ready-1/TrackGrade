import Foundation
import simd

public struct CDLValues: Equatable, Sendable {
    public var slope: SIMD3<Float>
    public var offset: SIMD3<Float>
    public var power: SIMD3<Float>
    public var saturation: Float

    public static let identity = CDLValues(
        slope: SIMD3<Float>(repeating: 1),
        offset: SIMD3<Float>(repeating: 0),
        power: SIMD3<Float>(repeating: 1),
        saturation: 1
    )

    public init(
        slope: SIMD3<Float> = SIMD3<Float>(repeating: 1),
        offset: SIMD3<Float> = SIMD3<Float>(repeating: 0),
        power: SIMD3<Float> = SIMD3<Float>(repeating: 1),
        saturation: Float = 1
    ) {
        self.slope = slope
        self.offset = offset
        self.power = power
        self.saturation = saturation
    }

    public func applying(
        to encodedRGB: SIMD3<Float>,
        transferFunction: TransferFunction
    ) -> SIMD3<Float> {
        let linearRGB = SIMD3<Float>(
            transferFunction.toLinear(encodedRGB.x),
            transferFunction.toLinear(encodedRGB.y),
            transferFunction.toLinear(encodedRGB.z)
        )

        let gradedLinearRGB = applyingToLinearRGB(linearRGB)
        return SIMD3<Float>(
            transferFunction.fromLinear(gradedLinearRGB.x),
            transferFunction.fromLinear(gradedLinearRGB.y),
            transferFunction.fromLinear(gradedLinearRGB.z)
        )
    }

    public func applyingToLinearRGB(
        _ linearRGB: SIMD3<Float>
    ) -> SIMD3<Float> {
        let graded = simd_clamp((linearRGB * slope) + offset, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
        let exponent = SIMD3<Float>(
            1 / clampedPower.x,
            1 / clampedPower.y,
            1 / clampedPower.z
        )
        let powered = SIMD3<Float>(
            Foundation.pow(graded.x, exponent.x),
            Foundation.pow(graded.y, exponent.y),
            Foundation.pow(graded.z, exponent.z)
        )

        let luma = simd_dot(powered, Self.rec709LumaWeights)
        let saturated = SIMD3<Float>(
            luma + (clampedSaturation * (powered.x - luma)),
            luma + (clampedSaturation * (powered.y - luma)),
            luma + (clampedSaturation * (powered.z - luma))
        )
        return simd_clamp(saturated, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
    }

    public var clampedPower: SIMD3<Float> {
        simd_clamp(power, SIMD3<Float>(repeating: 0.2), SIMD3<Float>(repeating: 5))
    }

    public var clampedSaturation: Float {
        saturation.clamped(to: 0 ... 2)
    }

    public static let rec709LumaWeights = SIMD3<Float>(
        0.2126,
        0.7152,
        0.0722
    )
}

public struct CDLControlState: Equatable, Sendable {
    public var ball: SIMD2<Float>
    public var ring: Float

    public static let zero = CDLControlState(
        ball: SIMD2<Float>(repeating: 0),
        ring: 0
    )

    public init(
        ball: SIMD2<Float> = SIMD2<Float>(repeating: 0),
        ring: Float = 0
    ) {
        self.ball = ball
        self.ring = ring
    }

    public var clampedBall: SIMD2<Float> {
        let magnitude = simd_length(ball)
        guard magnitude > 1, magnitude > 0 else {
            return ball
        }

        return ball / magnitude
    }
}

public struct GradeState: Equatable, Sendable {
    public var lift: CDLControlState
    public var gamma: CDLControlState
    public var gain: CDLControlState
    public var saturation: Float

    public init(
        lift: CDLControlState = .zero,
        gamma: CDLControlState = .zero,
        gain: CDLControlState = .zero,
        saturation: Float = 1
    ) {
        self.lift = lift
        self.gamma = gamma
        self.gain = gain
        self.saturation = saturation
    }

    public init(
        gradeControl: ColorBoxGradeControlState
    ) {
        let liftState = ColorBoxTrackballMapping.state(for: gradeControl.lift, kind: .lift)
        let gammaState = ColorBoxTrackballMapping.state(for: gradeControl.gamma, kind: .gamma)
        let gainState = ColorBoxTrackballMapping.state(for: gradeControl.gain, kind: .gain)

        self.init(
            lift: CDLControlState(ball: SIMD2<Float>(liftState.ball.x, liftState.ball.y), ring: liftState.ring),
            gamma: CDLControlState(ball: SIMD2<Float>(gammaState.ball.x, gammaState.ball.y), ring: gammaState.ring),
            gain: CDLControlState(ball: SIMD2<Float>(gainState.ball.x, gainState.ball.y), ring: gainState.ring),
            saturation: gradeControl.saturation
        )
    }

    public func toCDL() -> CDLValues {
        let liftOffset = mappedOffset(from: lift)
        let gammaPower = mappedPower(from: gamma)
        let gainSlope = mappedSlope(from: gain)

        return CDLValues(
            slope: gainSlope,
            offset: liftOffset,
            power: gammaPower,
            saturation: saturation.clamped(to: 0 ... 2)
        )
    }

    public func bakeLUT(
        transferFunction: TransferFunction,
        size: Int = 33
    ) -> CubeLUT {
        LUTBaker.bake(
            cdl: toCDL(),
            transferFunction: transferFunction,
            size: size
        )
    }

    private func mappedOffset(
        from control: CDLControlState
    ) -> SIMD3<Float> {
        let baseLift = control.ring.clamped(to: -1 ... 1) * 0.2
        return simd_clamp(
            SIMD3<Float>(repeating: baseLift) + chromaVector(for: control.clampedBall, scale: 0.1),
            SIMD3<Float>(repeating: -0.2),
            SIMD3<Float>(repeating: 0.2)
        )
    }

    private func mappedPower(
        from control: CDLControlState
    ) -> SIMD3<Float> {
        let normalized = (control.ring.clamped(to: -1 ... 1) + 1) / 2
        let basePower = 0.2 * Foundation.pow(25, normalized)
        return simd_clamp(
            SIMD3<Float>(repeating: basePower) + chromaVector(for: control.clampedBall, scale: 0.2),
            SIMD3<Float>(repeating: 0.2),
            SIMD3<Float>(repeating: 5)
        )
    }

    private func mappedSlope(
        from control: CDLControlState
    ) -> SIMD3<Float> {
        let ring = control.ring.clamped(to: -1 ... 1)
        let baseSlope: Float
        if ring >= 0 {
            baseSlope = 1 + (ring * 3)
        } else {
            baseSlope = 1 + ring
        }

        return simd_clamp(
            SIMD3<Float>(repeating: baseSlope) + chromaVector(for: control.clampedBall, scale: 0.2),
            SIMD3<Float>(repeating: 0),
            SIMD3<Float>(repeating: 4)
        )
    }

    private func chromaVector(
        for point: SIMD2<Float>,
        scale: Float
    ) -> SIMD3<Float> {
        let angle = atan2(point.y, point.x)
        let magnitude = min(simd_length(point), 1)
        let greenRotation: Float = .pi * (2 / 3)
        let blueRotation: Float = .pi * (4 / 3)

        return SIMD3<Float>(
            magnitude * scale * cos(angle),
            magnitude * scale * cos(angle - greenRotation),
            magnitude * scale * cos(angle - blueRotation)
        )
    }
}

public extension ColorBoxGradeControlState {
    var gradeState: GradeState {
        GradeState(gradeControl: self)
    }

    func toCDL() -> CDLValues {
        gradeState.toCDL()
    }

    func bakeLUT(
        transferFunction: TransferFunction,
        size: Int = 33
    ) -> CubeLUT {
        gradeState.bakeLUT(
            transferFunction: transferFunction,
            size: size
        )
    }
}

private extension Float {
    func clamped(
        to range: ClosedRange<Float>
    ) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
