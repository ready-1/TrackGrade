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

    public init(username: String, password: String) {
        self.username = username
        self.password = password
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

public struct ColorBoxPipelineState: Codable, Sendable, Equatable {
    public let bypassEnabled: Bool
    public let falseColorEnabled: Bool
    public let dynamicLUTMode: String
    public let lastRecalledPresetSlot: Int?

    public init(
        bypassEnabled: Bool,
        falseColorEnabled: Bool,
        dynamicLUTMode: String,
        lastRecalledPresetSlot: Int? = nil
    ) {
        self.bypassEnabled = bypassEnabled
        self.falseColorEnabled = falseColorEnabled
        self.dynamicLUTMode = dynamicLUTMode
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
