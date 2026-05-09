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
    let addHost: () -> Void
    let pingAll: () -> Void

    var body: some View {
        /// 左边是应用标题，右边是指标和全局按钮。
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RemoteDock")
                    .font(.system(size: 28, weight: .bold))

                Text("Remote hosts, SSH sessions, and remote workspaces.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                DashboardMetricView(title: "Hosts", value: "\(hostCount)")
                DashboardMetricView(title: "Online", value: "\(onlineCount)")
                DashboardMetricView(title: "Unchecked", value: "\(uncheckedCount)")
            }

            Button(action: addHost) {
                Label("Add Host", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Button(action: pingAll) {
                Label(isPingingAll ? "Checking" : "Ping All", systemImage: "network")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasHosts || isPingingAll)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }
}

/// 仪表盘中的单个指标块，例如 Hosts / Online / Unchecked。
private struct DashboardMetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .help("\(title): \(value)")
    }
}
