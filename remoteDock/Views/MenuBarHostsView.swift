import SwiftUI
import RemoteDockCore

/// 菜单栏入口中的主机列表和快捷操作菜单。
///
/// 这是主窗口的一份“轻量镜像”：
/// 它复用了同一份配置文件、同一批系统服务和同一套状态概念，
/// 但 UI 更偏向快速操作，而不是完整管理。
struct MenuBarHostsView: View {
    /// 菜单栏需要知道全局默认打开方式，这样没有主机级覆盖时也能正确决定主动作。
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue

    /// 这些状态是菜单栏自己的局部快照，不直接和主窗口共享内存。
    /// 每次展开时它会从配置文件重新加载，保证信息尽量新鲜。
    @State private var hosts: [RemoteHost] = []
    @State private var groups: [HostGroup] = []
    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var latencyMilliseconds: [UUID: Double] = [:]
    @State private var lastCheckedAt: [UUID: Date] = [:]
    @State private var errorMessage: String?
    @State private var isPingingAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topActionsSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if hosts.isEmpty {
                    emptyStateSection
                } else {
                    statusSummary

                    ForEach(hostGroups) { group in
                        if !group.hosts.isEmpty {
                            hostGroupSection(group)
                        }
                    }
                }

                footerActionsSection
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadHosts()
        }
    }

    /// 每次展开菜单栏时都可重载配置，确保不必依赖主窗口也能拿到最新 host 列表。
    private func loadHosts() {
        do {
            let configuration = try HostStore.loadOrCreateConfiguration()
            hosts = configuration.hosts
            groups = configuration.groups
            errorMessage = nil
        } catch {
            hosts = []
            groups = []
            errorMessage = error.localizedDescription
        }
    }

    /// 优先激活已有主窗口；只有窗口不存在时才请求 SwiftUI 新开一个。
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = existingMainWindow() {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            return
        }

        AppBridge.shared.openMainWindow?()
    }

    /// 尝试找出当前最像“主窗口”的现有 NSWindow，避免重复打开多个主界面窗口。
    private func existingMainWindow() -> NSWindow? {
        let candidateWindows = NSApp.orderedWindows.filter {
            $0.isVisible &&
            !$0.isMiniaturized &&
            $0.canBecomeMain &&
            $0.level == .normal &&
            !$0.collectionBehavior.contains(.transient)
        }

        return candidateWindows.first(where: \.isKeyWindow)
            ?? candidateWindows.first(where: \.isMainWindow)
            ?? candidateWindows.first(where: { $0.title != "Settings" })
            ?? candidateWindows.first
    }

    private func status(for host: RemoteHost) -> HostStatus {
        statuses[host.id, default: .unknown]
    }

    private var onlineCount: Int {
        hosts.filter { status(for: $0) == .online }.count
    }

    private var offlineCount: Int {
        hosts.filter { status(for: $0) == .offline }.count
    }

    private var uncheckedCount: Int {
        hosts.filter { status(for: $0) == .unknown }.count
    }

    private var statusSummary: some View {
        /// 菜单栏空间有限，所以摘要只保留最有判断价值的三个计数。
        VStack(alignment: .leading, spacing: 4) {
            Text("\(hosts.count) hosts")
                .font(.subheadline.weight(.semibold))

            Text("Online \(onlineCount)  •  Offline \(offlineCount)  •  Unchecked \(uncheckedCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var topActionsSection: some View {
        VStack(spacing: 8) {
            actionRowButton(
                title: "Show Main Window",
                systemImage: "macwindow",
                secondaryText: "Bring the current app window to front",
                isProminent: true,
                action: showMainWindow
            )

            actionRowButton(
                title: isPingingAll ? "Checking All Hosts..." : "Ping All Hosts",
                systemImage: "wave.3.right",
                secondaryText: "Refresh online status and latency",
                isDisabled: hosts.isEmpty || isPingingAll,
                action: pingAll
            )
        }
    }

    private var emptyStateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No hosts configured")
                .font(.subheadline.weight(.semibold))

            Text("Add a host in the main window to use quick actions here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }

    private var footerActionsSection: some View {
        VStack(spacing: 8) {
            actionRowButton(
                title: "Reload Hosts",
                systemImage: "arrow.clockwise",
                secondaryText: "Reload configuration from disk",
                action: loadHosts
            )

            actionRowButton(
                title: "Quit RemoteDock",
                systemImage: "power",
                secondaryText: "Close the app and menu bar helper",
                action: { NSApp.terminate(nil) }
            )
        }
    }

    private func hostGroupSection(_ group: HostMenuSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(spacing: 4) {
                ForEach(group.hosts) { host in
                    hostMenu(for: host)
                }
            }
        }
    }

    /// 菜单栏里的主机分组逻辑与 sidebar 保持一致，保证用户在两个入口看到相同结构。
    private var hostGroups: [HostMenuSection] {
        var sections: [HostMenuSection] = groups.compactMap { group in
            let sectionHosts = hosts.filter { $0.groupID == group.id }
            guard !sectionHosts.isEmpty else {
                return nil
            }

            return HostMenuSection(title: group.name, hosts: sectionHosts)
        }

        let validGroupIDs = Set(groups.map(\.id))
        let ungroupedHosts = hosts.filter { host in
            guard let groupID = host.groupID else {
                return true
            }

            return !validGroupIDs.contains(groupID)
        }

        if !ungroupedHosts.isEmpty {
            sections.append(HostMenuSection(title: "Ungrouped", hosts: ungroupedHosts))
        }

        return sections
    }

    @ViewBuilder
    /// 每台主机对应一个子菜单：
    /// 顶部是状态摘要，中间是动作，底部是复制类辅助操作。
    private func hostMenu(for host: RemoteHost) -> some View {
        Menu {
            Text(statusLine(for: host))
                .foregroundStyle(status(for: host).color)

            if let lastCheckedAt = lastCheckedAt[host.id] {
                Text("Checked \(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Not checked yet")
                    .foregroundStyle(.secondary)
            }

            if let latencyText = latencyText(for: host), status(for: host) == .online {
                Text("Latency: \(latencyText)")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(primaryActionTitle(for: host)) {
                openPreferred(for: host)
            }

            Button("Ping") {
                ping(host)
            }

            Divider()

            Button("Copy SSH Command") {
                ClipboardService.copy(host.sshCommand)
            }

            Button("Copy Host Details") {
                ClipboardService.copy(host.fullDetailsText)
            }
        } label: {
            HStack {
                Label(host.name, systemImage: status(for: host).systemImage)
                    .lineLimit(1)
                Spacer()
                Text(host.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary)
            }
        }
        .buttonStyle(.plain)
    }

    private func primaryActionTitle(for host: RemoteHost) -> String {
        effectiveOpenMode(for: host).actionTitle
    }

    private func effectiveOpenMode(for host: RemoteHost) -> PreferredOpenMode {
        /// 生效逻辑与主窗口保持一致：先看主机级覆盖，再回退到全局默认值。
        host.preferredOpenModeOrNil ?? (PreferredOpenMode(rawValue: defaultOpenModeRawValue) ?? AppSettings.defaultOpenMode)
    }

    /// 菜单栏也复用与主窗口相同的“按首选方式打开”决策逻辑。
    private func openPreferred(for host: RemoteHost) {
        switch effectiveOpenMode(for: host) {
        case .ghostty:
            if let error = TerminalService.openSSHSession(for: host) {
                errorMessage = error.localizedDescription
            }
        case .defaultTerminal:
            if let error = DefaultTerminalService.openSSHSession(for: host) {
                errorMessage = error.localizedDescription
            }
        case .vscode:
            if let error = VSCodeService.openRemoteFolder(for: host) {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 单主机 ping 在菜单栏里用 fire-and-forget 方式触发，
    /// 完成后回到主线程更新局部状态。
    private func ping(_ host: RemoteHost) {
        statuses[host.id] = .checking

        Task {
            let result = await PingService.checkResult(address: host.address)
            await MainActor.run {
                statuses[host.id] = result.isReachable ? .online : .offline
                latencyMilliseconds[host.id] = result.averageLatencyMilliseconds
                lastCheckedAt[host.id] = Date()
            }
        }
    }

    /// 全量 ping 也采用并发任务组，避免主机数量一多就让菜单栏操作显得很慢。
    private func pingAll() {
        guard !isPingingAll else {
            return
        }

        isPingingAll = true
        for host in hosts {
            statuses[host.id] = .checking
        }

        Task {
            await withTaskGroup(of: (UUID, PingResult).self) { group in
                for host in hosts {
                    group.addTask {
                        let result = await PingService.checkResult(address: host.address)
                        return (host.id, result)
                    }
                }

                for await (hostID, result) in group {
                    await MainActor.run {
                        statuses[hostID] = result.isReachable ? .online : .offline
                        latencyMilliseconds[hostID] = result.averageLatencyMilliseconds
                        lastCheckedAt[hostID] = Date()
                    }
                }
            }

            await MainActor.run {
                isPingingAll = false
            }
        }
    }

    private func statusLine(for host: RemoteHost) -> String {
        /// 菜单栏顶部状态行使用短句式文案，避免在狭窄菜单里占用过多空间。
        switch status(for: host) {
        case .unknown:
            "Status: Not checked"
        case .checking:
            "Status: Checking..."
        case .online:
            "Status: Online"
        case .offline:
            "Status: Offline"
        }
    }

    private func latencyText(for host: RemoteHost) -> String? {
        guard let value = latencyMilliseconds[host.id] else {
            return nil
        }

        /// 菜单栏里沿用主窗口同样的格式化策略：
        /// 大于等于 100ms 用整数，小于 100ms 保留 1 位小数。
        if value >= 100 {
            return String(format: "%.0f ms", value)
        }

        return String(format: "%.1f ms", value)
    }

    private func actionRowButton(
        title: String,
        systemImage: String,
        secondaryText: String,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isProminent ? Color.accentColor : Color.primary)

                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(isProminent ? Color.accentColor.opacity(0.78) : Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isProminent
                ? Color.accentColor.opacity(0.18)
                : Color(nsColor: .controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isProminent
                        ? Color.accentColor.opacity(0.28)
                        : Color.secondary.opacity(0.16)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

/// 用于菜单栏分组展示的轻量 section 模型。
private struct HostMenuSection: Identifiable {
    let title: String
    let hosts: [RemoteHost]

    /// 菜单 section 用标题作为身份标识已经足够，因为这里的标题来自稳定的分组名或 `Ungrouped`。
    var id: String { title }
}
