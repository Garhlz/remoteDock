//
//  HostCard.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

struct HostCard: View {
    let host: RemoteHost
    let status: HostStatus
    let copiedLabel: String?
    let copySSHCommand: () -> Void
    let copyIPAddress: () -> Void
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
                    Label(
                        copiedLabel == "SSH" ? "Copied" : "Copy SSH",
                        systemImage: copiedLabel == "SSH" ? "checkmark" : "doc.on.doc"
                    )
                }

                Button(action: copyIPAddress) {
                    Label(
                        copiedLabel == "IP" ? "Copied" : "Copy IP",
                        systemImage: copiedLabel == "IP" ? "checkmark" : "number"
                    )
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
