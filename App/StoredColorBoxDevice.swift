import Foundation
import SwiftData

enum ABScratchSlot: String, CaseIterable, Identifiable, Sendable {
    case a
    case b

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue.uppercased()
    }

    var snapshotKind: StoredGradeSnapshotKind {
        switch self {
        case .a:
            return .scratchA
        case .b:
            return .scratchB
        }
    }
}

enum StoredGradeSnapshotKind: String, Codable, Sendable {
    case standard
    case scratchA
    case scratchB
}

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

@Model
final class StoredGradeSnapshot {
    @Attribute(.unique) var id: UUID
    var deviceID: UUID
    var deviceName: String
    var name: String
    var kindRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var previewFrameData: Data?
    var liftRed: Double
    var liftGreen: Double
    var liftBlue: Double
    var gammaRed: Double
    var gammaGreen: Double
    var gammaBlue: Double
    var gainRed: Double
    var gainGreen: Double
    var gainBlue: Double
    var saturation: Double

    init(
        id: UUID = UUID(),
        deviceID: UUID,
        deviceName: String,
        name: String,
        kind: StoredGradeSnapshotKind = .standard,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        previewFrameData: Data? = nil,
        gradeControl: ColorBoxGradeControlState
    ) {
        self.id = id
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.name = name
        self.kindRawValue = kind.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.previewFrameData = previewFrameData
        self.liftRed = Double(gradeControl.lift.red)
        self.liftGreen = Double(gradeControl.lift.green)
        self.liftBlue = Double(gradeControl.lift.blue)
        self.gammaRed = Double(gradeControl.gamma.red)
        self.gammaGreen = Double(gradeControl.gamma.green)
        self.gammaBlue = Double(gradeControl.gamma.blue)
        self.gainRed = Double(gradeControl.gain.red)
        self.gainGreen = Double(gradeControl.gain.green)
        self.gainBlue = Double(gradeControl.gain.blue)
        self.saturation = Double(gradeControl.saturation)
    }

    var kind: StoredGradeSnapshotKind {
        get {
            StoredGradeSnapshotKind(rawValue: kindRawValue) ?? .standard
        }
        set {
            kindRawValue = newValue.rawValue
        }
    }

    var gradeControl: ColorBoxGradeControlState {
        get {
            ColorBoxGradeControlState(
                lift: ColorBoxRGBVector(
                    red: Float(liftRed),
                    green: Float(liftGreen),
                    blue: Float(liftBlue)
                ),
                gamma: ColorBoxRGBVector(
                    red: Float(gammaRed),
                    green: Float(gammaGreen),
                    blue: Float(gammaBlue)
                ),
                gain: ColorBoxRGBVector(
                    red: Float(gainRed),
                    green: Float(gainGreen),
                    blue: Float(gainBlue)
                ),
                saturation: Float(saturation)
            )
        }
        set {
            liftRed = Double(newValue.lift.red)
            liftGreen = Double(newValue.lift.green)
            liftBlue = Double(newValue.lift.blue)
            gammaRed = Double(newValue.gamma.red)
            gammaGreen = Double(newValue.gamma.green)
            gammaBlue = Double(newValue.gamma.blue)
            gainRed = Double(newValue.gain.red)
            gainGreen = Double(newValue.gain.green)
            gainBlue = Double(newValue.gain.blue)
            saturation = Double(newValue.saturation)
        }
    }
}
