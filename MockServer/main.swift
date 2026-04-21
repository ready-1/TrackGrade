import Foundation
import Vapor

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let application = try await Application.make(environment)

let configuration = MockColorBoxConfiguration.fromEnvironment()
application.http.server.configuration.hostname = configuration.host
application.http.server.configuration.port = configuration.port

let bonjourAdvertiser = MockColorBoxBonjourAdvertiser(
    configuration: configuration,
    logger: application.logger
)

try MockColorBoxApplication.configure(
    application,
    configuration: configuration
)
bonjourAdvertiser.start()

do {
    try await application.execute()
    bonjourAdvertiser.stop()
    try await application.asyncShutdown()
} catch {
    bonjourAdvertiser.stop()
    try? await application.asyncShutdown()
    throw error
}
