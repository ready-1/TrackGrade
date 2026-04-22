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
    let librarySections: [UUID: [ColorBoxLibrarySection]]
    let snapshotsData: [StoredGradeSnapshot]

    static func make() -> TrackGradeUITestFixture {
        let deviceAID = UUID(uuidString: "A0C95A0B-4B33-4A4B-A2D4-2A2BC4E4F001") ?? UUID()
        let deviceBID = UUID(uuidString: "A0C95A0B-4B33-4A4B-A2D4-2A2BC4E4F002") ?? UUID()
        let deviceCID = UUID(uuidString: "A0C95A0B-4B33-4A4B-A2D4-2A2BC4E4F003") ?? UUID()

        let sharedGrade = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: 0.08, green: -0.02, blue: 0.03),
            gamma: ColorBoxRGBVector(red: 0.12, green: 0.02, blue: -0.07),
            gain: ColorBoxRGBVector(red: 1.08, green: 0.97, blue: 1.11),
            saturation: 1.10
        )
        let snapshotGrade = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: -0.04, green: 0.01, blue: 0.06),
            gamma: ColorBoxRGBVector(red: 0.03, green: -0.02, blue: 0.04),
            gain: ColorBoxRGBVector(red: 0.96, green: 1.05, blue: 1.02),
            saturation: 0.92
        )
        let pipelineState = ColorBoxPipelineState(
            bypassEnabled: false,
            falseColorEnabled: false,
            dynamicLUTMode: "dynamic",
            gradeControl: sharedGrade
        )
        let previewData = Data(base64Encoded: Self.previewPNGBase64)
        let preset = ColorBoxPresetSummary(slot: 4, name: "House Look")
        let snapshotA = makeSnapshot(
            id: deviceAID,
            name: "Fixture ColorBox A",
            address: "mock://fixture-colorbox-a",
            serialNumber: "FIXTURE-0001",
            hostName: "Fixture-ColorBox-A",
            pipelineState: pipelineState,
            preset: preset,
            previewData: previewData
        )
        let snapshotB = makeSnapshot(
            id: deviceBID,
            name: "Fixture ColorBox B",
            address: "mock://fixture-colorbox-b",
            serialNumber: "FIXTURE-0002",
            hostName: "Fixture-ColorBox-B",
            pipelineState: pipelineState,
            preset: preset,
            previewData: previewData
        )
        let snapshotC = makeSnapshot(
            id: deviceCID,
            name: "Fixture ColorBox C",
            address: "mock://fixture-colorbox-c",
            serialNumber: "FIXTURE-0003",
            hostName: "Fixture-ColorBox-C",
            pipelineState: pipelineState,
            preset: preset,
            previewData: previewData
        )
        let knownDeviceA = StoredColorBoxDevice(
            id: deviceAID,
            name: "Fixture ColorBox A",
            address: "mock://fixture-colorbox-a"
        )
        let knownDeviceB = StoredColorBoxDevice(
            id: deviceBID,
            name: "Fixture ColorBox B",
            address: "mock://fixture-colorbox-b"
        )
        let knownDeviceC = StoredColorBoxDevice(
            id: deviceCID,
            name: "Fixture ColorBox C",
            address: "mock://fixture-colorbox-c"
        )
        let storedSnapshot = StoredGradeSnapshot(
            deviceID: deviceAID,
            deviceName: "Fixture ColorBox A",
            name: "Lobby Warm-Up",
            previewFrameData: previewData,
            gradeControl: snapshotGrade
        )

        return TrackGradeUITestFixture(
            knownDevices: [knownDeviceA, knownDeviceB, knownDeviceC],
            snapshots: [snapshotA, snapshotB, snapshotC],
            presetGrades: [
                deviceAID: [preset.slot: sharedGrade],
                deviceBID: [preset.slot: sharedGrade],
                deviceCID: [preset.slot: sharedGrade],
            ],
            librarySections: [
                deviceAID: fixtureLibrarySections(),
                deviceBID: fixtureLibrarySections(),
                deviceCID: fixtureLibrarySections(),
            ],
            snapshotsData: [storedSnapshot]
        )
    }

    static func fixtureLibrarySections() -> [ColorBoxLibrarySection] {
        [
            ColorBoxLibrarySection(
                kind: .oneDLUT,
                entries: [
                    ColorBoxLibraryEntry(kind: .oneDLUT, slot: 1, userName: "709 Clamp", fileName: "709-clamp.cube"),
                    ColorBoxLibraryEntry(kind: .oneDLUT, slot: 2, userName: "Legalize", fileName: "legalize.cube"),
                ]
            ),
            ColorBoxLibrarySection(
                kind: .threeDLUT,
                entries: [
                    ColorBoxLibraryEntry(kind: .threeDLUT, slot: 1, userName: "Stage Neutral", fileName: "stage-neutral-33.cube"),
                    ColorBoxLibraryEntry(kind: .threeDLUT, slot: 2, userName: "Warm LED", fileName: "warm-led-33.cube"),
                ]
            ),
            ColorBoxLibrarySection(
                kind: .matrix,
                entries: [
                    ColorBoxLibraryEntry(kind: .matrix, slot: 1, userName: "LED Matrix A", fileName: "led-matrix-a.mtx"),
                ]
            ),
            ColorBoxLibrarySection(
                kind: .image,
                entries: [
                    ColorBoxLibraryEntry(kind: .image, slot: 1, userName: "Framing Guide", fileName: "framing-guide.png"),
                ]
            ),
            ColorBoxLibrarySection(
                kind: .overlay,
                entries: [
                    ColorBoxLibraryEntry(kind: .overlay, slot: 1, userName: "Lower Third", fileName: "lower-third.png"),
                ]
            ),
        ]
    }

    private static func makeSnapshot(
        id: UUID,
        name: String,
        address: String,
        serialNumber: String,
        hostName: String,
        pipelineState: ColorBoxPipelineState,
        preset: ColorBoxPresetSummary,
        previewData: Data?
    ) -> ManagedColorBoxDevice {
        ManagedColorBoxDevice(
            id: id,
            name: name,
            address: address,
            connectionState: .connected,
            systemInfo: ColorBoxSystemInfo(
                productName: "AJA ColorBox",
                modelName: "ColorBox",
                serialNumber: serialNumber,
                deviceUUID: id,
                hostName: hostName
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
    }

    private static let previewPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+c7xkAAAAASUVORK5CYII="
}
