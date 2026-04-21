import CryptoKit
import Foundation
#if canImport(ColorBoxOpenAPI)
import ColorBoxOpenAPI
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
#endif

public struct ColorBoxAPIClient: Sendable {
    public let endpoint: ColorBoxEndpoint
    public let credentials: ColorBoxCredentials?
    public let urlSession: URLSession

    public init(
        endpoint: ColorBoxEndpoint,
        credentials: ColorBoxCredentials? = nil,
        urlSession: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.credentials = credentials
        self.urlSession = urlSession
    }

    public func fetchOpenAPIDocument() async throws -> Data {
        do {
            return try await performDataRequest(path: "api/openapi.yaml")
        } catch {
            return try await performDataRequest(path: "api")
        }
    }

    public func fetchSystemInfo() async throws -> ColorBoxSystemInfo {
        do {
            return try await fetchSystemInfoV2()
        } catch {
            return try await performJSONRequest(path: "system/info")
        }
    }

    public func fetchFirmwareInfo() async throws -> ColorBoxFirmwareInfo {
        do {
            return try await fetchFirmwareInfoV2()
        } catch {
            return try await performJSONRequest(path: "system/firmware")
        }
    }

    public func fetchPipelineState() async throws -> ColorBoxPipelineState {
        do {
            return try await fetchPipelineStateV2()
        } catch {
            return try await performJSONRequest(path: "pipeline/state")
        }
    }

    public func configureDynamicLUTNode() async throws -> ColorBoxPipelineState {
        do {
            return try await configureDynamicLUTNodeV2()
        } catch {
            let body = try JSONEncoder().encode(ColorBoxDynamicLUTModeUpdate(mode: "dynamic"))
            return try await performJSONRequest(
                path: "pipeline/aja/nodes/3dlut/dynamic",
                method: "PATCH",
                body: body
            )
        }
    }

    public func uploadDynamicLUT(
        cubeText: String,
        sequenceID: Int
    ) async throws -> ColorBoxDynamicLUTUploadResponse {
        var request = try makeRequest(
            path: "pipeline/aja/nodes/3dlut/dynamic",
            method: "PUT",
            body: Data(cubeText.utf8),
            contentType: "text/plain"
        )
        request.setValue(String(sequenceID), forHTTPHeaderField: "X-TrackGrade-Sequence")
        return try await perform(request: request)
    }

    public func setBypass(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        do {
            return try await setBypassV2(enabled)
        } catch {
            let body = try JSONEncoder().encode(ColorBoxBooleanToggle(enabled: enabled))
            return try await performJSONRequest(
                path: "pipeline/bypass",
                method: "PATCH",
                body: body
            )
        }
    }

    public func setFalseColor(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        let body = try JSONEncoder().encode(ColorBoxBooleanToggle(enabled: enabled))
        do {
            return try await performJSONRequest(
                path: "pipeline/false-color",
                method: "PATCH",
                body: body
            )
        } catch let error as ColorBoxAPIError {
            if case .unexpectedStatus(code: 404, _) = error {
                throw ColorBoxAPIError.unsupportedFeature(
                    "False color is not exposed by the ColorBox `/v2` API on firmware 3.0.0.24."
                )
            }

            throw error
        }
    }

    public func listPresets() async throws -> [ColorBoxPresetSummary] {
        do {
            return try await listPresetsV2()
        } catch {
            return try await performJSONRequest(path: "presets")
        }
    }

    public func savePreset(slot: Int, name: String) async throws -> [ColorBoxPresetSummary] {
        do {
            try await performLibraryActionV2(
                library: "systemPreset",
                entry: slot,
                action: "StoreEntry"
            )
            try await performLibraryActionV2(
                library: "systemPreset",
                entry: slot,
                action: "SetUserName",
                data: name
            )
            return try await listPresetsV2()
        } catch {
            let body = try JSONEncoder().encode(ColorBoxPresetMutation(slot: slot, name: name))
            return try await performJSONRequest(
                path: "presets/save",
                method: "POST",
                body: body
            )
        }
    }

    public func recallPreset(slot: Int) async throws -> ColorBoxPipelineState {
        do {
            try await performLibraryActionV2(
                library: "systemPreset",
                entry: slot,
                action: "RecallEntry"
            )
            var pipelineState = try await fetchPipelineStateV2()
            pipelineState = ColorBoxPipelineState(
                bypassEnabled: pipelineState.bypassEnabled,
                falseColorEnabled: pipelineState.falseColorEnabled,
                dynamicLUTMode: pipelineState.dynamicLUTMode,
                lastRecalledPresetSlot: slot
            )
            return pipelineState
        } catch {
            let body = try JSONEncoder().encode(ColorBoxPresetRecall(slot: slot))
            return try await performJSONRequest(
                path: "presets/recall",
                method: "POST",
                body: body
            )
        }
    }

    public func deletePreset(slot: Int) async throws -> [ColorBoxPresetSummary] {
        do {
            try await performLibraryActionV2(
                library: "systemPreset",
                entry: slot,
                action: "DeleteEntry"
            )
            return try await listPresetsV2()
        } catch {
            return try await performJSONRequest(
                path: "presets/\(slot)",
                method: "DELETE"
            )
        }
    }

    public func fetchPreviewFrame() async throws -> Data {
        do {
            return try await fetchPreviewFrameV2()
        } catch {
            return try await performDataRequest(path: "preview/frame")
        }
    }

    private func fetchSystemInfoV2() async throws -> ColorBoxSystemInfo {
        let hostName: String

        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()

        async let buildInfoOutput = client.getBuildInfo()
        async let systemConfigOutput = client.getSystemConfig()

        _ = try (try await buildInfoOutput).ok.body.json
        let systemConfig = try (try await systemConfigOutput).ok.body.json
        hostName = normalizedHostName(from: systemConfig.hostName)
        #else
        async let buildInfo: V2BuildInfo = performJSONRequest(path: "v2/buildInfo")
        async let systemConfig: V2SystemConfig = performJSONRequest(path: "v2/system/config")

        _ = try await buildInfo
        hostName = normalizedHostName(from: try await systemConfig.hostName)
        #endif

        return ColorBoxSystemInfo(
            productName: "AJA ColorBox",
            modelName: "ColorBox",
            serialNumber: serialNumber(from: hostName),
            deviceUUID: stableDeviceUUID(for: hostName),
            hostName: hostName
        )
    }

    private func fetchFirmwareInfoV2() async throws -> ColorBoxFirmwareInfo {
        let buildVersion: String?
        let buildIdentifier: String?
        let statusRunningVersion: String?
        let statusMainbootVersion: String?

        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()

        async let buildInfoOutput = client.getBuildInfo()
        async let systemStatusOutput = client.getSystemStatus()

        let buildInfo = try (try await buildInfoOutput).ok.body.json
        let systemStatus = try (try await systemStatusOutput).ok.body.json
        buildVersion = buildInfo.appVersion
        buildIdentifier = firstNonEmpty([buildInfo.repoident, buildInfo.buildType, buildInfo.date])
        statusRunningVersion = systemStatus.runningVersion
        statusMainbootVersion = systemStatus.mainbootVersion
        #else
        async let buildInfo: V2BuildInfo = performJSONRequest(path: "v2/buildInfo")
        async let systemStatus: V2SystemStatus = performJSONRequest(path: "v2/system/status")

        let resolvedBuildInfo = try await buildInfo
        let resolvedSystemStatus = try await systemStatus
        buildVersion = resolvedBuildInfo.appVersion
        buildIdentifier = firstNonEmpty([
            resolvedBuildInfo.repoident,
            resolvedBuildInfo.buildType,
            resolvedBuildInfo.date,
        ])
        statusRunningVersion = resolvedSystemStatus.runningVersion
        statusMainbootVersion = resolvedSystemStatus.mainbootVersion
        #endif

        let version = firstNonEmpty([
            statusRunningVersion,
            statusMainbootVersion,
            buildVersion,
        ]) ?? "unknown"
        let build = firstNonEmpty([
            buildIdentifier,
        ]) ?? "unknown"

        return ColorBoxFirmwareInfo(
            version: version,
            build: build
        )
    }

    private func fetchPipelineStateV2() async throws -> ColorBoxPipelineState {
        let bypassEnabled: Bool
        let dynamicMode: String

        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()

        async let routingOutput = client.getRouting()
        async let stagesOutput = client.getPipelineStages()

        let routing = try (try await routingOutput).ok.body.json
        let stages = try (try await stagesOutput).ok.body.json
        bypassEnabled = routing.pipelineBypassUser ?? routing.pipelineBypassButton ?? false
        dynamicMode = dynamicLUTMode(from: stages.lut3d1)
        #else
        async let routing: V2Routing = performJSONRequest(path: "v2/routing")
        async let stages: V2PipelineStages = performJSONRequest(path: "v2/pipelineStages")

        let resolvedRouting = try await routing
        let resolvedStages = try await stages
        bypassEnabled = resolvedRouting.pipelineBypassUser ?? resolvedRouting.pipelineBypassButton ?? false
        dynamicMode = dynamicLUTMode(from: resolvedStages.lut3d1)
        #endif

        return ColorBoxPipelineState(
            bypassEnabled: bypassEnabled,
            falseColorEnabled: false,
            dynamicLUTMode: dynamicMode
        )
    }

    private func configureDynamicLUTNodeV2() async throws -> ColorBoxPipelineState {
        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()
        let currentStages = try (try await client.getPipelineStages()).ok.body.json

        var updatedStages = currentStages
        var updatedStage = currentStages.lut3d1 ?? Components.Schemas.Stage()
        updatedStage.dynamic = true
        updatedStage.enabled = true
        updatedStage.libraryEntry = 0
        updatedStages.lut3d1 = updatedStage

        _ = try (try await client.setPipelineStages(
            body: .json(updatedStages)
        )).ok
        #else
        var currentStages: V2PipelineStages = try await performJSONRequest(path: "v2/pipelineStages")
        var updatedStage = currentStages.lut3d1 ?? V2Stage()
        updatedStage.dynamic = true
        updatedStage.enabled = true
        updatedStage.libraryEntry = 0
        currentStages.lut3d1 = updatedStage
        let body = try JSONEncoder().encode(currentStages)
        try await performNoContentRequest(
            path: "v2/pipelineStages",
            method: "PUT",
            body: body
        )
        #endif

        return try await fetchPipelineStateV2()
    }

    private func setBypassV2(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()
        let currentRouting = try (try await client.getRouting()).ok.body.json

        var updatedRouting = currentRouting
        updatedRouting.pipelineBypassUser = enabled

        _ = try (try await client.setRouting(
            body: .json(updatedRouting)
        )).ok
        #else
        var currentRouting: V2Routing = try await performJSONRequest(path: "v2/routing")
        currentRouting.pipelineBypassUser = enabled
        let body = try JSONEncoder().encode(currentRouting)
        try await performNoContentRequest(
            path: "v2/routing",
            method: "PUT",
            body: body
        )
        #endif

        return try await fetchPipelineStateV2()
    }

    private func listPresetsV2() async throws -> [ColorBoxPresetSummary] {
        let entries: [V2LibraryEntry]

        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()
        let liveEntries = try (try await client.getSystemPresetLibrary()).ok.body.json
        entries = liveEntries.map { entry in
            V2LibraryEntry(
                userName: entry.userName,
                fileName: entry.fileName
            )
        }
        #else
        entries = try await performJSONRequest(path: "v2/systemPresetLibrary")
        #endif

        return entries.enumerated().compactMap { index, entry in
            let trimmedUserName = entry.userName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFileName = entry.fileName?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (trimmedUserName?.isEmpty == false) || (trimmedFileName?.isEmpty == false) else {
                return nil
            }

            let fallbackName = entry.fileName?
                .replacingOccurrences(of: ".preset", with: "")
                ?? "Preset \(index + 1)"
            return ColorBoxPresetSummary(
                slot: index + 1,
                name: firstNonEmpty([entry.userName, fallbackName]) ?? "Preset \(index + 1)"
            )
        }
    }

    private func performLibraryActionV2(
        library: String,
        entry: Int,
        action: String,
        data: String = ""
    ) async throws {
        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()
        let payload = Components.Schemas.LibraryControl(
            library: Components.Schemas.Library(rawValue: library),
            entry: entry,
            action: Components.Schemas.LibraryAction(rawValue: action),
            data: data,
            errorMsg: ""
        )

        _ = try (try await client.setLibraryControl(
            body: .json(payload)
        )).ok

        let state = try (try await client.getLibraryControl()).ok.body.json
        if let errorMessage = state.errorMsg?.trimmingCharacters(in: .whitespacesAndNewlines),
           errorMessage.isEmpty == false {
            throw ColorBoxAPIError.unexpectedStatus(code: 409, body: errorMessage)
        }
        #else
        let payload = V2LibraryControl(
            library: library,
            entry: entry,
            action: action,
            data: data,
            errorMsg: ""
        )
        let body = try JSONEncoder().encode(payload)
        try await performNoContentRequest(
            path: "v2/libraryControl",
            method: "PUT",
            body: body
        )

        let state: V2LibraryControl = try await performJSONRequest(path: "v2/libraryControl")
        if let errorMessage = state.errorMsg?.trimmingCharacters(in: .whitespacesAndNewlines),
           errorMessage.isEmpty == false {
            throw ColorBoxAPIError.unexpectedStatus(code: 409, body: errorMessage)
        }
        #endif
    }

    private func fetchPreviewFrameV2() async throws -> Data {
        #if canImport(ColorBoxOpenAPI)
        let client = makeGeneratedClient()
        let preview = try (try await client.getPreviewImage()).ok.body.json

        guard let image = preview.image else {
            throw ColorBoxAPIError.invalidResponse
        }

        return Data(image.data)
        #else
        let preview: V2Preview = try await performJSONRequest(path: "v2/preview")
        guard let image = preview.image,
              let data = Data(base64Encoded: image, options: .ignoreUnknownCharacters) else {
            throw ColorBoxAPIError.invalidResponse
        }

        return data
        #endif
    }

    private func normalizedHostName(from candidate: String?) -> String {
        if let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
           candidate.isEmpty == false {
            return candidate
        }

        return endpoint.baseURL.host ?? endpoint.baseURL.absoluteString
    }

    private func serialNumber(from hostName: String) -> String {
        if hostName.hasPrefix("ColorBox-") {
            return String(hostName.dropFirst("ColorBox-".count))
        }

        return hostName
    }

    private func stableDeviceUUID(for hostName: String) -> UUID {
        let digest = SHA256.hash(data: Data(hostName.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func dynamicLUTMode(from stage: V2Stage?) -> String {
        guard let stage else {
            return "unknown"
        }

        if stage.dynamic == true {
            return "dynamic"
        }

        if stage.enabled == true {
            return "static"
        }

        return "disabled"
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values.first { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }

            return value.isEmpty == false
        } ?? nil
    }

    private func performJSONRequest<Response: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Response {
        let request = try makeRequest(path: path, method: method, body: body)
        return try await perform(request: request)
    }

    private func performDataRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let request = try makeRequest(path: path, method: method, body: body)
        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func performNoContentRequest(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String = "application/json"
    ) async throws {
        let request = try makeRequest(
            path: path,
            method: method,
            body: body,
            contentType: contentType
        )
        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
    }

    private func perform<Response: Decodable>(
        request: URLRequest
    ) async throws -> Response {
        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ColorBoxAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 401:
            throw ColorBoxAPIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            throw ColorBoxAPIError.unexpectedStatus(
                code: httpResponse.statusCode,
                body: body
            )
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String = "application/json"
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: endpoint.baseURL) else {
            throw ColorBoxAPIError.invalidEndpoint(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = endpoint.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if let credentials {
            let auth = "\(credentials.username):\(credentials.password)"
            let encoded = Data(auth.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

#if canImport(ColorBoxOpenAPI)
private extension ColorBoxAPIClient {
    func makeGeneratedClient() -> Client {
        let serverURL = endpoint.baseURL.appendingPathComponent("v2", isDirectory: true)
        let transport = URLSessionTransport(
            configuration: .init(session: urlSession)
        )

        return Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: authenticationMiddlewares()
        )
    }

    func authenticationMiddlewares() -> [any ClientMiddleware] {
        guard let credentials else {
            return []
        }

        return [ColorBoxAuthenticationMiddleware(credentials: credentials)]
    }

    func dynamicLUTMode(from stage: Components.Schemas.Stage?) -> String {
        guard let stage else {
            return "unknown"
        }

        if stage.dynamic == true {
            return "dynamic"
        }

        if stage.enabled == true {
            return "static"
        }

        return "disabled"
    }
}

private struct ColorBoxAuthenticationMiddleware: ClientMiddleware {
    let credentials: ColorBoxCredentials

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request

        if let apiKey = credentials.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           apiKey.isEmpty == false,
           let apiKeyHeader = HTTPField.Name("X-API-KEY") {
            request.headerFields[apiKeyHeader] = apiKey
        }

        let password = credentials.password.trimmingCharacters(in: .whitespacesAndNewlines)
        if password.isEmpty == false {
            let authorizationValue = "\(credentials.username):\(credentials.password)"
            let encoded = Data(authorizationValue.utf8).base64EncodedString()
            request.headerFields[.authorization] = "Basic \(encoded)"
        }

        return try await next(request, body, baseURL)
    }
}
#endif

private struct V2BuildInfo: Decodable {
    let date: String?
    let repoident: String?
    let buildType: String?
    let appVersion: String?
}

private struct V2SystemConfig: Decodable {
    let hostName: String?
}

private struct V2SystemStatus: Decodable {
    let mainbootVersion: String?
    let runningVersion: String?
}

private struct V2Routing: Codable {
    var mode: String?
    var previewTap: String?
    var pipelineBypassButton: Bool?
    var pipelineBypassUser: Bool?
}

private struct V2PipelineStages: Codable {
    var lut3d1: V2Stage?

    enum CodingKeys: String, CodingKey {
        case lut3d1 = "lut3d_1"
    }
}

private struct V2Stage: Codable {
    var enabled: Bool?
    var dynamic: Bool?
    var libraryEntry: Int?
}

private struct V2LibraryEntry: Decodable {
    let userName: String?
    let fileName: String?
}

private struct V2LibraryControl: Codable {
    let library: String?
    let entry: Int?
    let action: String?
    let data: String?
    let errorMsg: String?
}

private struct V2Preview: Decodable {
    let image: String?
}
