import Foundation
import Testing
@testable import RemoteDockCore

struct RemoteHostTests {
    @Test
    func linuxHostUsesHomeDirectoryByDefault() {
        let host = RemoteHost(
            name: "Arch T480s",
            username: "elaine",
            address: "100.117.140.113"
        )

        #expect(host.suggestedRemoteDirectory == "/home/elaine")
        #expect(host.effectiveRemoteDirectory == "/home/elaine")
        #expect(host.isWindowsHost == false)
    }

    @Test
    func macHostUsesUsersDirectoryByDefault() {
        let host = RemoteHost(
            name: "Mac mini",
            username: "elaine",
            address: "192.168.1.2"
        )

        #expect(host.suggestedRemoteDirectory == "/Users/elaine")
    }

    @Test
    func windowsHostUsesWindowsDirectoryAndWrapperSuggestion() {
        let host = RemoteHost(
            name: "Windows Omen16",
            username: "elaine",
            address: "100.102.71.37"
        )

        #expect(host.isWindowsHost)
        #expect(host.suggestedRemoteDirectory == "C:/Users/elaine")
        #expect(host.suggestedStartupCommand == #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#)
    }

    @Test
    func windowsPathMarksHostAsWindows() {
        let host = RemoteHost(
            name: "Workstation",
            username: "elaine",
            address: "192.168.1.9",
            remoteDirectory: "C:/Users/elaine"
        )

        #expect(host.isWindowsHost)
        #expect(host.effectiveRemoteDirectory == "C:/Users/elaine")
    }

    @Test
    func tailscaleIPv4AddressIsRecognized() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113"
        )

        #expect(host.usesTailscale)
    }

    @Test
    func tailscaleMagicDnsNameIsRecognized() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "arch-t480s.tail123.ts.net"
        )

        #expect(host.usesTailscale)
    }

    @Test
    func nonTailscaleAddressIsNotRecognized() {
        let host = RemoteHost(
            name: "NAS",
            username: "elaine",
            address: "192.168.1.20"
        )

        #expect(host.usesTailscale == false)
    }

    @Test
    func sshFieldsUseDefaultPortWhenPortIsMissing() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113"
        )

        #expect(host.port == nil)
        #expect(host.sshTarget == "elaine@100.117.140.113")
        #expect(host.sshAuthority == "elaine@100.117.140.113")
        #expect(host.displayAddress == "elaine@100.117.140.113")
        #expect(host.sshCommand == "ssh elaine@100.117.140.113")
    }

    @Test
    func sshFieldsIncludeCustomPort() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222
        )

        #expect(host.port == 2222)
        #expect(host.sshTarget == "elaine@100.117.140.113")
        #expect(host.sshAuthority == "elaine@100.117.140.113:2222")
        #expect(host.displayAddress == "elaine@100.117.140.113:2222")
        #expect(host.sshCommand == "ssh -p 2222 elaine@100.117.140.113")
    }

    @Test
    func invalidPortIsNormalizedToNil() {
        let zeroPortHost = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 0
        )
        let tooLargePortHost = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 70000
        )

        #expect(zeroPortHost.port == nil)
        #expect(tooLargePortHost.port == nil)
    }

    @Test
    func remoteDirectoryAndStartupCommandAreTrimmedAndEmptyValuesBecomeNil() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            remoteDirectory: "  /srv/project  ",
            startupCommand: "  exec zsh -l  "
        )
        let emptyValuesHost = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            remoteDirectory: "   ",
            startupCommand: "\n"
        )

        #expect(host.preferredRemoteDirectory == "/srv/project")
        #expect(host.preferredStartupCommand == "exec zsh -l")
        #expect(emptyValuesHost.preferredRemoteDirectory == nil)
        #expect(emptyValuesHost.preferredStartupCommand == nil)
    }

    @Test
    func withRemoteDirectoryPreservesOtherFields() {
        let original = RemoteHost(
            id: UUID(),
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222,
            remoteDirectory: "/home/elaine",
            startupCommand: "exec zsh -l"
        )

        let updated = original.withRemoteDirectory("/srv/project")

        #expect(updated.id == original.id)
        #expect(updated.name == original.name)
        #expect(updated.username == original.username)
        #expect(updated.address == original.address)
        #expect(updated.port == original.port)
        #expect(updated.preferredRemoteDirectory == "/srv/project")
        #expect(updated.preferredStartupCommand == original.preferredStartupCommand)
    }

    @Test
    func withStartupCommandPreservesOtherFields() {
        let original = RemoteHost(
            id: UUID(),
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222,
            remoteDirectory: "/home/elaine",
            startupCommand: "exec zsh -l"
        )

        let updated = original.withStartupCommand("cd /srv/project && exec bash -l")

        #expect(updated.id == original.id)
        #expect(updated.name == original.name)
        #expect(updated.username == original.username)
        #expect(updated.address == original.address)
        #expect(updated.port == original.port)
        #expect(updated.preferredRemoteDirectory == original.preferredRemoteDirectory)
        #expect(updated.preferredStartupCommand == "cd /srv/project && exec bash -l")
    }

    @Test
    func fullDetailsTextIncludesPortInformation() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222,
            remoteDirectory: "/home/elaine"
        )

        #expect(host.fullDetailsText.contains("Port: 2222"))
        #expect(host.fullDetailsText.contains("SSH Target: elaine@100.117.140.113"))
    }
}
