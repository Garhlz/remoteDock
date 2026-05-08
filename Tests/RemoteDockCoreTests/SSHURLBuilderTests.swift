import Foundation
import Testing
@testable import RemoteDockCore

struct SSHURLBuilderTests {
    @Test
    func urlWithoutPortUsesDefaultAuthority() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113"
        )

        let url = SSHURLBuilder.url(for: host)

        #expect(url?.absoluteString == "ssh://elaine@100.117.140.113")
    }

    @Test
    func urlIncludesCustomPort() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222
        )

        let url = SSHURLBuilder.url(for: host)

        #expect(url?.absoluteString == "ssh://elaine@100.117.140.113:2222")
    }

    @Test
    func urlUsesUsernameAndHostComponents() {
        let host = RemoteHost(
            name: "Server",
            username: "root",
            address: "server.example.com",
            port: 2200
        )

        let url = SSHURLBuilder.url(for: host)

        #expect(url?.user == "root")
        #expect(url?.host == "server.example.com")
        #expect(url?.port == 2200)
    }
}
