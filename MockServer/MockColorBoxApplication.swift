import Foundation
import Vapor
import TrackGradeCore

struct MockColorBoxConfiguration: Sendable, Equatable {
    var host: String
    var port: Int
    var bonjourServiceName: String
    var username: String?
    var password: String?
    var latencyMilliseconds: UInt64
    var firmwareVersion: String
    var firmwareBuild: String
    var openAPIDocument: Data?

    static func fromEnvironment() -> MockColorBoxConfiguration {
        MockColorBoxConfiguration(
            host: Environment.get("MOCK_COLORBOX_HOST") ?? "0.0.0.0",
            port: Int(Environment.get("MOCK_COLORBOX_PORT") ?? "") ?? 8080,
            bonjourServiceName: Environment.get("MOCK_COLORBOX_SERVICE_NAME") ?? "MockColorBox-TrackGrade",
            username: Environment.get("MOCK_COLORBOX_USERNAME"),
            password: Environment.get("MOCK_COLORBOX_PASSWORD"),
            latencyMilliseconds: UInt64(Environment.get("MOCK_COLORBOX_LATENCY_MS") ?? "") ?? 0,
            firmwareVersion: Environment.get("MOCK_COLORBOX_FIRMWARE_VERSION") ?? "mock-1.0.0",
            firmwareBuild: Environment.get("MOCK_COLORBOX_FIRMWARE_BUILD") ?? "mock-build-1",
            openAPIDocument: try? Data(contentsOf: URL(fileURLWithPath: "Docs/openapi-colorbox.json"))
        )
    }
}

private struct MockColorBoxStateKey: StorageKey {
    typealias Value = MockColorBoxState
}

enum MockColorBoxApplication {
    static func configure(
        _ app: Application,
        configuration: MockColorBoxConfiguration
    ) throws {
        let state = MockColorBoxState(configuration: configuration)
        app.storage[MockColorBoxStateKey.self] = state

        if configuration.password != nil {
            app.middleware.use(
                MockColorBoxBasicAuthMiddleware(
                    username: configuration.username ?? "admin",
                    password: configuration.password ?? ""
                )
            )
        }

        app.get("system", "info") { request async throws -> ColorBoxSystemInfo in
            try await state.systemInfo()
        }

        app.get("system", "firmware") { request async throws -> ColorBoxFirmwareInfo in
            try await state.firmwareInfo()
        }

        app.get("v2", "buildInfo") { request async throws -> MockColorBoxBuildInfo in
            let firmware = try await state.firmwareInfo()
            return MockColorBoxBuildInfo(
                date: "2026-04-21",
                time: "12:00:00",
                repoident: firmware.build,
                buildType: "Debug",
                appVersion: firmware.version,
                qtVersion: "mock-qt"
            )
        }

        app.get("v2", "system", "config") { request async throws -> MockColorBoxSystemConfig in
            let systemInfo = try await state.systemInfo()
            return MockColorBoxSystemConfig(
                hostName: systemInfo.hostName,
                systemOrganizationName: "",
                ssdpEnable: true,
                identify: false,
                updateRequest: false,
                reboot: false,
                refresh: false,
                shutdown: false,
                factoryPreset: false,
                factoryReset: false,
                transformMode: "LUT",
                previewAncEnable: true,
                authenticationEnable: configuration.password != nil,
                fanSpeed: 170,
                startupPreset: 1
            )
        }

        app.get("v2", "system", "status") { request async throws -> MockColorBoxSystemStatus in
            let firmware = try await state.firmwareInfo()
            return MockColorBoxSystemStatus(
                safebootVersion: "mock-safe-1",
                mainbootVersion: firmware.version,
                runningVersion: firmware.version,
                safeboot: false,
                updateMsg: [],
                transformModeChanging: false,
                transformModeTimestamp: nil
            )
        }

        app.get("v2", "routing") { request async throws -> MockColorBoxRouting in
            let pipelineState = try await state.pipelineState()
            return MockColorBoxRouting(
                mode: "Input",
                previewTap: "OUTPUT",
                pipelineBypassButton: false,
                pipelineBypassUser: pipelineState.bypassEnabled
            )
        }

        app.put("v2", "routing") { request async throws -> HTTPStatus in
            let routing = try request.content.decode(MockColorBoxRouting.self)
            _ = try await state.setBypass(routing.pipelineBypassUser)
            return .ok
        }

        app.get("v2", "pipelineStages") { request async throws -> MockColorBoxPipelineStages in
            let pipelineState = try await state.pipelineState()
            return MockColorBoxPipelineStages(
                lut3d1: MockColorBoxStage(
                    enabled: true,
                    dynamic: pipelineState.dynamicLUTMode == "dynamic",
                    libraryEntry: 0
                ),
                inColorimetry: "BT.709",
                inRange: "SMPTEFull",
                outColorimetry: "BT.709",
                outRange: "SMPTEFull",
                transferCharacteristic: "SDR",
                cscFilter: "None"
            )
        }

        app.put("v2", "pipelineStages") { request async throws -> HTTPStatus in
            let stages = try request.content.decode(MockColorBoxPipelineStages.self)
            let mode = stages.lut3d1.dynamic ? "dynamic" : "static"
            _ = try await state.configureDynamicLUTNode(mode: mode)
            return .ok
        }

        app.get("v2", "systemPresetLibrary") { request async throws -> [MockColorBoxLibraryEntry] in
            let entries = try await state.systemPresetLibraryEntries()
            return entries.map { entry in
                MockColorBoxLibraryEntry(
                    userName: entry.userName,
                    fileName: entry.fileName
                )
            }
        }

        app.get("v2", "libraryControl") { request async throws -> MockColorBoxLibraryControl in
            let control = try await state.libraryControl()
            return MockColorBoxLibraryControl(
                library: control.library,
                entry: control.entry,
                action: control.action,
                data: control.data,
                errorMsg: control.errorMessage
            )
        }

        app.put("v2", "libraryControl") { request async throws -> HTTPStatus in
            let control = try request.content.decode(MockColorBoxLibraryControl.self)
            try await state.applyLibraryControl(
                library: control.library,
                entry: control.entry,
                action: control.action,
                data: control.data
            )
            let latestControl = try await state.libraryControl()
            if latestControl.errorMessage.isEmpty == false {
                throw Abort(.conflict, reason: latestControl.errorMessage)
            }
            return .ok
        }

        app.get("v2", "preview") { request async throws -> MockColorBoxPreview in
            let data = try await state.previewImageData()
            return MockColorBoxPreview(
                image: data.base64EncodedString(),
                imageType: "png",
                ancData: nil,
                userData1: nil,
                userData2: nil
            )
        }

        app.get("pipeline", "state") { request async throws -> ColorBoxPipelineState in
            try await state.pipelineState()
        }

        app.patch("pipeline", "aja", "nodes", "3dlut", "dynamic") { request async throws -> ColorBoxPipelineState in
            let update = try request.content.decode(ColorBoxDynamicLUTModeUpdate.self)
            return try await state.configureDynamicLUTNode(mode: update.mode)
        }

        app.put("pipeline", "aja", "nodes", "3dlut", "dynamic") { request async throws -> ColorBoxDynamicLUTUploadResponse in
            let uploadData = request.body.data.flatMap { buffer in
                buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes)
            } ?? Data()
            let sequenceID = request.headers.first(name: "X-TrackGrade-Sequence")
            return try await state.storeDynamicLUTUpload(
                data: uploadData,
                sequenceID: sequenceID
            )
        }

        app.patch("pipeline", "bypass") { request async throws -> ColorBoxPipelineState in
            let toggle = try request.content.decode(ColorBoxBooleanToggle.self)
            return try await state.setBypass(toggle.enabled)
        }

        app.patch("pipeline", "false-color") { request async throws -> ColorBoxPipelineState in
            let toggle = try request.content.decode(ColorBoxBooleanToggle.self)
            return try await state.setFalseColor(toggle.enabled)
        }

        app.get("presets") { request async throws -> [ColorBoxPresetSummary] in
            try await state.presets()
        }

        app.post("presets", "save") { request async throws -> [ColorBoxPresetSummary] in
            let mutation = try request.content.decode(ColorBoxPresetMutation.self)
            return try await state.savePreset(slot: mutation.slot, name: mutation.name)
        }

        app.post("presets", "recall") { request async throws -> ColorBoxPipelineState in
            let recall = try request.content.decode(ColorBoxPresetRecall.self)
            return try await state.recallPreset(slot: recall.slot)
        }

        app.delete("presets", ":slot") { request async throws -> [ColorBoxPresetSummary] in
            guard let slot = request.parameters.get("slot", as: Int.self) else {
                throw Abort(.badRequest, reason: "Preset slot missing.")
            }
            return try await state.deletePreset(slot: slot)
        }

        app.get("preview", "frame") { request async throws -> Response in
            let data = try await state.previewImageData()
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "image/png")
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }

        app.get("api") { request async throws -> Response in
            guard let document = configuration.openAPIDocument else {
                throw Abort(.notFound, reason: "No OpenAPI document has been committed yet.")
            }

            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "application/json")
            return Response(status: .ok, headers: headers, body: .init(data: document))
        }
    }
}

private struct MockColorBoxBasicAuthMiddleware: AsyncMiddleware {
    let username: String
    let password: String

    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        guard let authorization = request.headers.basicAuthorization else {
            throw Abort(.unauthorized, reason: "Basic authentication is required.")
        }

        guard authorization.username == username, authorization.password == password else {
            throw Abort(.unauthorized, reason: "Invalid ColorBox credentials.")
        }

        return try await next.respond(to: request)
    }
}

extension ColorBoxSystemInfo: Content {}
extension ColorBoxFirmwareInfo: Content {}
extension ColorBoxPipelineState: Content {}
extension ColorBoxDynamicLUTModeUpdate: Content {}
extension ColorBoxDynamicLUTUploadResponse: Content {}
extension ColorBoxBooleanToggle: Content {}
extension ColorBoxPresetSummary: Content {}
extension ColorBoxPresetMutation: Content {}
extension ColorBoxPresetRecall: Content {}

private struct MockColorBoxBuildInfo: Content {
    let date: String
    let time: String
    let repoident: String
    let buildType: String
    let appVersion: String
    let qtVersion: String
}

private struct MockColorBoxSystemConfig: Content {
    let hostName: String
    let systemOrganizationName: String
    let ssdpEnable: Bool
    let identify: Bool
    let updateRequest: Bool
    let reboot: Bool
    let refresh: Bool
    let shutdown: Bool
    let factoryPreset: Bool
    let factoryReset: Bool
    let transformMode: String
    let previewAncEnable: Bool
    let authenticationEnable: Bool
    let fanSpeed: Double
    let startupPreset: Int
}

private struct MockColorBoxSystemStatus: Content {
    let safebootVersion: String
    let mainbootVersion: String
    let runningVersion: String
    let safeboot: Bool
    let updateMsg: [String]
    let transformModeChanging: Bool
    let transformModeTimestamp: String?
}

private struct MockColorBoxRouting: Content {
    let mode: String
    let previewTap: String
    let pipelineBypassButton: Bool
    let pipelineBypassUser: Bool
}

private struct MockColorBoxPipelineStages: Content {
    let lut3d1: MockColorBoxStage
    let inColorimetry: String
    let inRange: String
    let outColorimetry: String
    let outRange: String
    let transferCharacteristic: String
    let cscFilter: String

    enum CodingKeys: String, CodingKey {
        case lut3d1 = "lut3d_1"
        case inColorimetry
        case inRange
        case outColorimetry
        case outRange
        case transferCharacteristic
        case cscFilter
    }
}

private struct MockColorBoxStage: Content {
    let enabled: Bool
    let dynamic: Bool
    let libraryEntry: Int
}

private struct MockColorBoxLibraryEntry: Content {
    let userName: String?
    let fileName: String?
}

private struct MockColorBoxLibraryControl: Content {
    let library: String
    let entry: Int
    let action: String
    let data: String
    let errorMsg: String
}

private struct MockColorBoxPreview: Content {
    let image: String
    let imageType: String
    let ancData: String?
    let userData1: String?
    let userData2: String?
}
