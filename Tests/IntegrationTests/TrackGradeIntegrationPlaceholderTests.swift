import XCTest
import Vapor
@testable import MockColorBox
@testable import TrackGradeCore

final class TrackGradeIntegrationTests: XCTestCase {
    func testManagerConnectsAndControlsMockColorBox() async throws {
        let application = try await makeApplication(port: 18080)
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "Mock ColorBox",
            address: "http://127.0.0.1:18080"
        )

        let connectedDevice = try await manager.connect(id: deviceID)
        XCTAssertEqual(connectedDevice.connectionState, .connected)
        XCTAssertEqual(connectedDevice.systemInfo?.productName, "AJA ColorBox")
        XCTAssertEqual(connectedDevice.firmwareInfo?.version, "mock-1.0.0")

        let libraries = try await manager.fetchLibraries(id: deviceID)
        XCTAssertTrue(
            libraries.contains(where: { section in
                section.kind == .threeDLUT
                    && section.entries.contains(where: { $0.displayName == "Stage Neutral" })
            })
        )
        XCTAssertEqual(
            libraries.first(where: { $0.kind == .threeDLUT })?.entries.count,
            16
        )
        XCTAssertEqual(
            libraries.first(where: { $0.kind == .amf })?.entries.count,
            16
        )

        let configuredDevice = try await manager.configurePipelineForTrackGrade(id: deviceID)
        XCTAssertEqual(configuredDevice.pipelineState?.dynamicLUTMode, "dynamic")

        let bypassDevice = try await manager.setBypass(id: deviceID, enabled: true)
        XCTAssertEqual(bypassDevice.pipelineState?.bypassEnabled, true)

        let falseColorDevice = try await manager.setFalseColor(id: deviceID, enabled: true)
        XCTAssertEqual(falseColorDevice.pipelineState?.falseColorEnabled, true)

        let gradeDevice = try await manager.updateGradeControl(
            id: deviceID,
            gradeControl: ColorBoxGradeControlState(
                lift: ColorBoxRGBVector(red: 0.5, green: -0.25, blue: 0.75),
                gamma: ColorBoxRGBVector(red: 0.1, green: 0.0, blue: -0.1),
                gain: ColorBoxRGBVector(red: 1.2, green: 0.95, blue: 1.05),
                saturation: 1.25
            )
        )
        XCTAssertEqual(gradeDevice.pipelineState?.dynamicLUTMode, "dynamic")
        XCTAssertEqual(gradeDevice.pipelineState?.gradeControl.saturation ?? 0, 1.25, accuracy: 0.0001)
        XCTAssertEqual(gradeDevice.pipelineState?.gradeControl.lift.red ?? 0, 0.5, accuracy: 0.0001)

        let savedPresetDevice = try await manager.savePreset(
            id: deviceID,
            slot: 3,
            name: "Stage LED"
        )
        XCTAssertTrue(savedPresetDevice.presets.contains { $0.slot == 3 && $0.name == "Stage LED" })

        let recalledPresetDevice = try await manager.recallPreset(id: deviceID, slot: 3)
        XCTAssertEqual(recalledPresetDevice.pipelineState?.lastRecalledPresetSlot, 3)
        XCTAssertEqual(recalledPresetDevice.pipelineState?.gradeControl.saturation ?? 0, 1.25, accuracy: 0.0001)
        XCTAssertEqual(recalledPresetDevice.pipelineState?.gradeControl.gain.red ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(recalledPresetDevice.pipelineState?.gradeControl.gamma.red ?? 0, 0.1, accuracy: 0.0001)

        let previewDevice = try await manager.refreshPreview(id: deviceID)
        XCTAssertGreaterThan(previewDevice.previewByteCount, 0)
        XCTAssertEqual(previewDevice.pipelineState?.previewSource, .output)

        let inputPreviewDevice = try await manager.setPreviewSource(
            id: deviceID,
            source: .input
        )
        XCTAssertEqual(inputPreviewDevice.pipelineState?.previewSource, .input)
        XCTAssertGreaterThan(inputPreviewDevice.previewByteCount, 0)

        let deletedPresetDevice = try await manager.deletePreset(id: deviceID, slot: 3)
        XCTAssertFalse(deletedPresetDevice.presets.contains { $0.slot == 3 })
    }

    func testClientRejectsUnauthorizedRequests() async throws {
        let application = try await makeApplication(
            port: 18081,
            password: "secret"
        )
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let unauthenticatedClient = ColorBoxAPIClient(
            endpoint: try ColorBoxEndpoint.resolve("http://127.0.0.1:18081")
        )

        do {
            _ = try await unauthenticatedClient.fetchSystemInfo()
            XCTFail("Expected an unauthorized error for missing credentials.")
        } catch let error as ColorBoxAPIError {
            XCTAssertEqual(error, .unauthorized)
        }

        let authenticatedClient = ColorBoxAPIClient(
            endpoint: try ColorBoxEndpoint.resolve("http://127.0.0.1:18081"),
            credentials: ColorBoxCredentials(username: "admin", password: "secret")
        )

        let systemInfo = try await authenticatedClient.fetchSystemInfo()
        XCTAssertEqual(systemInfo.hostName, "ColorBox-1SC001145")
    }

    func testManagerRecoversAfterMockServerRestart() async throws {
        var application: Application? = try await makeApplication(port: 18082)

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "Restartable ColorBox",
            address: "http://127.0.0.1:18082"
        )

        _ = try await manager.connect(id: deviceID)

        try await application?.asyncShutdown()
        application = nil

        _ = try? await manager.refreshDevice(id: deviceID)
        let degradedDevice = await manager.deviceSnapshot(id: deviceID)
        XCTAssertEqual(degradedDevice?.connectionState, .degraded)

        application = try await makeApplication(port: 18082)

        try await Task.sleep(nanoseconds: 500_000_000)

        let recoveredDevice = await manager.deviceSnapshot(id: deviceID)
        XCTAssertEqual(recoveredDevice?.connectionState, .connected)
        XCTAssertEqual(recoveredDevice?.systemInfo?.serialNumber, "1SC001145")

        try await application?.asyncShutdown()
    }

    func testManagerMarksFalseColorUnsupportedWithoutDegradingDevice() async throws {
        let application = try await makeApplication(
            port: 18083,
            supportsFalseColor: false
        )
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "False Color Unsupported",
            address: "http://127.0.0.1:18083"
        )

        let connectedDevice = try await manager.connect(id: deviceID)
        XCTAssertEqual(connectedDevice.connectionState, .connected)
        XCTAssertEqual(connectedDevice.supportsFalseColor, true)

        do {
            _ = try await manager.setFalseColor(id: deviceID, enabled: true)
            XCTFail("Expected an unsupported false-color error.")
        } catch let error as ColorBoxAPIError {
            XCTAssertEqual(
                error,
                .unsupportedFeature(
                    "False color is not exposed by the ColorBox `/v2` API on firmware 3.0.0.24."
                )
            )
        }

        let updatedDevice = await manager.deviceSnapshot(id: deviceID)
        XCTAssertEqual(updatedDevice?.connectionState, .connected)
        XCTAssertEqual(updatedDevice?.supportsFalseColor, false)
        XCTAssertEqual(updatedDevice?.pipelineState?.falseColorEnabled, false)
    }

    func testManagerUploadsIdentityLUTToMockColorBox() async throws {
        let application = try await makeApplication(port: 18084)
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "Upload Mock",
            address: "http://127.0.0.1:18084"
        )

        let cubeText = LUTBaker.bake(
            cdl: .identity,
            transferFunction: .rec709SDR,
            size: 5,
            title: "Identity"
        ).serialize()

        let sequenceID = try await manager.enqueueDynamicLUTUpload(
            id: deviceID,
            cubeText: cubeText
        )
        XCTAssertEqual(sequenceID, 1)

        try await manager.flushDynamicLUTUploads(id: deviceID)

        let state = try XCTUnwrap(MockColorBoxApplication.state(from: application))
        let uploadedText = await state.lastUploadedLUTText()
        let uploadedSequenceID = await state.lastUploadedSequenceID()
        let uploadedCount = await state.dynamicLUTUploadCount()

        XCTAssertEqual(uploadedText, cubeText)
        XCTAssertEqual(uploadedSequenceID, "1")
        XCTAssertEqual(uploadedCount, 1)
    }

    func testDynamicLUTUploadQueueCoalescesRapidUpdates() async throws {
        let application = try await makeApplication(
            port: 18085,
            latencyMilliseconds: 10
        )
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "Queued Upload Mock",
            address: "http://127.0.0.1:18085"
        )

        for index in 0 ..< 1000 {
            _ = try await manager.enqueueDynamicLUTUpload(
                id: deviceID,
                cubeText: Self.simpleCubeText(
                    title: "LUT \(index)",
                    value: Float(index) / 1000
                )
            )
        }

        try await manager.flushDynamicLUTUploads(id: deviceID)

        let state = try XCTUnwrap(MockColorBoxApplication.state(from: application))
        let uploadedText = await state.lastUploadedLUTText()
        let uploadedSequenceID = await state.lastUploadedSequenceID()
        let uploadedCount = await state.dynamicLUTUploadCount()

        XCTAssertEqual(uploadedSequenceID, "1000")
        XCTAssertTrue(uploadedText?.contains("TITLE \"LUT 999\"") == true)
        XCTAssertLessThan(uploadedCount, 1000)
    }

    func testManagerUploadsRenamesAndDeletesLibraryAssetsOnMockColorBox() async throws {
        let application = try await makeApplication(port: 18086)
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "Library Mock",
            address: "http://127.0.0.1:18086"
        )

        let initialLibraries = try await manager.fetchLibraries(id: deviceID)
        let initialThreeDLUTSection = try XCTUnwrap(
            initialLibraries.first(where: { $0.kind == .threeDLUT })
        )
        XCTAssertTrue(
            try XCTUnwrap(initialThreeDLUTSection.entries.first(where: { $0.slot == 3 })).isEmpty
        )

        let uploadedLibraries = try await manager.uploadLibraryEntry(
            id: deviceID,
            kind: .threeDLUT,
            slot: 3,
            fileName: "VenueCue.cube",
            data: Data(Self.simpleCubeText(title: "VenueCue", value: 0.42).utf8)
        )
        let uploadedEntry = try XCTUnwrap(
            uploadedLibraries
                .first(where: { $0.kind == .threeDLUT })?
                .entries
                .first(where: { $0.slot == 3 })
        )
        XCTAssertEqual(uploadedEntry.fileName, "VenueCue.cube")
        XCTAssertEqual(uploadedEntry.userName, "VenueCue")

        let renamedLibraries = try await manager.renameLibraryEntry(
            id: deviceID,
            kind: .threeDLUT,
            slot: 3,
            name: "Venue Cue"
        )
        let renamedEntry = try XCTUnwrap(
            renamedLibraries
                .first(where: { $0.kind == .threeDLUT })?
                .entries
                .first(where: { $0.slot == 3 })
        )
        XCTAssertEqual(renamedEntry.userName, "Venue Cue")
        XCTAssertEqual(renamedEntry.fileName, "VenueCue.cube")

        let deletedLibraries = try await manager.deleteLibraryEntry(
            id: deviceID,
            kind: .threeDLUT,
            slot: 3
        )
        let deletedEntry = try XCTUnwrap(
            deletedLibraries
                .first(where: { $0.kind == .threeDLUT })?
                .entries
                .first(where: { $0.slot == 3 })
        )
        XCTAssertTrue(deletedEntry.isEmpty)
    }

    func testManagerUploadsAndDeletesAMFPackageOnMockColorBox() async throws {
        let application = try await makeApplication(port: 18087)
        defer {
            Task {
                try? await application.asyncShutdown()
            }
        }

        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "AMF Library Mock",
            address: "http://127.0.0.1:18087"
        )

        let initialLibraries = try await manager.fetchLibraries(id: deviceID)
        let initialAMFSection = try XCTUnwrap(
            initialLibraries.first(where: { $0.kind == .amf })
        )
        XCTAssertTrue(
            try XCTUnwrap(initialAMFSection.entries.first(where: { $0.slot == 2 })).isEmpty
        )

        let uploadedLibraries = try await manager.uploadLibraryEntries(
            id: deviceID,
            kind: .amf,
            slot: 2,
            files: [
                ColorBoxLibraryUploadFile(
                    fileName: "venue-wall.amf",
                    data: Data(Self.sampleAMFText.utf8)
                ),
                ColorBoxLibraryUploadFile(
                    fileName: "venue-wall-look.txt",
                    data: Data("mock-companion".utf8)
                ),
            ],
            selectionFileName: "venue-wall.amf"
        )
        let uploadedEntry = try XCTUnwrap(
            uploadedLibraries
                .first(where: { $0.kind == .amf })?
                .entries
                .first(where: { $0.slot == 2 })
        )
        XCTAssertEqual(uploadedEntry.fileName, "venue-wall.amf")
        XCTAssertEqual(uploadedEntry.userName, "venue-wall")

        let deletedLibraries = try await manager.deleteLibraryEntry(
            id: deviceID,
            kind: .amf,
            slot: 2
        )
        let deletedEntry = try XCTUnwrap(
            deletedLibraries
                .first(where: { $0.kind == .amf })?
                .entries
                .first(where: { $0.slot == 2 })
        )
        XCTAssertTrue(deletedEntry.isEmpty)
    }

    func testLiveColorBoxRoundTripsGradeBypassAndPreview() async throws {
        let (manager, deviceID) = try await makeLiveManager()
        let connectedDevice = try await manager.connect(id: deviceID)
        let originalPipelineState = try XCTUnwrap(connectedDevice.pipelineState)
        let originalBypass = originalPipelineState.bypassEnabled
        let originalPreviewSource = originalPipelineState.previewSource
        let originalGradeControl = originalPipelineState.gradeControl

        let alternatePreviewSource: ColorBoxPreviewSource = originalPreviewSource == .output ? .input : .output
        let testGrade = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: 0.04, green: -0.01, blue: 0.02),
            gamma: ColorBoxRGBVector(red: 0.08, green: -0.03, blue: 0.01),
            gain: ColorBoxRGBVector(red: 1.05, green: 0.98, blue: 1.03),
            saturation: 1.12
        )

        try await withAsyncCleanup {
            _ = try? await manager.updateGradeControl(
                id: deviceID,
                gradeControl: originalGradeControl
            )
            _ = try? await manager.setPreviewSource(
                id: deviceID,
                source: originalPreviewSource
            )
            _ = try? await manager.setBypass(
                id: deviceID,
                enabled: originalBypass
            )
        } operation: {
            let gradedDevice = try await manager.updateGradeControl(
                id: deviceID,
                gradeControl: testGrade
            )
            Self.assertGradeControl(
                gradedDevice.pipelineState?.gradeControl,
                matches: testGrade,
                file: #filePath,
                line: #line
            )

            let previewDevice = try await manager.setPreviewSource(
                id: deviceID,
                source: alternatePreviewSource
            )
            XCTAssertEqual(
                previewDevice.pipelineState?.previewSource,
                alternatePreviewSource
            )
            XCTAssertGreaterThan(previewDevice.previewByteCount, 0)

            let bypassedDevice = try await manager.setBypass(
                id: deviceID,
                enabled: originalBypass == false
            )
            XCTAssertEqual(
                bypassedDevice.pipelineState?.bypassEnabled,
                originalBypass == false
            )
        }
    }

    func testLiveColorBoxSupportsPresetLifecycle() async throws {
        let (manager, deviceID) = try await makeLiveManager()
        let connectedDevice = try await manager.connect(id: deviceID)
        let originalPipelineState = try XCTUnwrap(connectedDevice.pipelineState)
        let originalGradeControl = originalPipelineState.gradeControl

        let occupiedSlots = Set(connectedDevice.presets.map(\.slot))
        guard let presetSlot = (1 ... 16).first(where: { occupiedSlots.contains($0) == false }) else {
            throw XCTSkip("The live ColorBox has no empty preset slot available for a reversible test.")
        }

        let savedGrade = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: 0.06, green: -0.02, blue: 0.01),
            gamma: ColorBoxRGBVector(red: 0.09, green: 0.01, blue: -0.04),
            gain: ColorBoxRGBVector(red: 1.08, green: 0.97, blue: 1.04),
            saturation: 1.18
        )
        let alternateGrade = ColorBoxGradeControlState(
            lift: ColorBoxRGBVector(red: -0.03, green: 0.01, blue: 0.02),
            gamma: ColorBoxRGBVector(red: -0.05, green: 0.02, blue: 0.03),
            gain: ColorBoxRGBVector(red: 0.96, green: 1.02, blue: 1.01),
            saturation: 0.93
        )
        let presetName = "TrackGrade Live Preset \(presetSlot)"

        try await withAsyncCleanup {
            _ = try? await manager.deletePreset(id: deviceID, slot: presetSlot)
            _ = try? await manager.updateGradeControl(
                id: deviceID,
                gradeControl: originalGradeControl
            )
        } operation: {
            _ = try await manager.updateGradeControl(
                id: deviceID,
                gradeControl: savedGrade
            )

            let savedPresetDevice = try await manager.savePreset(
                id: deviceID,
                slot: presetSlot,
                name: presetName
            )
            XCTAssertTrue(
                savedPresetDevice.presets.contains(where: {
                    $0.slot == presetSlot && $0.name == presetName
                })
            )

            _ = try await manager.updateGradeControl(
                id: deviceID,
                gradeControl: alternateGrade
            )

            let recalledPresetDevice = try await manager.recallPreset(
                id: deviceID,
                slot: presetSlot
            )
            XCTAssertEqual(
                recalledPresetDevice.pipelineState?.lastRecalledPresetSlot,
                presetSlot
            )
            Self.assertGradeControl(
                recalledPresetDevice.pipelineState?.gradeControl,
                matches: savedGrade,
                file: #filePath,
                line: #line
            )

            let deletedPresetDevice = try await manager.deletePreset(
                id: deviceID,
                slot: presetSlot
            )
            XCTAssertFalse(
                deletedPresetDevice.presets.contains(where: { $0.slot == presetSlot })
            )
        }
    }

    func testLiveColorBoxSupportsThreeDLUTLibraryLifecycle() async throws {
        let (manager, deviceID) = try await makeLiveManager()
        _ = try await manager.connect(id: deviceID)

        let initialLibraries = try await manager.fetchLibraries(id: deviceID)
        let initialThreeDLUTSection = try XCTUnwrap(
            initialLibraries.first(where: { $0.kind == .threeDLUT })
        )
        guard let emptySlot = initialThreeDLUTSection.entries.first(where: \.isEmpty)?.slot else {
            throw XCTSkip("The live ColorBox has no empty 3D LUT slot available for a reversible test.")
        }

        let uploadedFileName = "TrackGradeLiveSlot\(emptySlot).cube"
        let renamedUserName = "TrackGrade Live Slot \(emptySlot)"

        try await withAsyncCleanup {
            _ = try? await manager.deleteLibraryEntry(
                id: deviceID,
                kind: .threeDLUT,
                slot: emptySlot
            )
        } operation: {
            let uploadedLibraries = try await manager.uploadLibraryEntry(
                id: deviceID,
                kind: .threeDLUT,
                slot: emptySlot,
                fileName: uploadedFileName,
                data: Data(Self.simpleCubeText(title: "TrackGradeLive", value: 0.33).utf8)
            )
            let uploadedEntry = try XCTUnwrap(
                uploadedLibraries
                    .first(where: { $0.kind == .threeDLUT })?
                    .entries
                    .first(where: { $0.slot == emptySlot })
            )
            XCTAssertEqual(uploadedEntry.fileName, uploadedFileName)
            XCTAssertFalse(uploadedEntry.isEmpty)

            let renamedLibraries = try await manager.renameLibraryEntry(
                id: deviceID,
                kind: .threeDLUT,
                slot: emptySlot,
                name: renamedUserName
            )
            let renamedEntry = try XCTUnwrap(
                renamedLibraries
                    .first(where: { $0.kind == .threeDLUT })?
                    .entries
                    .first(where: { $0.slot == emptySlot })
            )
            XCTAssertEqual(renamedEntry.userName, renamedUserName)

            let deletedLibraries = try await manager.deleteLibraryEntry(
                id: deviceID,
                kind: .threeDLUT,
                slot: emptySlot
            )
            let deletedEntry = try XCTUnwrap(
                deletedLibraries
                    .first(where: { $0.kind == .threeDLUT })?
                    .entries
                    .first(where: { $0.slot == emptySlot })
            )
            XCTAssertTrue(deletedEntry.isEmpty)
        }
    }

    private func makeApplication(
        port: Int,
        password: String? = nil,
        supportsFalseColor: Bool = true,
        latencyMilliseconds: UInt64 = 0
    ) async throws -> Application {
        let application = try await Application.make(.testing)
        application.http.server.configuration.hostname = "127.0.0.1"
        application.http.server.configuration.port = port

        try MockColorBoxApplication.configure(
            application,
            configuration: MockColorBoxConfiguration(
                host: "127.0.0.1",
                port: port,
                bonjourServiceName: "MockColorBox-Test-\(port)",
                username: password == nil ? nil : "admin",
                password: password,
                supportsFalseColor: supportsFalseColor,
                latencyMilliseconds: latencyMilliseconds,
                firmwareVersion: "mock-1.0.0",
                firmwareBuild: "build-1",
                openAPIDocument: nil
            )
        )

        try await application.startup()
        return application
    }

    private static func simpleCubeText(
        title: String,
        value: Float
    ) -> String {
        let formatted = String(format: "%.6f", value)
        return [
            "TITLE \"\(title)\"",
            "LUT_3D_SIZE 2",
            "DOMAIN_MIN 0.000000 0.000000 0.000000",
            "DOMAIN_MAX 1.000000 1.000000 1.000000",
            "0.000000 0.000000 0.000000",
            "\(formatted) 0.000000 0.000000",
            "0.000000 \(formatted) 0.000000",
            "\(formatted) \(formatted) 0.000000",
            "0.000000 0.000000 \(formatted)",
            "\(formatted) 0.000000 \(formatted)",
            "0.000000 \(formatted) \(formatted)",
            "\(formatted) \(formatted) \(formatted)",
        ].joined(separator: "\n") + "\n"
    }

    private static let sampleAMFText = """
    <?xml version="1.0" encoding="UTF-8"?>
    <aces:acesMetadataFile version="2.0" xmlns:aces="urn:ampas:aces:amf:v2.0">
        <aces:amfInfo>
            <aces:uuid>urn:uuid:948E6925-2B2B-4825-8540-368304288A06</aces:uuid>
        </aces:amfInfo>
        <aces:pipeline>
            <aces:pipelineInfo>
                <aces:uuid>urn:uuid:B5Fd5DfB-ca3b-E62a-5657-dDf31E32cE92</aces:uuid>
            </aces:pipelineInfo>
        </aces:pipeline>
    </aces:acesMetadataFile>
    """

    private func makeLiveManager() async throws -> (DeviceManager, UUID) {
        let address = try liveColorBoxAddress()
        let manager = DeviceManager(retryPolicy: .testing)
        let deviceID = try await manager.registerDevice(
            name: "Live ColorBox",
            address: address
        )
        return (manager, deviceID)
    }

    private func liveColorBoxAddress() throws -> String {
        let environment = ProcessInfo.processInfo.environment
        if let address = environment["TRACKGRADE_LIVE_COLORBOX_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           address.isEmpty == false {
            return address
        }

        throw XCTSkip(
            "Set TRACKGRADE_LIVE_COLORBOX_HOST to run the reversible live hardware integration tests."
        )
    }

    private func withAsyncCleanup(
        cleanup: @escaping () async throws -> Void,
        operation: @escaping () async throws -> Void
    ) async throws {
        do {
            try await operation()
        } catch {
            try? await cleanup()
            throw error
        }

        try await cleanup()
    }

    private static func assertGradeControl(
        _ actual: ColorBoxGradeControlState?,
        matches expected: ColorBoxGradeControlState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected a pipeline grade control value.", file: file, line: line)
            return
        }

        XCTAssertEqual(actual.lift.red, expected.lift.red, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.lift.green, expected.lift.green, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.lift.blue, expected.lift.blue, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.gamma.red, expected.gamma.red, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.gamma.green, expected.gamma.green, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.gamma.blue, expected.gamma.blue, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.gain.red, expected.gain.red, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.gain.green, expected.gain.green, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.gain.blue, expected.gain.blue, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.saturation, expected.saturation, accuracy: 0.0001, file: file, line: line)
    }
}
