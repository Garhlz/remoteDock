import Foundation

public enum SSHCommandBuilder {
    public static func command(for host: RemoteHost) -> String {
        let sshPrefix = "TERM=xterm-256color /usr/bin/ssh"
        let sshTarget = host.sshTarget
        let portArgument = host.port.map { "-p \($0) " } ?? ""

        guard let remoteCommand = remoteCommand(for: host) else {
            return "\(sshPrefix) \(portArgument)\(sshTarget)"
        }

        return "\(sshPrefix) \(portArgument)-t \(sshTarget) \(singleQuotedForShell(remoteCommand))"
    }

    static func remoteCommand(for host: RemoteHost) -> String? {
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

    static func defaultFollowUpCommand(remoteDirectory: String) -> String {
        "cd -- \(singleQuotedForShell(remoteDirectory)) && exec \"${SHELL:-/bin/sh}\" -l"
    }

    static func defaultWindowsFollowUpCommand(remoteDirectory: String?) -> String {
        let pwshArguments: String

        if let remoteDirectory {
            let normalizedPath = remoteDirectory.replacingOccurrences(of: "/", with: "\\")
            let escapedPath = normalizedPath.replacingOccurrences(of: "'", with: "''")
            pwshArguments = "-NoLogo -NoExit -Command \"Set-Location -LiteralPath '\(escapedPath)'\""
        } else {
            pwshArguments = "-NoLogo -NoExit"
        }

        let scoopPwsh = "%USERPROFILE%\\scoop\\apps\\pwsh\\current\\pwsh.exe"
        let bundledPwsh = "%ProgramFiles%\\PowerShell\\7\\pwsh.exe"

        return """
        if exist "\(scoopPwsh)" ("\(scoopPwsh)" \(pwshArguments)) else if exist "\(bundledPwsh)" ("\(bundledPwsh)" \(pwshArguments)) else (pwsh.exe \(pwshArguments))
        """
    }

    static func resolvedStartupCommand(_ startupCommand: String, for host: RemoteHost) -> String {
        startupCommand.replacingOccurrences(of: "{remoteDirectory}", with: host.effectiveRemoteDirectory)
    }

    static func singleQuotedForShell(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
