import Foundation

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
        try await performDataRequest(path: "api")
    }

    public func fetchSystemInfo() async throws -> ColorBoxSystemInfo {
        try await performJSONRequest(path: "system/info")
    }

    public func fetchFirmwareInfo() async throws -> ColorBoxFirmwareInfo {
        try await performJSONRequest(path: "system/firmware")
    }

    public func fetchPipelineState() async throws -> ColorBoxPipelineState {
        try await performJSONRequest(path: "pipeline/state")
    }

    public func configureDynamicLUTNode() async throws -> ColorBoxPipelineState {
        let body = try JSONEncoder().encode(ColorBoxDynamicLUTModeUpdate(mode: "dynamic"))
        return try await performJSONRequest(
            path: "pipeline/aja/nodes/3dlut/dynamic",
            method: "PATCH",
            body: body
        )
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
        let body = try JSONEncoder().encode(ColorBoxBooleanToggle(enabled: enabled))
        return try await performJSONRequest(
            path: "pipeline/bypass",
            method: "PATCH",
            body: body
        )
    }

    public func setFalseColor(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        let body = try JSONEncoder().encode(ColorBoxBooleanToggle(enabled: enabled))
        return try await performJSONRequest(
            path: "pipeline/false-color",
            method: "PATCH",
            body: body
        )
    }

    public func listPresets() async throws -> [ColorBoxPresetSummary] {
        try await performJSONRequest(path: "presets")
    }

    public func savePreset(slot: Int, name: String) async throws -> [ColorBoxPresetSummary] {
        let body = try JSONEncoder().encode(ColorBoxPresetMutation(slot: slot, name: name))
        return try await performJSONRequest(
            path: "presets/save",
            method: "POST",
            body: body
        )
    }

    public func recallPreset(slot: Int) async throws -> ColorBoxPipelineState {
        let body = try JSONEncoder().encode(ColorBoxPresetRecall(slot: slot))
        return try await performJSONRequest(
            path: "presets/recall",
            method: "POST",
            body: body
        )
    }

    public func deletePreset(slot: Int) async throws -> [ColorBoxPresetSummary] {
        try await performJSONRequest(
            path: "presets/\(slot)",
            method: "DELETE"
        )
    }

    public func fetchPreviewFrame() async throws -> Data {
        try await performDataRequest(path: "preview/frame")
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
