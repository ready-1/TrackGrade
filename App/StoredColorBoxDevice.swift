import Foundation
import SwiftData

@Model
final class StoredColorBoxDevice {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var username: String
    var credentialReference: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        username: String = "admin",
        credentialReference: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.username = username
        self.credentialReference = credentialReference
        self.createdAt = createdAt
    }
}
