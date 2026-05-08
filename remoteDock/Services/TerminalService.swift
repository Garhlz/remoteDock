//
//  TerminalService.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit

enum TerminalService {
    static func openSSHSession(for host: RemoteHost) -> String? {
        let escapedCommand = host.sshCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String
            return message ?? "Unable to open Terminal."
        }

        return nil
    }
}
