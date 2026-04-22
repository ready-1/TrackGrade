import Foundation

public struct CubeLUT: Equatable, Sendable {
    public let title: String
    public let size: Int
    public let domainMin: SIMD3<Float>
    public let domainMax: SIMD3<Float>
    public let values: [SIMD3<Float>]

    public init(
        title: String,
        size: Int,
        domainMin: SIMD3<Float> = SIMD3<Float>(repeating: 0),
        domainMax: SIMD3<Float> = SIMD3<Float>(repeating: 1),
        values: [SIMD3<Float>]
    ) {
        self.title = title
        self.size = size
        self.domainMin = domainMin
        self.domainMax = domainMax
        self.values = values
    }

    public var entryCount: Int {
        values.count
    }

    public func serialize() -> String {
        let formatter = CubeLUTNumberFormatter.shared
        let header = [
            "TITLE \"\(title)\"",
            "LUT_3D_SIZE \(size)",
            "DOMAIN_MIN \(formatter.string(from: domainMin.x)) \(formatter.string(from: domainMin.y)) \(formatter.string(from: domainMin.z))",
            "DOMAIN_MAX \(formatter.string(from: domainMax.x)) \(formatter.string(from: domainMax.y)) \(formatter.string(from: domainMax.z))",
        ]

        let body = values.map { value in
            "\(formatter.string(from: value.x)) \(formatter.string(from: value.y)) \(formatter.string(from: value.z))"
        }

        return (header + body).joined(separator: "\n") + "\n"
    }

    public static func parse(
        _ cubeText: String
    ) throws -> CubeLUT {
        var title = "Untitled"
        var size = 0
        var domainMin = SIMD3<Float>(repeating: 0)
        var domainMax = SIMD3<Float>(repeating: 1)
        var values: [SIMD3<Float>] = []

        let lines = cubeText.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.isEmpty == false, line.hasPrefix("#") == false else {
                continue
            }

            if line.hasPrefix("TITLE") {
                title = line
                    .replacingOccurrences(of: "TITLE", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
                continue
            }

            if line.hasPrefix("LUT_3D_SIZE") {
                let components = line.components(separatedBy: .whitespaces).filter { $0.isEmpty == false }
                guard components.count == 2, let parsedSize = Int(components[1]) else {
                    throw CubeLUTParseError.invalidHeader(line)
                }
                size = parsedSize
                continue
            }

            if line.hasPrefix("DOMAIN_MIN") {
                domainMin = try parseVector(headerLine: line)
                continue
            }

            if line.hasPrefix("DOMAIN_MAX") {
                domainMax = try parseVector(headerLine: line)
                continue
            }

            values.append(try parseValueLine(line))
        }

        guard size > 0 else {
            throw CubeLUTParseError.missingSize
        }

        let expectedValueCount = size * size * size
        guard values.count == expectedValueCount else {
            throw CubeLUTParseError.unexpectedEntryCount(expected: expectedValueCount, actual: values.count)
        }

        return CubeLUT(
            title: title,
            size: size,
            domainMin: domainMin,
            domainMax: domainMax,
            values: values
        )
    }

    private static func parseVector(
        headerLine: String
    ) throws -> SIMD3<Float> {
        let components = headerLine.components(separatedBy: .whitespaces).filter { $0.isEmpty == false }
        guard components.count == 4,
              let x = Float(components[1]),
              let y = Float(components[2]),
              let z = Float(components[3]) else {
            throw CubeLUTParseError.invalidHeader(headerLine)
        }

        return SIMD3<Float>(x, y, z)
    }

    private static func parseValueLine(
        _ line: String
    ) throws -> SIMD3<Float> {
        let components = line.components(separatedBy: .whitespaces).filter { $0.isEmpty == false }
        guard components.count == 3,
              let x = Float(components[0]),
              let y = Float(components[1]),
              let z = Float(components[2]) else {
            throw CubeLUTParseError.invalidValueLine(line)
        }

        return SIMD3<Float>(x, y, z)
    }
}

public enum CubeLUTParseError: Error, Equatable, Sendable {
    case missingSize
    case invalidHeader(String)
    case invalidValueLine(String)
    case unexpectedEntryCount(expected: Int, actual: Int)
}

private final class CubeLUTNumberFormatter: @unchecked Sendable {
    static let shared = CubeLUTNumberFormatter()

    private let formatter: NumberFormatter

    private init() {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 6
        formatter.maximumFractionDigits = 8
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = false
        self.formatter = formatter
    }

    func string(
        from value: Float
    ) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.8f", value)
    }
}
