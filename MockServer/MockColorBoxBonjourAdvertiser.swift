import Foundation
import Logging

final class MockColorBoxBonjourAdvertiser: NSObject, NetServiceDelegate {
    private let logger: Logger
    private let service: NetService

    init(
        configuration: MockColorBoxConfiguration,
        logger: Logger
    ) {
        self.logger = logger
        self.service = NetService(
            domain: "local.",
            type: "_http._tcp.",
            name: configuration.bonjourServiceName,
            port: Int32(configuration.port)
        )
        super.init()
        service.delegate = self
        service.setTXTRecord(
            NetService.data(
                fromTXTRecord: [
                    "vendor": Data("AJA".utf8),
                    "product": Data("ColorBox".utf8),
                    "path": Data("/".utf8),
                    "serial": Data("MOCK1SC001145".utf8),
                ]
            )
        )
    }

    func start() {
        service.publish()
    }

    func stop() {
        service.stop()
    }

    func netServiceDidPublish(_ sender: NetService) {
        logger.notice(
            "Published Bonjour service \(sender.name) as \(sender.type)\(sender.domain)"
        )
    }

    func netService(
        _ sender: NetService,
        didNotPublish errorDict: [String: NSNumber]
    ) {
        logger.warning(
            "Failed to publish Bonjour service \(sender.name): \(errorDict)"
        )
    }
}
