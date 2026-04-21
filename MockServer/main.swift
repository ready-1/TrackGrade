import Foundation
import Vapor

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let application = try await Application.make(environment)

let configuration = MockColorBoxConfiguration.fromEnvironment()
application.http.server.configuration.hostname = configuration.host
application.http.server.configuration.port = configuration.port

try MockColorBoxApplication.configure(
    application,
    configuration: configuration
)

do {
    try await application.execute()
    try await application.asyncShutdown()
} catch {
    try? await application.asyncShutdown()
    throw error
}
