import XCTest
import OpenAPIURLSession
@testable import ColorBoxOpenAPI

final class GeneratedColorBoxClientSmokeTests: XCTestCase {
    func testGeneratedClientInitializesWithLiveServerBase() throws {
        let client = Client(
            serverURL: try XCTUnwrap(URL(string: "http://172.29.14.51/v2")),
            transport: URLSessionTransport()
        )

        XCTAssertNotNil(client)
    }

    func testConfigurationHelperCreatesClient() throws {
        let client = ColorBoxOpenAPIConfiguration.makeClient(
            serverURL: try XCTUnwrap(URL(string: "http://172.29.14.51/v2"))
        )

        XCTAssertNotNil(client)
    }
}
