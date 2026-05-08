import Foundation
import Testing
@testable import RemoteDockCore

struct SSHCommandBuilderTests {
    @Test
    func linuxHostWithoutFollowUpUsesPlainSSHCommand() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113"
        )

        let command = SSHCommandBuilder.command(for: host.withRemoteDirectory(nil))

        #expect(command == "TERM=xterm-256color /usr/bin/ssh elaine@100.117.140.113")
    }

    @Test
    func customPortIsIncludedInSSHCommand() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222
        )

        let command = SSHCommandBuilder.command(for: host.withRemoteDirectory(nil))

        #expect(command == "TERM=xterm-256color /usr/bin/ssh -p 2222 elaine@100.117.140.113")
    }

    @Test
    func linuxRemoteDirectoryProducesFollowUpCommand() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            remoteDirectory: "/srv/project"
        )

        let remoteCommand = SSHCommandBuilder.remoteCommand(for: host)
        let command = SSHCommandBuilder.command(for: host)

        #expect(remoteCommand == #"cd -- '/srv/project' && exec "${SHELL:-/bin/sh}" -l"#)
        #expect(command.hasPrefix("TERM=xterm-256color /usr/bin/ssh -t elaine@100.117.140.113 "))
    }

    @Test
    func startupCommandUsesResolvedRemoteDirectory() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            remoteDirectory: "/srv/project",
            startupCommand: "cd -- {remoteDirectory} && exec zsh -l"
        )

        let remoteCommand = SSHCommandBuilder.remoteCommand(for: host)

        #expect(remoteCommand == "cd -- /srv/project && exec zsh -l")
    }

    @Test
    func singleQuotesAreEscapedInFollowUpCommand() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            remoteDirectory: "/Users/elaine/it's-here"
        )

        let remoteCommand = SSHCommandBuilder.remoteCommand(for: host)

        #expect(remoteCommand == #"cd -- '/Users/elaine/it'"'"'s-here' && exec "${SHELL:-/bin/sh}" -l"#)
    }

    @Test
    func windowsHostWithoutStartupCommandUsesWrapperFallback() {
        let host = RemoteHost(
            name: "Windows Omen16",
            username: "elaine",
            address: "100.102.71.37",
            remoteDirectory: "C:/Users/elaine"
        )

        let remoteCommand = SSHCommandBuilder.remoteCommand(for: host.withStartupCommand(nil))
        let command = SSHCommandBuilder.command(for: host.withStartupCommand(nil))

        #expect(remoteCommand?.contains(#"pwsh.exe -NoLogo -NoExit -Command "Set-Location -LiteralPath 'C:\Users\elaine'""#) == true)
        #expect(command.hasPrefix("TERM=xterm-256color /usr/bin/ssh -t elaine@100.102.71.37 "))
    }
}
