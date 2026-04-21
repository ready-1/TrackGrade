import Foundation

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
}
