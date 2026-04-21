import Foundation
import Network

struct DiscoveredColorBoxDevice: Identifiable, Equatable, Sendable {
    let serviceName: String
    let address: String

    var id: String {
        address
    }
}

@MainActor
final class TrackGradeDeviceDiscovery {
    var onDevicesChanged: @MainActor ([DiscoveredColorBoxDevice]) -> Void = { _ in }

    private let queue = DispatchQueue(label: "com.example.trackgrade.discovery")
    private var browser: NWBrowser?

    func start() {
        stop()

        let parameters = NWParameters.tcp
        let browser = NWBrowser(
            for: .bonjour(type: "_http._tcp", domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { state in
            if case let .failed(error) = state {
                print("TrackGrade discovery failed: \(error)")
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let devices = results.compactMap(Self.makeDevice(from:))
                .filter { $0.serviceName.localizedCaseInsensitiveContains("colorbox") }
                .sorted { $0.serviceName.localizedStandardCompare($1.serviceName) == .orderedAscending }

            Task { @MainActor in
                self?.onDevicesChanged(devices)
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func restart() {
        start()
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    nonisolated private static func makeDevice(
        from result: NWBrowser.Result
    ) -> DiscoveredColorBoxDevice? {
        switch result.endpoint {
        case let .hostPort(host, port):
            return DiscoveredColorBoxDevice(
                serviceName: host.debugDescription,
                address: "http://\(host.debugDescription):\(port.rawValue)"
            )
        case let .service(name, _, domain, _):
            let normalizedDomain = domain
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let hostSuffix = normalizedDomain.isEmpty ? "local" : normalizedDomain
            return DiscoveredColorBoxDevice(
                serviceName: name,
                address: "http://\(name).\(hostSuffix)"
            )
        default:
            return nil
        }
    }
}
