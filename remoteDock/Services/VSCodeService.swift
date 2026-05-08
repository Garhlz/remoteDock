//
//  VSCodeService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import Foundation
import RemoteDockCore

enum VSCodeService {
    enum Error: LocalizedError {
        case notInstalled
        case launchFailed(output: String?)
        case processError(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                "Visual Studio Code is not installed."
            case .launchFailed(let output):
                if let output, !output.isEmpty {
                    "Unable to launch Visual Studio Code: \(output)"
                } else {
                    "Unable to launch Visual Studio Code."
                }
            case .processError(let description):
                "Unable to launch Visual Studio Code: \(description)"
            }
        }
    }

    static func openRemoteFolder(for host: RemoteHost) -> Error? {
        guard let cli = availableCLI else {
            return .notInstalled
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = cli.executableURL
        process.arguments = [
            "--new-window",
            "--remote",
            "ssh-remote+\(host.sshAuthority)",
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

                return .launchFailed(output: output)
            }

            return nil
        } catch {
            return .processError(error.localizedDescription)
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
