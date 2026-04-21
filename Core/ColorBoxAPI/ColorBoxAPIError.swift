import Foundation

public enum ColorBoxAPIError: Error, LocalizedError, Sendable, Equatable {
    case invalidEndpoint(String)
    case invalidResponse
    case unauthorized
    case unexpectedStatus(code: Int, body: String?)

    public var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(path):
            return "Invalid ColorBox endpoint path: \(path)"
        case .invalidResponse:
            return "The ColorBox response was not a valid HTTP response."
        case .unauthorized:
            return "The ColorBox rejected the request with 401 Unauthorized."
        case let .unexpectedStatus(code, body):
            if let body, body.isEmpty == false {
                return "Unexpected HTTP status \(code): \(body)"
            }

            return "Unexpected HTTP status \(code)."
        }
    }
}
