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
}
