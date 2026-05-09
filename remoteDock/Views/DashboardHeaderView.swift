import SwiftUI

/// 主窗口顶部的统计与全局操作区域。
///
/// 这里承担两个作用：
/// 1. 给用户一个“总览仪表盘”，快速理解当前配置规模和状态；
/// 2. 放置最高频的全局动作入口，例如新增主机、打开设置、批量 Ping。
struct DashboardHeaderView: View {
    let hostCount: Int
    let onlineCount: Int
    let uncheckedCount: Int
    let isPingingAll: Bool
    let hasHosts: Bool
    let isCompact: Bool
    let addHost: () -> Void
    let pingAll: () -> Void

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        titleBlock

                        Spacer(minLength: 12)

                        compactActionRow
                    }

                    metricsRow
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    titleBlock

                    Spacer(minLength: 12)

                    metricsRow
                    actionRow
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 12 : 14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RemoteDock")
                .font(.system(size: isCompact ? 23 : 28, weight: .bold))

            Text("Remote hosts, SSH sessions, and remote workspaces.")
                .font(isCompact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: isCompact ? 6 : 8) {
            DashboardMetricView(title: "Hosts", value: "\(hostCount)", isCompact: isCompact)
            DashboardMetricView(title: "Online", value: "\(onlineCount)", isCompact: isCompact)
            DashboardMetricView(title: "Unchecked", value: "\(uncheckedCount)", isCompact: isCompact)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            addHostButton
            settingsButton
            pingAllButton
        }
    }

    private var compactActionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                addHostButton
                settingsButton
                pingAllButton
            }

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    addHostButton
                    settingsButton
                }

                pingAllButton
            }
        }
    }

    private var addHostButton: some View {
        Button(action: addHost) {
            Label("Add Host", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .controlSize(isCompact ? .small : .regular)
    }

    private var settingsButton: some View {
        SettingsLink {
            Label("Settings", systemImage: "gearshape")
        }
        .buttonStyle(.bordered)
        .controlSize(isCompact ? .small : .regular)
    }

    private var pingAllButton: some View {
        Button(action: pingAll) {
            Label(isPingingAll ? "Checking" : "Ping All", systemImage: "network")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(isCompact ? .small : .regular)
        .disabled(!hasHosts || isPingingAll)
    }
}

/// 仪表盘中的单个指标块，例如 Hosts / Online / Unchecked。
private struct DashboardMetricView: View {
    let title: String
    let value: String
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(isCompact ? .subheadline.weight(.semibold) : .headline)
        }
        .padding(.horizontal, isCompact ? 9 : 10)
        .padding(.vertical, isCompact ? 6 : 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .help("\(title): \(value)")
    }
}
