import SwiftUI
import RemoteDockCore

/// 左侧主机导航列表，负责搜索、筛选、分组和选中态展示。
///
/// 这个视图的职责非常明确：只负责“导航体验”。
/// 真正的数据筛选结果、状态计算和分组结构都由上层 `ContentView` 先准备好，再传进来。
/// 因此这里更像一个纯展示层组件。
struct HostsSidebarView: View {
    /// 这里的多个 `@Binding` 表示 sidebar 直接参与编辑页面级状态，
    /// 例如搜索词、筛选项和当前选中项都由上层持有，但在这里更新。
    let hosts: [RemoteHost]
    let groups: [HostGroup]
    @Binding var searchText: String
    @Binding var selectedFilter: HostFilter
    @Binding var selectedHostID: UUID?
    @Binding var isSidebarControlsExpanded: Bool
    let filteredHosts: [RemoteHost]
    let sidebarSections: [SidebarSection]
    let lastCheckedAt: [UUID: Date]
    let openModeSystemImage: (RemoteHost) -> String
    let status: (RemoteHost) -> HostStatus
    let latencyText: (RemoteHost) -> String?
    let manageGroups: () -> Void

    var body: some View {
        /// 结构分成三层：
        /// 1. 顶部标题和控制按钮；
        /// 2. 搜索/筛选区域；
        /// 3. 主机列表或空状态提示。
        VStack(spacing: 0) {
            header

            if isSidebarControlsExpanded {
                expandedControls
            } else if !searchText.isEmpty || selectedFilter != .all {
                collapsedControls
            }

            Divider()

            if filteredHosts.isEmpty {
                ContentUnavailableView(
                    hosts.isEmpty ? "No Hosts" : "No Results",
                    systemImage: hosts.isEmpty ? "server.rack" : "line.3.horizontal.decrease.circle",
                    description: Text(
                        hosts.isEmpty
                        ? "Add your first host to get started."
                        : "Try a different name, address, username, path, or status filter."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedHostID) {
                    ForEach(sidebarSections) { section in
                        Section(section.title) {
                            ForEach(section.hosts) { host in
                                HostSidebarRow(
                                    host: host,
                                    openModeSystemImage: openModeSystemImage(host),
                                    status: status(host),
                                    latencyText: latencyText(host),
                                    lastCheckedAt: lastCheckedAt[host.id],
                                    isSelected: selectedHostID == host.id
                                )
                                .tag(host.id)
                                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }

    /// 顶部标题除了显示统计信息，还承担两个入口：
    /// - 打开分组管理弹窗
    /// - 展开/收起搜索筛选区域
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hosts")
                    .font(.headline)

                Text("\(hosts.count) configured  •  \(groups.count) groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: manageGroups) {
                Image(systemName: "folder.badge.gearshape")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Manage host groups")

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSidebarControlsExpanded.toggle()
                }
            } label: {
                Image(systemName: isSidebarControlsExpanded ? "chevron.up.circle" : "slider.horizontal.3")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isSidebarControlsExpanded ? "Hide search and filter" : "Show search and filter")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    /// 展开态下显示完整控制区，适合经常搜索或切换筛选的用户。
    private var expandedControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search hosts", text: $searchText)
                    .textFieldStyle(.plain)

                /// 搜索框右侧的清除按钮只在有输入时出现，保持空状态下的界面更简洁。
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)

                Picker("Status Filter", selection: $selectedFilter) {
                    ForEach(HostFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 收起态下只保留“当前已生效的筛选标签”，减少视觉噪音。
    private var collapsedControls: some View {
        HStack(spacing: 8) {
            if !searchText.isEmpty {
                SidebarTagView(title: searchText, systemImage: "magnifyingglass")
            }

            if selectedFilter != .all {
                SidebarTagView(title: selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .transition(.opacity)
    }
}

/// 收起态下用于展示搜索词或筛选条件的轻量标签。
private struct SidebarTagView: View {
    let title: String
    let systemImage: String

    var body: some View {
        /// 这个标签的作用不是提供交互，而是把“当前生效的条件”用紧凑形式提示出来。
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }
}

/// 单条主机在 sidebar 中的展示行。
///
/// 这一行尝试在很小的空间里表达尽可能多的信息：
/// - 打开方式图标
/// - 在线状态
/// - 主机名称
/// - 地址
/// - 延迟
/// - 上次检查时间
/// - 是否有自定义启动命令
private struct HostSidebarRow: View {
    let host: RemoteHost
    let openModeSystemImage: String
    let status: HostStatus
    let latencyText: String?
    let lastCheckedAt: Date?
    let isSelected: Bool

    var body: some View {
        /// 左侧彩条 + 图标背景共同强化“当前选中项”的视觉锚点。
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 4)

            Image(systemName: openModeSystemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20, height: 20)
                .padding(6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)

                    Text(host.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(host.displayAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.72) : Color.secondary)
                    .lineLimit(1)

                if let latencyText, status == .online {
                    /// 只有在线状态才展示延迟，避免离线或未知状态下出现误导性的旧数值。
                    Text(latencyText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.68) : status.color)
                        .lineLimit(1)
                }

                if let lastCheckedAt {
                    /// 这里优先显示相对时间，让列表更适合快速扫读；tooltip 再补充完整时间戳。
                    HStack(spacing: 4) {
                        Text("Checked")
                        Text(lastCheckedAt, style: .relative)
                    }
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.62) : Color.secondary.opacity(0.72))
                    .lineLimit(1)
                    .help(lastCheckedAt.formatted(date: .complete, time: .standard))
                } else {
                    Text("Not checked yet")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.62) : Color.secondary.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if host.preferredStartupCommand != nil {
                /// bolt 图标表示这台主机登录后还会执行额外 follow-up 命令。
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("This host runs a custom startup command after SSH login")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
