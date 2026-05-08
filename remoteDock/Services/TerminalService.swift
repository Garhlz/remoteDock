//
//  TerminalService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import Foundation

enum TerminalService {
    private static let ghosttyBundleIdentifier = "com.mitchellh.ghostty"

    static func openSSHSession(for host: RemoteHost) -> String? {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = appleScriptArguments(for: host)
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let output = String(
                    data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines)

                if let output, !output.isEmpty {
                    return "Ghostty automation failed: \(output)"
                }

                return "Ghostty automation failed with exit code \(process.terminationStatus)."
            }

            return nil
        } catch {
            return "Unable to automate Ghostty: \(error.localizedDescription)"
        }
    }

    private static func appleScriptArguments(for host: RemoteHost) -> [String] {
        let commandSequence = commandSequence(for: host)
        let isGhosttyRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: ghosttyBundleIdentifier)
            .isEmpty

        if isGhosttyRunning {
            return [
                "-e",
                "tell application \"Ghostty\" to set win to new window",
                "-e",
                "tell application \"Ghostty\" to set term to focused terminal of selected tab of win",
            ] + commandSequence.appleScriptEvents(forTerminalVariable: "term")
        }

        return [
            "-e",
            "tell application \"Ghostty\" to activate",
            "-e",
            "delay 0.2",
            "-e",
            "tell application \"Ghostty\" to set term to focused terminal of selected tab of front window",
        ] + commandSequence.appleScriptEvents(forTerminalVariable: "term")
    }

    private static func commandSequence(for host: RemoteHost) -> CommandSequence {
        if let startupCommand = host.preferredStartupCommand {
            return CommandSequence(
                initialCommand: baseSSHCommand(for: host),
                followUpCommand: resolvedStartupCommand(startupCommand, for: host)
            )
        }

        if host.isWindowsHost {
            return CommandSequence(
                initialCommand: baseSSHCommand(for: host),
                followUpCommand: defaultWindowsFollowUpCommand(remoteDirectory: host.preferredRemoteDirectory)
            )
        }

        if let remoteDirectory = host.preferredRemoteDirectory {
            return CommandSequence(
                initialCommand: baseSSHCommand(for: host),
                followUpCommand: defaultFollowUpCommand(for: host, remoteDirectory: remoteDirectory)
            )
        }

        return CommandSequence(initialCommand: baseSSHCommand(for: host))
    }

    private static func baseSSHCommand(for host: RemoteHost) -> String {
        let sshPrefix = "TERM=xterm-256color /usr/bin/ssh"

        return "\(sshPrefix) \(host.sshTarget)"
    }

    private static func defaultFollowUpCommand(for host: RemoteHost, remoteDirectory: String) -> String {
        return "cd -- \(singleQuotedForShell(remoteDirectory))"
    }

    private static func defaultWindowsFollowUpCommand(remoteDirectory: String?) -> String {
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

    private static func resolvedStartupCommand(_ startupCommand: String, for host: RemoteHost) -> String {
        startupCommand.replacingOccurrences(of: "{remoteDirectory}", with: host.effectiveRemoteDirectory)
    }

    private static func singleQuotedForShell(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private static func doubleQuotedForShell(_ value: String) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")

        return "\"\(escapedValue)\""
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

private struct CommandSequence {
    let initialCommand: String
    let followUpCommand: String?

    init(initialCommand: String, followUpCommand: String? = nil) {
        self.initialCommand = initialCommand
        self.followUpCommand = followUpCommand
    }

    func appleScriptEvents(forTerminalVariable terminalVariable: String) -> [String] {
        var events = [
            "-e",
            "tell application \"Ghostty\" to input text \(appleScriptQuoted(initialCommand)) to \(terminalVariable)",
            "-e",
            "tell application \"Ghostty\" to send key \"enter\" to \(terminalVariable)"
        ]

        if let followUpCommand {
            events.append(contentsOf: [
                "-e",
                "delay 1.5",
                "-e",
                "tell application \"Ghostty\" to input text \(appleScriptQuoted(followUpCommand)) to \(terminalVariable)",
                "-e",
                "tell application \"Ghostty\" to send key \"enter\" to \(terminalVariable)"
            ])
        }

        return events
    }

    private func appleScriptQuoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
