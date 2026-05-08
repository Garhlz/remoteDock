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
    let edit: () -> Void
    let delete: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.name)
                        .font(.headline)

                    Text(host.displayAddress)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                statusBadge
                moreMenu
            }

            HStack(spacing: 10) {
                Button(action: openSSH) {
                    Label("Open SSH", systemImage: "terminal")
                }
                .keyboardShortcut(.defaultAction)

                Button(action: ping) {
                    Label(status == .checking ? "Checking" : "Ping", systemImage: "network")
                }
                .disabled(status == .checking)

                Spacer()
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
    }
}
