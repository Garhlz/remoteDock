import SwiftUI
import RemoteDockCore

/// 单个主机的详情页内容，组合头部信息、动作卡片和连接详情。
///
/// 这个视图本身几乎不保存业务状态，而是接收上层 `ContentView` 传下来的数据和动作闭包。
/// 这样做的好处是：
/// - UI 布局与业务逻辑分离；
/// - 视图更容易复用和测试；
/// - 真正的数据源始终只有一份，避免多个地方各管一套状态。
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
    let copyHostConfiguration: () -> Void
    let openSSH: () -> Void
    let openDefaultTerminal: () -> Void
    let openVSCodeRemote: () -> Void
    let showTailscaleStatus: () -> Void
    let ping: () -> Void
    let duplicate: () -> Void
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
                copyHostConfiguration: copyHostConfiguration,
                openSSH: openSSH,
                openDefaultTerminal: openDefaultTerminal,
                openVSCodeRemote: openVSCodeRemote,
                showTailscaleStatus: showTailscaleStatus,
                showsTailscaleStatusAction: host.usesTailscale,
                ping: ping,
                duplicate: duplicate,
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

    /// 顶部区域负责回答“这台机器是谁、当前状态如何、有哪些快速上下文标签”。
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

            /// `ViewThatFits` 会优先尝试横向排布；空间不够时再退回纵向堆叠。
            /// 这样无需手工判断窗口宽度，就能适配不同尺寸。
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

    /// 下半部分是更稳定、更偏“配置详情”的信息网格。
    /// 与上面的动作卡片相比，这里更像一块只读说明面板。
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

    /// 分组切换菜单直接把用户选择回传给上层，由上层决定如何保存。
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

    /// 最后检查时间同时提供相对时间和绝对时间，
    /// 兼顾“好读”和“精确”两个场景。
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

    /// Tooltip 解释状态胶囊背后的含义，避免只有颜色和图标而不够直白。
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
        /// 单列详情行，适合像 Startup Command 这样长度可能明显大于其它字段的内容。
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
        /// 双列网格行，用于并排展示信息密度相近的两个字段。
        HStack(alignment: .top, spacing: 18) {
            detailCell(title: leftTitle, value: leftValue)
            detailCell(title: rightTitle, value: rightValue)
        }
    }

    private func detailCell(title: String, value: String) -> some View {
        /// `detailCell` 是网格里的最小复用单元：标题一行，值一行，可选中文本。
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
        /// 详情标签用于表达“上下文属性”，比如用户名、分组、目录、打开方式。
        /// 它们比正文更轻，但比注释更显眼。
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
