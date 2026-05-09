import Foundation

/// 负责为不同主机配置生成最终 SSH 命令。
///
/// 这个类型解决的是“从配置到真实 shell 命令”的最后一跳：
/// - 基础 SSH 连接命令怎么拼
/// - 是否要带端口
/// - 登录后是否要执行 follow-up 命令
/// - Linux/macOS 与 Windows 主机的 follow-up 行为如何区分
public enum SSHCommandBuilder {
    /// 生成适合在终端中直接执行的 SSH 启动命令。
    ///
    /// 如果没有 follow-up 命令，就是普通 ssh；
    /// 如果有 follow-up 命令，则加 `-t` 让远端分配终端并执行后续命令。
    public static func command(for host: RemoteHost) -> String {
        /// 这里显式指定 `TERM=xterm-256color`，是为了让远端 shell/工具有一个更稳定的终端能力假设。
        let sshPrefix = "TERM=xterm-256color /usr/bin/ssh"
        let sshTarget = host.sshTarget
        let portArgument = host.port.map { "-p \($0) " } ?? ""

        guard let remoteCommand = remoteCommand(for: host) else {
            return "\(sshPrefix) \(portArgument)\(sshTarget)"
        }

        return "\(sshPrefix) \(portArgument)-t \(sshTarget) \(singleQuotedForShell(remoteCommand))"
    }

    /// 选择登录后在远端执行什么命令。
    /// 优先级是：
    /// 1. 用户自定义 startup command
    /// 2. Windows 默认 follow-up
    /// 3. 非 Windows 但显式填写了 remote directory 时的默认 `cd`
    /// 4. 什么都不做
    static func remoteCommand(for host: RemoteHost) -> String? {
        /// follow-up 命令只描述“SSH 成功后的远端动作”，
        /// 它本身不负责连接，而是作为 ssh 的远端命令参数被拼进去。
        if let startupCommand = host.preferredStartupCommand {
            return resolvedStartupCommand(startupCommand, for: host)
        }

        if host.isWindowsHost {
            return defaultWindowsFollowUpCommand(remoteDirectory: host.preferredRemoteDirectory)
        }

        if let remoteDirectory = host.preferredRemoteDirectory {
            return defaultFollowUpCommand(remoteDirectory: remoteDirectory)
        }

        return nil
    }

    /// Unix 类主机的默认 follow-up：
    /// 先进入目标目录，再 `exec` 一个登录 shell，保证后续交互像正常登录一样。
    static func defaultFollowUpCommand(remoteDirectory: String) -> String {
        "cd -- \(singleQuotedForShell(remoteDirectory)) && exec \"${SHELL:-/bin/sh}\" -l"
    }

    /// Windows 主机默认尝试打开 PowerShell 并切换目录。
    /// 这里兼容 scoop 安装、官方安装，以及 PATH 中已有 `pwsh.exe` 的情况。
    static func defaultWindowsFollowUpCommand(remoteDirectory: String?) -> String {
        let pwshArguments: String

        if let remoteDirectory {
            /// Windows 远端命令里需要把 `/` 转成 `\`，并兼容 PowerShell 单引号转义规则。
            let normalizedPath = remoteDirectory.replacingOccurrences(of: "/", with: "\\")
            let escapedPath = normalizedPath.replacingOccurrences(of: "'", with: "''")
            pwshArguments = "-NoLogo -NoExit -Command \"Set-Location -LiteralPath '\(escapedPath)'\""
        } else {
            pwshArguments = "-NoLogo -NoExit"
        }

        /// 这里先尝试常见的固定安装位置，再退回 PATH 中的 `pwsh.exe`。
        let scoopPwsh = "%USERPROFILE%\\scoop\\apps\\pwsh\\current\\pwsh.exe"
        let bundledPwsh = "%ProgramFiles%\\PowerShell\\7\\pwsh.exe"

        return """
        if exist "\(scoopPwsh)" ("\(scoopPwsh)" \(pwshArguments)) else if exist "\(bundledPwsh)" ("\(bundledPwsh)" \(pwshArguments)) else (pwsh.exe \(pwshArguments))
        """
    }

    /// 将模板命令中的 `{remoteDirectory}` 占位符替换成当前主机的最终远程目录。
    static func resolvedStartupCommand(_ startupCommand: String, for host: RemoteHost) -> String {
        startupCommand.replacingOccurrences(of: "{remoteDirectory}", with: host.effectiveRemoteDirectory)
    }

    /// 用单引号包装并转义 shell 文本，尽量避免目录或命令中的特殊字符破坏 shell 解析。
    static func singleQuotedForShell(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
