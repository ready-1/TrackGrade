import Foundation

public enum TransferFunction: String, CaseIterable, Sendable {
    case rec709SDR
    case rec709HLG

    public var displayName: String {
        switch self {
        case .rec709SDR:
            return "Rec.709 SDR"
        case .rec709HLG:
            return "Rec.709 HLG"
        }
    }

    public func toLinear(
        _ encodedValue: Float
    ) -> Float {
        let value = encodedValue.clamped(to: 0 ... 1)

        switch self {
        case .rec709SDR:
            return Foundation.pow(value, 2.4)
        case .rec709HLG:
            if value <= 0.5 {
                return (value * value) / 3
            }

            let a: Float = 0.17883277
            let b: Float = 1 - (4 * a)
            let c: Float = 0.5 - (a * Foundation.log(4 * a))
            return (Foundation.exp((value - c) / a) + b) / 12
        }
    }

    public func fromLinear(
        _ linearValue: Float
    ) -> Float {
        let value = linearValue.clamped(to: 0 ... 1)

        switch self {
        case .rec709SDR:
            return Foundation.pow(value, 1 / 2.4)
        case .rec709HLG:
            if value <= (1 / 12) {
                return Foundation.sqrt(3 * value)
            }

            let a: Float = 0.17883277
            let b: Float = 1 - (4 * a)
            let c: Float = 0.5 - (a * Foundation.log(4 * a))
            return (a * Foundation.log((12 * value) - b)) + c
        }
    }
}

private extension Float {
    func clamped(
        to range: ClosedRange<Float>
    ) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
