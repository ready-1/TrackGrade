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
