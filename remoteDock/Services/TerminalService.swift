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
        guard isGhosttyInstalled else {
            return "Ghostty is not installed. Install Ghostty first, or use Copy SSH instead."
        }

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

                if let output {
                    if isAutomationPermissionError(output) {
                        return """
                        RemoteDock is not allowed to control Ghostty yet.
                        Open System Settings > Privacy & Security > Automation, then allow RemoteDock to control Ghostty.
                        """
                    }

                    if !output.isEmpty {
                        return "Ghostty automation failed: \(output)"
                    }
                }

                return "Ghostty automation failed with exit code \(process.terminationStatus)."
            }

            return nil
        } catch {
            return "Unable to automate Ghostty: \(error.localizedDescription)"
        }
    }

    private static var isGhosttyInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: ghosttyBundleIdentifier) != nil
    }

    private static func appleScriptArguments(for host: RemoteHost) -> [String] {
        let sshCommand = sshCommand(for: host)
        let isGhosttyRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: ghosttyBundleIdentifier)
            .isEmpty

        if isGhosttyRunning {
            return [
                "-e",
                "tell application \"Ghostty\" to set win to new window",
                "-e",
                "tell application \"Ghostty\" to set term to focused terminal of selected tab of win",
                "-e",
                "tell application \"Ghostty\" to input text \(appleScriptQuoted(sshCommand)) to term",
                "-e",
                "tell application \"Ghostty\" to send key \"enter\" to term"
            ]
        }

        return [
            "-e",
            "tell application \"Ghostty\" to activate",
            "-e",
            "delay 0.2",
            "-e",
            "tell application \"Ghostty\" to set term to focused terminal of selected tab of front window",
            "-e",
            "tell application \"Ghostty\" to input text \(appleScriptQuoted(sshCommand)) to term",
            "-e",
            "tell application \"Ghostty\" to send key \"enter\" to term"
        ]
    }

    private static func sshCommand(for host: RemoteHost) -> String {
        let sshPrefix = "TERM=xterm-256color /usr/bin/ssh"

        guard let remoteCommand = remoteCommand(for: host) else {
            return "\(sshPrefix) \(host.sshTarget)"
        }

        return "\(sshPrefix) -t \(host.sshTarget) \(singleQuotedForShell(remoteCommand))"
    }

    private static func remoteCommand(for host: RemoteHost) -> String? {
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

    private static func defaultFollowUpCommand(remoteDirectory: String) -> String {
        "cd -- \(singleQuotedForShell(remoteDirectory)) && exec \"${SHELL:-/bin/sh}\" -l"
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

    private static func appleScriptQuoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private static func isAutomationPermissionError(_ output: String) -> Bool {
        output.contains("-1743") ||
        output.localizedCaseInsensitiveContains("Not authorized to send Apple events") ||
        output.localizedCaseInsensitiveContains("not allowed assistive access") ||
        output.localizedCaseInsensitiveContains("automation")
    }
}
