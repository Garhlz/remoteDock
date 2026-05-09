import Foundation
import Testing
@testable import RemoteDockCore

/// 覆盖 SSH 命令拼接与 follow-up 行为的测试集合。
///
/// 这些测试主要保护“命令字符串生成”这个高风险区域：
/// 一旦转义、follow-up 或平台分支出错，用户点击打开后就会直接失败。
struct SSHCommandBuilderTests {
    /// 没有目录、没有自定义命令时，应退化成最普通的 ssh 命令。
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

    /// 只要配置了端口，就必须准确落到命令行参数里。
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

    /// Unix 主机有目录时，会生成 `cd && exec shell` 形式的 follow-up。
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

    /// 占位符替换要以最终有效目录为准。
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

    /// 单引号转义是 shell 拼接里最容易出错的点之一。
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

    /// Windows 主机的默认 follow-up 走 PowerShell fallback 逻辑。
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
