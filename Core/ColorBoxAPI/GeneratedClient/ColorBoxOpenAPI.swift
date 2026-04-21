import Foundation
import OpenAPIURLSession

public enum ColorBoxOpenAPIConfiguration {
    public static func makeClient(serverURL: URL) -> Client {
        Client(
            serverURL: serverURL,
            transport: URLSessionTransport()
        )
    }
}
