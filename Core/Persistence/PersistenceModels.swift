import Foundation

public struct SnapshotRecord: Identifiable, Equatable, Sendable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public struct KnownDeviceRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var address: String
    public var credentialsReference: String?

    public init(
        id: UUID = UUID(),
        name: String,
        address: String,
        credentialsReference: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.credentialsReference = credentialsReference
    }
}
