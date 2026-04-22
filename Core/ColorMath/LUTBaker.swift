import Foundation

public enum LUTBaker {
    public static func bake(
        cdl: CDLValues,
        transferFunction: TransferFunction,
        size: Int = 33,
        title: String? = nil
    ) -> CubeLUT {
        precondition(size > 1, "Cube LUT size must be greater than 1.")

        let maxIndex = Float(size - 1)
        let valueCount = size * size * size
        var values: [SIMD3<Float>] = []
        values.reserveCapacity(valueCount)

        for blueIndex in 0 ..< size {
            let blue = Float(blueIndex) / maxIndex
            for greenIndex in 0 ..< size {
                let green = Float(greenIndex) / maxIndex
                for redIndex in 0 ..< size {
                    let red = Float(redIndex) / maxIndex
                    values.append(
                        cdl.applying(
                            to: SIMD3<Float>(red, green, blue),
                            transferFunction: transferFunction
                        )
                    )
                }
            }
        }

        return CubeLUT(
            title: title ?? defaultTitle(),
            size: size,
            values: values
        )
    }

    private static func defaultTitle() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "TrackGrade \(formatter.string(from: .now))"
    }
}
