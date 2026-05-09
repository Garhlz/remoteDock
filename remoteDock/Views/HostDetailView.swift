import SwiftUI
import RemoteDockCore

struct HostDetailView: View {
    let host: RemoteHost
    let groups: [HostGroup]
    let preferredOpenMode: PreferredOpenMode
    let status: HostStatus
    let copiedLabel: String?
    let latencyText: String?
    let lastCheckedAt: Date?
    let autoPingDescription: String
    let groupName: String?
    let openPreferred: () -> Void
    let copySSHCommand: () -> Void
    let copyIPAddress: () -> Void
    let copyHostDetails: () -> Void
    let openSSH: () -> Void
    let openDefaultTerminal: () -> Void
    let openVSCodeRemote: () -> Void
    let showTailscaleStatus: () -> Void
    let ping: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    let assignGroup: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailHeader

            HostCard(
                preferredOpenMode: preferredOpenMode,
                status: status,
                copiedLabel: copiedLabel,
                openPreferred: openPreferred,
                copySSHCommand: copySSHCommand,
                copyIPAddress: copyIPAddress,
                copyHostDetails: copyHostDetails,
                openSSH: openSSH,
                openDefaultTerminal: openDefaultTerminal,
                openVSCodeRemote: openVSCodeRemote,
                showTailscaleStatus: showTailscaleStatus,
                showsTailscaleStatusAction: host.usesTailscale,
                ping: ping,
                edit: edit,
                delete: delete,
                moveUp: moveUp,
                moveDown: moveDown,
                canMoveUp: canMoveUp,
                canMoveDown: canMoveDown
            )

            hostMetadata
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(host.name)
                        .font(.title.weight(.semibold))

                    Text(host.sshTarget)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Label(status.rawValue, systemImage: status.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(status.color.opacity(0.12))
                    .clipShape(Capsule())
                    .help(statusTooltip)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    detailTag(title: host.username, systemImage: "person")
                    detailTag(title: preferredOpenMode.title, systemImage: preferredOpenMode.systemImage)
                    groupAssignmentMenu
                    detailTag(title: host.effectiveRemoteDirectory, systemImage: "folder")

                    if host.preferredStartupCommand != nil {
                        detailTag(title: "Custom startup", systemImage: "bolt")
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    detailTag(title: host.username, systemImage: "person")
                    detailTag(title: preferredOpenMode.title, systemImage: preferredOpenMode.systemImage)
                    groupAssignmentMenu
                    detailTag(title: host.effectiveRemoteDirectory, systemImage: "folder")

                    if host.preferredStartupCommand != nil {
                        detailTag(title: "Custom startup", systemImage: "bolt")
                    }
                }
            }
        }
    }

    private var hostMetadata: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Details")
                .font(.headline)

            detailGridRow(
                leftTitle: "Username",
                leftValue: host.username,
                rightTitle: "Preferred Open",
                rightValue: preferredOpenMode.title
            )

            detailGridRow(
                leftTitle: "Endpoint",
                leftValue: host.port.map { "\(host.address):\($0)" } ?? host.address,
                rightTitle: "Auto Ping",
                rightValue: autoPingDescription
            )

            detailGridRow(
                leftTitle: "Group",
                leftValue: groupName ?? "Ungrouped",
                rightTitle: "Latency",
                rightValue: latencyText ?? "Unavailable"
            )

            HStack(alignment: .top, spacing: 18) {
                detailCell(title: "Remote Directory", value: host.effectiveRemoteDirectory)
                lastCheckedDetailCell
            }

            detailGridRow(
                leftTitle: "Current Status",
                leftValue: status.rawValue,
                rightTitle: "VS Code Target",
                rightValue: host.vscodeRemoteDirectory
            )

            detailRow(title: "Startup Command", value: host.preferredStartupCommand ?? "Default behavior")
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary)
        }
    }

    private var groupAssignmentMenu: some View {
        Menu {
            Button(host.groupID == nil ? "Ungrouped" : "Move to Ungrouped") {
                assignGroup(nil)
            }

            if !groups.isEmpty {
                Divider()

                ForEach(groups) { group in
                    Button {
                        assignGroup(group.id)
                    } label: {
                        if host.groupID == group.id {
                            Label(group.name, systemImage: "checkmark")
                        } else {
                            Text(group.name)
                        }
                    }
                }
            }
        } label: {
            detailTag(title: groupName ?? "Ungrouped", systemImage: "folder.badge.person.crop")
        }
        .menuStyle(.borderlessButton)
        .help("Change host group")
    }

    private var lastCheckedDetailCell: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Checked")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let lastCheckedAt {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lastCheckedAt, style: .relative)
                        .font(.system(.body, design: .monospaced))

                    Text(lastCheckedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .help(lastCheckedAt.formatted(date: .complete, time: .standard))
            } else {
                Text("Not checked yet")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusTooltip: String {
        switch status {
        case .unknown:
            "Host has not been checked yet"
        case .checking:
            "Checking host reachability"
        case .online:
            "Host responded to ping"
        case .offline:
            "Host did not respond to ping"
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func detailGridRow(
        leftTitle: String,
        leftValue: String,
        rightTitle: String,
        rightValue: String
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            detailCell(title: leftTitle, value: leftValue)
            detailCell(title: rightTitle, value: rightValue)
        }
    }

    private func detailCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailTag(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }
}
