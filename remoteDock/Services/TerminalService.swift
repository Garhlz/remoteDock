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
        let sshCommand = "/usr/bin/ssh \(host.username)@\(host.address)"
        let escapedCommand = appleScriptQuoted(sshCommand)
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
                "tell application \"Ghostty\" to input text \(escapedCommand) to term",
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
            "tell application \"Ghostty\" to input text \(escapedCommand) to term",
            "-e",
            "tell application \"Ghostty\" to send key \"enter\" to term"
        ]
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
