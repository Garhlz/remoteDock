//
//  HostCard.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

struct HostCard: View {
    let preferredOpenMode: PreferredOpenMode
    let status: HostStatus
    let copiedLabel: String?
    let openPreferred: () -> Void
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
    @State private var isShowingAlternateOpenMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Actions")
                        .font(.headline)

                    Label("Primary: \(preferredOpenMode.title)", systemImage: preferredOpenMode.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                reorderButtons
                statusBadge
                moreMenu
            }

            HStack(spacing: 10) {
                primaryActionButton

                alternateOpenButton
            }

            Divider()

            HStack(spacing: 8) {
                quickActionButtons

                if showsTailscaleStatusAction {
                    actionPill(
                        title: "Local Tailscale",
                        systemImage: "wave.3.right.circle",
                        action: showTailscaleStatus
                    )
                }

                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary)
        }
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
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

    private var reorderButtons: some View {
        HStack(spacing: 4) {
            Button(action: moveUp) {
                Image(systemName: "arrow.up")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)
            .help("Move host up")

            Button(action: moveDown) {
                Image(systemName: "arrow.down")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("Move host down")
        }
        .foregroundStyle(.secondary)
    }

    private var primaryActionButton: some View {
        Button(action: openPreferred) {
            actionButtonLabel(
                title: preferredOpenMode.actionTitle,
                systemImage: preferredOpenMode.systemImage,
                foregroundStyle: .white,
                backgroundStyle: Color.accentColor,
                isProminent: true
            )
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .help(primaryHelpText)
    }

    private var alternateOpenButton: some View {
        Button {
            isShowingAlternateOpenMenu = true
        } label: {
            actionButtonLabel(
                title: "More Options",
                systemImage: "chevron.down.circle",
                foregroundStyle: .primary,
                backgroundStyle: Color(nsColor: .controlColor),
                isProminent: false
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingAlternateOpenMenu, arrowEdge: .bottom) {
            alternateOpenPopover
        }
        .help("Open this host with another configured action")
    }

    private var alternateOpenPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Open With")
                .font(.headline)

            ForEach(secondaryOpenActions) { action in
                Button {
                    isShowingAlternateOpenMenu = false
                    action.handler()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.mode.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.mode.actionTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(action.helpText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private var primaryHelpText: String {
        switch preferredOpenMode {
        case .ghostty:
            "Open Ghostty and start an SSH session"
        case .defaultTerminal:
            "Open an SSH session using the default SSH URL handler"
        case .vscode:
            "Open the host's remote directory in Visual Studio Code"
        }
    }

    private var secondaryOpenActions: [OpenAction] {
        PreferredOpenMode.allCases
            .filter { $0 != preferredOpenMode }
            .map { mode in
                OpenAction(
                    mode: mode,
                    helpText: helpText(for: mode),
                    handler: handler(for: mode)
                )
            }
    }

    private func helpText(for mode: PreferredOpenMode) -> String {
        switch mode {
        case .ghostty:
            "Open Ghostty and start an SSH session"
        case .defaultTerminal:
            "Open an SSH session using the default SSH URL handler"
        case .vscode:
            "Open the host's remote directory in Visual Studio Code"
        }
    }

    private func actionButtonLabel(
        title: String,
        systemImage: String,
        foregroundStyle: Color,
        backgroundStyle: Color,
        isProminent: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isProminent ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.10))
        }
    }

    private func handler(for mode: PreferredOpenMode) -> () -> Void {
        switch mode {
        case .ghostty:
            openSSH
        case .defaultTerminal:
            openDefaultTerminal
        case .vscode:
            openVSCodeRemote
        }
    }

    private func actionPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .controlSize(.regular)
        .help(title)
    }

    @ViewBuilder
    private var quickActionButtons: some View {
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
    }

    private struct OpenAction: Identifiable {
        let mode: PreferredOpenMode
        let helpText: String
        let handler: () -> Void

        var id: PreferredOpenMode { mode }
    }
}
