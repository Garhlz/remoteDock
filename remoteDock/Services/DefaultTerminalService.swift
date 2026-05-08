//
//  DefaultTerminalService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import Foundation

enum DefaultTerminalService {
    static func openSSHSession(for host: RemoteHost) -> String? {
        guard let url = URL(string: "ssh://\(host.sshTarget)") else {
            return "Unable to build the SSH URL for the default terminal."
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
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
                    return "Unable to open the default terminal: \(output)"
                }

                return "Unable to open the default terminal."
            }

            return nil
        } catch {
            return "Unable to open the default terminal: \(error.localizedDescription)"
        }
    }
}
