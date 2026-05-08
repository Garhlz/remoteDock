//
//  VSCodeService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import Foundation

enum VSCodeService {
    static func openRemoteFolder(for host: RemoteHost) -> String? {
        guard let cli = availableCLI else {
            return "Visual Studio Code is not installed."
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = cli.executableURL
        process.arguments = [
            "--new-window",
            "--remote",
            "ssh-remote+\(host.sshTarget)",
            host.vscodeRemoteDirectory
        ]
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
                    return "Unable to launch Visual Studio Code: \(output)"
                }

                return "Unable to launch Visual Studio Code."
            }

            return nil
        } catch {
            return "Unable to launch Visual Studio Code: \(error.localizedDescription)"
        }
    }

    private struct VSCodeCLI {
        let executableURL: URL
    }

    private static let cliCandidates: [(bundleIdentifier: String, executableName: String)] = [
        ("com.microsoft.VSCode", "code"),
        ("com.microsoft.VSCodeInsiders", "code-insiders")
    ]

    private static var availableCLI: VSCodeCLI? {
        cliCandidates.lazy.compactMap { candidate in
            guard let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: candidate.bundleIdentifier
            ) else {
                return nil
            }

            let executableURL = appURL
                .appendingPathComponent("Contents/Resources/app/bin", isDirectory: true)
                .appendingPathComponent(candidate.executableName, isDirectory: false)

            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                return nil
            }

            return VSCodeCLI(executableURL: executableURL)
        }
        .first
    }
}
