//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import AppKit
import SwiftUI

struct RemoteHost: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let address: String

    var sshCommand: String {
        "ssh \(username)@\(address)"
    }

    var displayAddress: String {
        "\(username)@\(address)"
    }
}

enum HostStatus: String {
    case unknown = "Not checked"
    case checking = "Checking..."
    case online = "Online"
    case offline = "Offline"

    var color: Color {
        switch self {
        case .unknown:
            .secondary
        case .checking:
            .orange
        case .online:
            .green
        case .offline:
            .red
        }
    }

    var systemImage: String {
        switch self {
        case .unknown:
            "circle"
        case .checking:
            "clock"
        case .online:
            "checkmark.circle.fill"
        case .offline:
            "xmark.circle.fill"
        }
    }
}

struct ContentView: View {
    private let hosts = [
        RemoteHost(name: "Arch T480s", username: "elaine", address: "100.117.140.113"),
        RemoteHost(name: "Windows Omen16", username: "elaine", address: "100.102.71.37")
    ]

    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var copiedHostID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ForEach(hosts) { host in
                HostCard(
                    host: host,
                    status: statuses[host.id, default: .unknown],
                    isCopied: copiedHostID == host.id,
                    copySSHCommand: {
                        copySSHCommand(for: host)
                    },
                    openSSH: {
                        openSSHSession(for: host)
                    },
                    ping: {
                        Task {
                            await ping(host)
                        }
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 520, height: 360)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RemoteDock")
                .font(.largeTitle.bold())

            Text("Quick access to your SSH hosts")
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func copySSHCommand(for host: RemoteHost) {
        copyToClipboard(host.sshCommand)
        copiedHostID = host.id

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedHostID == host.id {
                copiedHostID = nil
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openSSHSession(for host: RemoteHost) {
        let escapedCommand = host.sshCommand.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    @MainActor
    private func ping(_ host: RemoteHost) async {
        statuses[host.id] = .checking

        let isOnline = await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "1000", host.address]

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value

        statuses[host.id] = isOnline ? .online : .offline
    }

    private func status(for host: RemoteHost) -> HostStatus {
        statuses[host.id, default: .unknown]
    }

    private func isChecking(_ host: RemoteHost) -> Bool {
        status(for: host) == .checking
    }
}

struct HostCard: View {
    let host: RemoteHost
    let status: HostStatus
    let isCopied: Bool
    let copySSHCommand: () -> Void
    let openSSH: () -> Void
    let ping: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.name)
                        .font(.headline)

                    Text(host.displayAddress)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(status.rawValue, systemImage: status.systemImage)
                    .font(.caption)
                    .foregroundStyle(status.color)
            }

            HStack(spacing: 10) {
                Button(action: copySSHCommand) {
                    Label(isCopied ? "Copied" : "Copy SSH", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                }

                Button(action: openSSH) {
                    Label("Open SSH", systemImage: "terminal")
                }
                .keyboardShortcut(.defaultAction)

                Button(action: ping) {
                    Label(status == .checking ? "Checking" : "Ping", systemImage: "network")
                }
                .disabled(status == .checking)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }
}
