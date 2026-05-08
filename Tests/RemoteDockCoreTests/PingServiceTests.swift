import Foundation
import Testing
@testable import RemoteDockCore

struct PingServiceTests {
    @Test
    func checkReturnsTrueWhenRunnerSucceeds() async {
        defer { PingService.resetDependencies() }

        PingService.setRunPing { address in
            address == "100.117.140.113"
        }

        let result = await PingService.check(address: "100.117.140.113")

        #expect(result)
    }

    @Test
    func checkReturnsFalseForNonResponsiveHost() async {
        defer { PingService.resetDependencies() }

        PingService.setRunPing { _ in false }

        let result = await PingService.check(address: "192.168.1.50")

        #expect(result == false)
    }

    @Test
    func checkPassesAddressToInjectedRunner() async {
        defer { PingService.resetDependencies() }

        var receivedAddress: String?
        PingService.setRunPing { address in
            receivedAddress = address
            return true
        }

        _ = await PingService.check(address: "server.example.com")

        #expect(receivedAddress == "server.example.com")
    }
}
