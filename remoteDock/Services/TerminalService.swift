//
//  TerminalService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import Foundation
import RemoteDockCore

enum TerminalService {
    enum Error: LocalizedError {
        case ghosttyNotInstalled
        case automationPermissionDenied
        case automationFailed(output: String?, exitCode: Int32)
        case processError(String)

        var errorDescription: String? {
            switch self {
            case .ghosttyNotInstalled:
                "Ghostty is not installed. Install Ghostty first, or use Copy SSH instead."
            case .automationPermissionDenied:
                """
                RemoteDock is not allowed to control Ghostty yet.
                Open System Settings > Privacy & Security > Automation, then allow RemoteDock to control Ghostty.
                """
            case .automationFailed(let output, let exitCode):
                if let output, !output.isEmpty {
                    "Ghostty automation failed: \(output)"
                } else {
                    "Ghostty automation failed with exit code \(exitCode)."
                }
            case .processError(let description):
                "Unable to automate Ghostty: \(description)"
            }
        }
    }

    private static let ghosttyBundleIdentifier = "com.mitchellh.ghostty"

    static func openSSHSession(for host: RemoteHost) -> Error? {
        guard isGhosttyInstalled else {
            return .ghosttyNotInstalled
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
                        return .automationPermissionDenied
                    }
                }

                return .automationFailed(output: output, exitCode: process.terminationStatus)
            }

            return nil
        } catch {
            return .processError(error.localizedDescription)
        }
    }

    private static var isGhosttyInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: ghosttyBundleIdentifier) != nil
    }

    private static func appleScriptArguments(for host: RemoteHost) -> [String] {
        let sshCommand = SSHCommandBuilder.command(for: host)
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
