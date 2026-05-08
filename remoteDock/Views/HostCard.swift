//
//  HostCard.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

struct HostCard: View {
    let status: HostStatus
    let copiedLabel: String?
    let copySSHCommand: () -> Void
    let copyIPAddress: () -> Void
    let copyHostDetails: () -> Void
    let openSSH: () -> Void
    let openDefaultTerminal: () -> Void
    let openVSCodeRemote: () -> Void
    let showTailscaleStatus: () -> Void
    let showsTailscaleStatusAction: Bool
    let ping: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("Actions")
                    .font(.headline)

                Spacer(minLength: 0)

                statusBadge
                moreMenu
            }

            HStack(spacing: 12) {
                Button(action: openSSH) {
                    Label("Open in Ghostty", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("Open Ghostty and start an SSH session")

                Button(action: openVSCodeRemote) {
                    Label("Open in VS Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Open the host's remote directory in Visual Studio Code")
            }

            if showsTailscaleStatusAction {
                HStack(spacing: 12) {
                    Button(action: openDefaultTerminal) {
                        Label("Open in Default Terminal", systemImage: "rectangle.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("Open an SSH session using the default SSH URL handler")

                    Button(action: showTailscaleStatus) {
                        Label("Local Tailscale", systemImage: "wave.3.right.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("Show the local Tailscale status output")
                }
            } else {
                Button(action: openDefaultTerminal) {
                    Label("Open in Default Terminal", systemImage: "rectangle.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Open an SSH session using the default SSH URL handler")
            }

            Divider()

            HStack(spacing: 8) {
                actionPill(
                    title: copiedLabel == "SSH" ? "Copied SSH" : "Copy SSH",
                    systemImage: copiedLabel == "SSH" ? "checkmark" : "doc.on.doc",
                    action: copySSHCommand
                )

                actionPill(
                    title: copiedLabel == "IP" ? "Copied IP" : "Copy IP",
                    systemImage: copiedLabel == "IP" ? "checkmark" : "network",
                    action: copyIPAddress
                )

                actionPill(
                    title: copiedLabel == "Host" ? "Copied Host" : "Copy Host Info",
                    systemImage: copiedLabel == "Host" ? "checkmark" : "list.bullet.rectangle",
                    action: copyHostDetails
                )

                actionPill(
                    title: status == .checking ? "Checking" : "Ping",
                    systemImage: "wave.3.right",
                    action: ping
                )
                .disabled(status == .checking)

                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    private var statusBadge: some View {
        Label(status.rawValue, systemImage: status.systemImage)
            .font(.caption)
            .foregroundStyle(status.color)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var moreMenu: some View {
        Menu {
            Section("Copy") {
                Button(action: copySSHCommand) {
                    Label(copiedLabel == "SSH" ? "Copied SSH" : "Copy SSH", systemImage: "doc.on.doc")
                }

                Button(action: copyIPAddress) {
                    Label(copiedLabel == "IP" ? "Copied IP" : "Copy IP", systemImage: "number")
                }
            }

            Section("Manage") {
                Button(action: edit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(action: moveUp) {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button(action: moveDown) {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)

                Button(role: .destructive, action: delete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28, height: 28)
        .help("More host actions")
    }

    private func actionPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .controlSize(.regular)
        .help(title)
    }
}
