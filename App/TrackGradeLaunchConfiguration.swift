import Foundation

enum TrackGradeLaunchArgument {
    static let uiTestFixture = "-ui-test-fixture"
}

struct TrackGradeLaunchConfiguration {
    let usesUITestFixture: Bool

    static let current = TrackGradeLaunchConfiguration(
        arguments: ProcessInfo.processInfo.arguments
    )

    init(arguments: [String]) {
        usesUITestFixture = arguments.contains(TrackGradeLaunchArgument.uiTestFixture)
    }

    static func prepareProcessForLaunch(
        _ configuration: TrackGradeLaunchConfiguration = .current
    ) {
        guard configuration.usesUITestFixture else {
            return
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
    }
}

struct TrackGradeUITestFixture {
    let knownDevices: [StoredColorBoxDevice]
    let snapshots: [ManagedColorBoxDevice]
    let presetGrades: [UUID: [Int: ColorBoxGradeControlState]]

    static func make() -> TrackGradeUITestFixture {
        let deviceID = UUID(uuidString: "A0C95A0B-4B33-4A4B-A2D4-2A2BC4E4F001") ?? UUID()
        let grade = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: 0.08, green: -0.02, blue: 0.03),
            gamma: ColorBoxRGBVector(red: 0.12, green: 0.02, blue: -0.07),
            gain: ColorBoxRGBVector(red: 1.08, green: 0.97, blue: 1.11),
            saturation: 1.10
        )
        let pipelineState = ColorBoxPipelineState(
            bypassEnabled: false,
            falseColorEnabled: false,
            dynamicLUTMode: "dynamic",
            gradeControl: grade
        )
        let previewData = Data(base64Encoded: Self.previewPNGBase64)
        let preset = ColorBoxPresetSummary(slot: 4, name: "House Look")
        let snapshot = ManagedColorBoxDevice(
            id: deviceID,
            name: "Fixture ColorBox",
            address: "mock://fixture-colorbox",
            connectionState: .connected,
            systemInfo: ColorBoxSystemInfo(
                productName: "AJA ColorBox",
                modelName: "ColorBox",
                serialNumber: "FIXTURE-0001",
                deviceUUID: deviceID,
                hostName: "Fixture-ColorBox"
            ),
            firmwareInfo: ColorBoxFirmwareInfo(
                version: "fixture-3.0.0.24",
                build: "ui-test"
            ),
            pipelineState: pipelineState,
            supportsFalseColor: false,
            presets: [preset],
            previewFrameData: previewData,
            previewByteCount: previewData?.count ?? 0
        )
        let knownDevice = StoredColorBoxDevice(
            id: deviceID,
            name: "Fixture ColorBox",
            address: "mock://fixture-colorbox"
        )

        return TrackGradeUITestFixture(
            knownDevices: [knownDevice],
            snapshots: [snapshot],
            presetGrades: [
                deviceID: [
                    preset.slot: grade
                ]
            ]
        )
    }

    private static let previewPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+c7xkAAAAASUVORK5CYII="
}
