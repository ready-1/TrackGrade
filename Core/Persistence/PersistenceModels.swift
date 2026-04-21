import Foundation

public struct SnapshotRecord: Identifiable, Equatable, Sendable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}
