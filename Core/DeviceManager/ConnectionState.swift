import Foundation

public enum ConnectionState: String, Codable, Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case degraded
    case error
}

public struct ConnectionRetryPolicy: Sendable, Equatable {
    public let delays: [TimeInterval]

    public init(delays: [TimeInterval]) {
        self.delays = delays
    }

    public static let `default` = ConnectionRetryPolicy(
        delays: [1, 2, 4, 8, 16, 30]
    )

    public static let testing = ConnectionRetryPolicy(
        delays: [0.05, 0.1, 0.2]
    )
}

public struct ManagedColorBoxDevice: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var address: String
    public var connectionState: ConnectionState
    public var lastErrorDescription: String?
    public var systemInfo: ColorBoxSystemInfo?
    public var firmwareInfo: ColorBoxFirmwareInfo?
    public var pipelineState: ColorBoxPipelineState?
    public var presets: [ColorBoxPresetSummary]
    public var previewFrameData: Data?
    public var previewByteCount: Int

    public init(
        id: UUID,
        name: String,
        address: String,
        connectionState: ConnectionState = .disconnected,
        lastErrorDescription: String? = nil,
        systemInfo: ColorBoxSystemInfo? = nil,
        firmwareInfo: ColorBoxFirmwareInfo? = nil,
        pipelineState: ColorBoxPipelineState? = nil,
        presets: [ColorBoxPresetSummary] = [],
        previewFrameData: Data? = nil,
        previewByteCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.connectionState = connectionState
        self.lastErrorDescription = lastErrorDescription
        self.systemInfo = systemInfo
        self.firmwareInfo = firmwareInfo
        self.pipelineState = pipelineState
        self.presets = presets
        self.previewFrameData = previewFrameData
        self.previewByteCount = previewByteCount
    }
}
