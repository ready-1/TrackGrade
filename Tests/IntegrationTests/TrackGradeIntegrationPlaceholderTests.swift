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

        let configuredDevice = try await manager.configurePipelineForTrackGrade(id: deviceID)
        XCTAssertEqual(configuredDevice.pipelineState?.dynamicLUTMode, "dynamic")

        let bypassDevice = try await manager.setBypass(id: deviceID, enabled: true)
        XCTAssertEqual(bypassDevice.pipelineState?.bypassEnabled, true)

        let falseColorDevice = try await manager.setFalseColor(id: deviceID, enabled: true)
        XCTAssertEqual(falseColorDevice.pipelineState?.falseColorEnabled, true)

        let savedPresetDevice = try await manager.savePreset(
            id: deviceID,
            slot: 3,
            name: "Stage LED"
        )
        XCTAssertTrue(savedPresetDevice.presets.contains { $0.slot == 3 && $0.name == "Stage LED" })

        let recalledPresetDevice = try await manager.recallPreset(id: deviceID, slot: 3)
        XCTAssertEqual(recalledPresetDevice.pipelineState?.lastRecalledPresetSlot, 3)

        let previewDevice = try await manager.refreshPreview(id: deviceID)
        XCTAssertGreaterThan(previewDevice.previewByteCount, 0)

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

    private func makeApplication(
        port: Int,
        password: String? = nil
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
                latencyMilliseconds: 0,
                firmwareVersion: "mock-1.0.0",
                firmwareBuild: "build-1",
                openAPIDocument: nil
            )
        )

        try await application.startup()
        return application
    }
}
