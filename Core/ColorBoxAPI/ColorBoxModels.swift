import Foundation

public struct ColorBoxEndpoint: Codable, Sendable, Equatable {
    public let baseURL: URL
    public let timeout: TimeInterval

    public init(baseURL: URL, timeout: TimeInterval = 5) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    public static func resolve(_ address: String, timeout: TimeInterval = 5) throws -> ColorBoxEndpoint {
        let normalizedAddress: String
        if address.hasPrefix("http://") || address.hasPrefix("https://") {
            normalizedAddress = address
        } else {
            normalizedAddress = "http://\(address)"
        }

        guard let url = URL(string: normalizedAddress) else {
            throw ColorBoxAPIError.invalidEndpoint(address)
        }

        let normalizedBaseURL: URL
        if normalizedAddress.hasSuffix("/") {
            normalizedBaseURL = url
        } else {
            normalizedBaseURL = url.appendingPathComponent("", isDirectory: true)
        }

        return ColorBoxEndpoint(baseURL: normalizedBaseURL, timeout: timeout)
    }
}

public struct ColorBoxCredentials: Codable, Sendable, Equatable {
    public let username: String
    public let password: String
    public let apiKey: String?

    public init(
        username: String,
        password: String,
        apiKey: String? = nil
    ) {
        self.username = username
        self.password = password
        self.apiKey = apiKey
    }
}

public struct ColorBoxSystemInfo: Codable, Sendable, Equatable {
    public let productName: String
    public let modelName: String
    public let serialNumber: String
    public let deviceUUID: UUID
    public let hostName: String

    public init(
        productName: String,
        modelName: String,
        serialNumber: String,
        deviceUUID: UUID,
        hostName: String
    ) {
        self.productName = productName
        self.modelName = modelName
        self.serialNumber = serialNumber
        self.deviceUUID = deviceUUID
        self.hostName = hostName
    }
}

public struct ColorBoxFirmwareInfo: Codable, Sendable, Equatable {
    public let version: String
    public let build: String

    public init(version: String, build: String) {
        self.version = version
        self.build = build
    }
}

public struct ColorBoxRGBVector: Codable, Sendable, Equatable {
    public var red: Float
    public var green: Float
    public var blue: Float

    public init(
        red: Float,
        green: Float,
        blue: Float
    ) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct ColorBoxControlPoint: Codable, Sendable, Equatable {
    public var x: Float
    public var y: Float

    public static let zero = ColorBoxControlPoint(x: 0, y: 0)

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public var magnitude: Float {
        sqrt((x * x) + (y * y))
    }

    public func clampedToUnitDisk() -> ColorBoxControlPoint {
        let magnitude = magnitude
        guard magnitude > 1, magnitude > 0 else {
            return self
        }

        let scale = 1 / magnitude
        return ColorBoxControlPoint(
            x: x * scale,
            y: y * scale
        )
    }
}

public struct ColorBoxTrackballState: Codable, Sendable, Equatable {
    public var ball: ColorBoxControlPoint
    public var ring: Float

    public static let zero = ColorBoxTrackballState(
        ball: .zero,
        ring: 0
    )

    public init(
        ball: ColorBoxControlPoint = .zero,
        ring: Float = 0
    ) {
        self.ball = ball
        self.ring = ring
    }
}

public enum ColorBoxTrackballKind: String, CaseIterable, Codable, Sendable {
    case lift
    case gamma
    case gain

    fileprivate var ballScale: Float {
        switch self {
        case .lift:
            return 0.18
        case .gamma:
            return 0.25
        case .gain:
            return 0.22
        }
    }

    fileprivate var ringScale: Float {
        switch self {
        case .lift:
            return 0.5
        case .gamma:
            return 0.5
        case .gain:
            return 1.0
        }
    }

    fileprivate var neutralChannelValue: Float {
        switch self {
        case .gain:
            return 1
        case .lift, .gamma:
            return 0
        }
    }

    fileprivate var channelRange: ClosedRange<Float> {
        switch self {
        case .lift:
            return -0.75 ... 0.75
        case .gamma:
            return -1.0 ... 1.0
        case .gain:
            return 0.0 ... 2.0
        }
    }
}

public enum ColorBoxTrackballMapping {
    public static func vector(
        for state: ColorBoxTrackballState,
        kind: ColorBoxTrackballKind
    ) -> ColorBoxRGBVector {
        let clampedBall = state.ball.clampedToUnitDisk()
        let luminance = state.ring.clamped(to: -1 ... 1) * kind.ringScale
        let chroma = chromaVector(
            x: clampedBall.x,
            y: clampedBall.y,
            scale: kind.ballScale
        )
        let neutral = kind.neutralChannelValue

        return ColorBoxRGBVector(
            red: (neutral + luminance + chroma.red).clamped(to: kind.channelRange),
            green: (neutral + luminance + chroma.green).clamped(to: kind.channelRange),
            blue: (neutral + luminance + chroma.blue).clamped(to: kind.channelRange)
        )
    }

    public static func state(
        for vector: ColorBoxRGBVector,
        kind: ColorBoxTrackballKind
    ) -> ColorBoxTrackballState {
        let neutralRemoved = vector.addingUniform(-kind.neutralChannelValue)
        let luminance = neutralRemoved.averageComponent
        let centered = neutralRemoved.addingUniform(-luminance)

        let x = centered.red / kind.ballScale
        let y = (centered.green - centered.blue) / (sqrt(3) * kind.ballScale)

        return ColorBoxTrackballState(
            ball: ColorBoxControlPoint(x: x, y: y).clampedToUnitDisk(),
            ring: (luminance / kind.ringScale).clamped(to: -1 ... 1)
        )
    }

    private static func chromaVector(
        x: Float,
        y: Float,
        scale: Float
    ) -> ColorBoxRGBVector {
        let greenRotation: Float = .pi * (2 / 3)
        let blueRotation: Float = .pi * (4 / 3)
        let angle = atan2(y, x)
        let magnitude = sqrt((x * x) + (y * y))

        return ColorBoxRGBVector(
            red: magnitude * scale * cos(angle),
            green: magnitude * scale * cos(angle - greenRotation),
            blue: magnitude * scale * cos(angle - blueRotation)
        )
    }
}

public struct ColorBoxGradeControlState: Codable, Sendable, Equatable {
    public var lift: ColorBoxRGBVector
    public var gamma: ColorBoxRGBVector
    public var gain: ColorBoxRGBVector
    public var saturation: Float

    public static let identity = ColorBoxGradeControlState(
        lift: ColorBoxRGBVector(red: 0, green: 0, blue: 0),
        gamma: ColorBoxRGBVector(red: 0, green: 0, blue: 0),
        gain: ColorBoxRGBVector(red: 1, green: 1, blue: 1),
        saturation: 1
    )

    public init(
        lift: ColorBoxRGBVector = ColorBoxRGBVector(red: 0, green: 0, blue: 0),
        gamma: ColorBoxRGBVector = ColorBoxRGBVector(red: 0, green: 0, blue: 0),
        gain: ColorBoxRGBVector = ColorBoxRGBVector(red: 1, green: 1, blue: 1),
        saturation: Float = 1
    ) {
        self.lift = lift
        self.gamma = gamma
        self.gain = gain
        self.saturation = saturation
    }
}

private extension ColorBoxRGBVector {
    var averageComponent: Float {
        (red + green + blue) / 3
    }

    func addingUniform(_ value: Float) -> ColorBoxRGBVector {
        ColorBoxRGBVector(
            red: red + value,
            green: green + value,
            blue: blue + value
        )
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

public struct ColorBoxPipelineState: Codable, Sendable, Equatable {
    public let bypassEnabled: Bool
    public let falseColorEnabled: Bool
    public let dynamicLUTMode: String
    public let gradeControl: ColorBoxGradeControlState
    public let lastRecalledPresetSlot: Int?

    public init(
        bypassEnabled: Bool,
        falseColorEnabled: Bool,
        dynamicLUTMode: String,
        gradeControl: ColorBoxGradeControlState = .identity,
        lastRecalledPresetSlot: Int? = nil
    ) {
        self.bypassEnabled = bypassEnabled
        self.falseColorEnabled = falseColorEnabled
        self.dynamicLUTMode = dynamicLUTMode
        self.gradeControl = gradeControl
        self.lastRecalledPresetSlot = lastRecalledPresetSlot
    }
}

public struct ColorBoxDynamicLUTModeUpdate: Codable, Sendable, Equatable {
    public let mode: String

    public init(mode: String) {
        self.mode = mode
    }
}

public struct ColorBoxDynamicLUTUploadResponse: Codable, Sendable, Equatable {
    public let accepted: Bool
    public let byteCount: Int
    public let sequenceID: String?

    public init(accepted: Bool, byteCount: Int, sequenceID: String?) {
        self.accepted = accepted
        self.byteCount = byteCount
        self.sequenceID = sequenceID
    }
}

public struct ColorBoxBooleanToggle: Codable, Sendable, Equatable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

public struct ColorBoxPresetSummary: Identifiable, Codable, Sendable, Equatable {
    public let slot: Int
    public let name: String

    public var id: String {
        "preset-\(slot)"
    }

    public init(slot: Int, name: String) {
        self.slot = slot
        self.name = name
    }
}

public struct ColorBoxPresetMutation: Codable, Sendable, Equatable {
    public let slot: Int
    public let name: String

    public init(slot: Int, name: String) {
        self.slot = slot
        self.name = name
    }
}

public struct ColorBoxPresetRecall: Codable, Sendable, Equatable {
    public let slot: Int

    public init(slot: Int) {
        self.slot = slot
    }
}
