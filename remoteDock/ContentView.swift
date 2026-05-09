//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

/// 左侧主机列表的状态筛选类型。
enum HostFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case online = "Online"
    case offline = "Offline"
    case unchecked = "Unchecked"

    var id: String { rawValue }
}

/// 顶部反馈条使用的瞬时消息模型。
struct FeedbackMessage: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case error

        var title: String {
            switch self {
            case .success:
                "Done"
            case .error:
                "Action failed"
            }
        }

        var systemImage: String {
            switch self {
            case .success:
                "checkmark.circle.fill"
            case .error:
                "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success:
                .green
            case .error:
                .red
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

/// 左侧边栏中每个分组 section 的展示模型。
struct SidebarSection: Identifiable {
    let id: String
    let title: String
    let hosts: [RemoteHost]
}

/// 主窗口根据可用宽度切换布局模式，而不是只依赖固定最小尺寸。
private enum WindowLayoutMode {
    case regular
    case compact
    case stacked
}

/// 主窗口容器视图，负责页面级状态、主机操作和双栏布局编排。
///
/// 这个文件可以视为整个应用的“页面控制器”：
/// 1. 从 `HostStore` 读取配置文件，拿到主机和分组；
/// 2. 把数据拆给左侧 sidebar 和右侧 detail 两个子视图；
/// 3. 接住子视图发回来的动作，再调用存储、剪贴板、终端或网络服务；
/// 4. 把结果重新写回本地状态，驱动界面刷新。
///
/// SwiftUI 的核心思想是“状态决定界面”。
/// 因此这里最重要的不是直接操作控件，而是维护一组状态值；
/// 当这些状态变化时，SwiftUI 会重新计算 `body` 并刷新界面。
struct ContentView: View {
    /// 这组 `@State` 是主窗口运行期的内存状态。
    /// 它们只在窗口活着的时候存在，用来驱动当前界面。
    @State private var hosts: [RemoteHost] = []
    @State private var groups: [HostGroup] = []
    @State private var selectedHostID: UUID?
    @State private var searchText: String = ""
    @State private var selectedFilter: HostFilter = .all
    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var latencyMilliseconds: [UUID: Double] = [:]
    @State private var lastCheckedAt: [UUID: Date] = [:]
    @State private var copiedFeedback: [UUID: String] = [:]
    @State private var feedbackMessage: FeedbackMessage?
    @State private var configPath: String = ""
    @State private var didCopyConfig = false
    @State private var didCopyConfigPath = false
    @State private var hostBeingEdited: RemoteHost?
    @State private var isAddingHost = false
    @State private var isManagingGroups = false
    @State private var isPingingAll = false
    @AppStorage(AppSettings.sidebarControlsExpandedKey) private var isSidebarControlsExpanded = false
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingModeKey) private var defaultAutoPingModeRawValue = AppSettings.defaultAutoPingMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingIntervalValueKey) private var defaultAutoPingIntervalValue = AppSettings.defaultAutoPingIntervalValue
    @AppStorage(AppSettings.runInitialPingOnLaunchKey) private var runInitialPingOnLaunch = AppSettings.defaultRunInitialPingOnLaunch
    @State private var tailscaleStatusText: String?
    @State private var didRunInitialPing = false
    @State private var didStartAutoPingLoop = false

    var body: some View {
        GeometryReader { proxy in
            let layoutMode = layoutMode(for: proxy.size.width)
            let horizontalPadding = layoutMode == .stacked ? 14.0 : 18.0
            let verticalPadding = layoutMode == .stacked ? 14.0 : 18.0

            /// `body` 不是“渲染一次”的命令式代码，而是“当前状态下界面应该长什么样”的声明。
            VStack(spacing: layoutMode == .stacked ? 12 : 14) {
                DashboardHeaderView(
                    hostCount: hosts.count,
                    onlineCount: onlineHostsCount,
                    uncheckedCount: uncheckedHostsCount,
                    isPingingAll: isPingingAll,
                    hasHosts: !hosts.isEmpty,
                    isCompact: layoutMode != .regular,
                    addHost: { isAddingHost = true },
                    pingAll: {
                        Task {
                            await pingAll()
                        }
                    }
                )

                if let feedbackMessage {
                    FeedbackBannerView(feedback: feedbackMessage) {
                        self.feedbackMessage = nil
                    }
                }

                mainContent(for: layoutMode)

                ConfigPathFooterView(
                    configPath: configPath,
                    didCopyConfig: didCopyConfig,
                    didCopyPath: didCopyConfigPath,
                    isCompact: layoutMode != .regular,
                    copyConfig: copyConfiguration,
                    copyPath: copyConfigPath,
                    reload: loadHosts
                )
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 560)
        /// 第一个 task 用于窗口出现时读取配置。
        .task {
            loadHosts()
        }
        /// 第二个 task 负责启动后台自动 ping 循环，但只会真正启动一次。
        .task {
            await startAutoPingLoopIfNeeded()
        }
        /// 搜索词或筛选条件变化后，需要重新确认当前选中项是否仍然可见。
        .onChange(of: searchText) { _, _ in
            syncSelection()
        }
        .onChange(of: selectedFilter) { _, _ in
            syncSelection()
        }
        .sheet(isPresented: $isAddingHost) {
            HostEditorView(title: "Add Host", host: nil, availableGroups: groups) { host in
                add(host)
            }
        }
        .sheet(item: $hostBeingEdited) { host in
            HostEditorView(title: "Edit Host", host: host, availableGroups: groups) { updatedHost in
                update(updatedHost)
            }
        }
        .sheet(isPresented: $isManagingGroups) {
            GroupManagerView(groups: groups, hostCounts: hostCountsByGroup) { updatedGroups in
                saveGroups(updatedGroups)
            }
        }
        .sheet(isPresented: isShowingTailscaleStatus) {
            TailscaleStatusSheetView(
                statusText: tailscaleStatusText ?? "",
                dismiss: { tailscaleStatusText = nil },
                copy: {
                    guard let tailscaleStatusText else {
                        return
                    }

                    ClipboardService.copy(tailscaleStatusText)
                    showFeedback(.success, "Local Tailscale status copied.")
                }
            )
        }
        /// 这三项 `focusedSceneValue` 是“页面状态 -> 全局菜单命令”的桥。
        /// `ContentView` 负责把当前上下文打包成动作和名称，
        /// `RemoteDockCommands` 再从焦点场景中读取它们。
        /// 这样菜单命令不会反向依赖页面实现，页面切换时上下文也能自动更新。
        .focusedSceneValue(\.openSelectedHost, openSelectedHostAction)
        .focusedSceneValue(\.pingSelectedHost, pingSelectedHostAction)
        .focusedSceneValue(\.selectedHostName, selectedHost?.name)
    }

    @ViewBuilder
    private func mainContent(for layoutMode: WindowLayoutMode) -> some View {
        if layoutMode == .stacked {
            VStack(spacing: 12) {
                sidebar
                    .frame(minHeight: 220, idealHeight: 280, maxHeight: 320)

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            HSplitView {
                sidebar
                    .frame(
                        minWidth: layoutMode == .compact ? 210 : 230,
                        idealWidth: layoutMode == .compact ? 228 : 250,
                        maxWidth: layoutMode == .compact ? 255 : 290
                    )

                detailPane
                    .frame(
                        minWidth: layoutMode == .compact ? 420 : 520,
                        idealWidth: layoutMode == .compact ? 620 : 760,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
    }

    private var sidebar: some View {
        HostsSidebarView(
            hosts: hosts,
            groups: groups,
            searchText: $searchText,
            selectedFilter: $selectedFilter,
            selectedHostID: $selectedHostID,
            isSidebarControlsExpanded: $isSidebarControlsExpanded,
            filteredHosts: filteredHosts,
            sidebarSections: sidebarSections,
            lastCheckedAt: lastCheckedAt,
            openModeSystemImage: { effectiveOpenMode(for: $0).systemImage },
            status: status(for:),
            latencyText: latencyText(for:),
            manageGroups: { isManagingGroups = true }
        )
    }

    /// 右侧详情区并不自己保存状态，而是完全根据当前 `selectedHost` 决定展示什么。
    private var detailPane: some View {
        Group {
            if let host = selectedHost {
                ScrollView {
                    HostDetailView(
                        host: host,
                        groups: groups,
                        preferredOpenMode: effectiveOpenMode(for: host),
                        status: status(for: host),
                        copiedLabel: copiedFeedback[host.id],
                        latencyText: latencyText(for: host),
                        lastCheckedAt: lastCheckedAt[host.id],
                        autoPingDescription: effectiveAutoPingDescription(for: host),
                        groupName: groupName(for: host),
                        openPreferred: { openPreferred(for: host) },
                        copySSHCommand: { copy(host.sshCommand, label: "SSH", for: host) },
                        copyIPAddress: { copy(host.address, label: "IP", for: host) },
                        copyHostDetails: { copy(fullDetailsText(for: host), label: "Host", for: host) },
                        copyHostConfiguration: { copyHostConfiguration(host) },
                        openSSH: { openSSHSession(for: host) },
                        openDefaultTerminal: { openDefaultTerminalSession(for: host) },
                        openVSCodeRemote: { openVSCodeRemote(for: host) },
                        showTailscaleStatus: { showTailscaleStatus(for: host) },
                        ping: {
                            Task {
                                await ping(host)
                            }
                        },
                        duplicate: { duplicate(host) },
                        edit: { hostBeingEdited = host },
                        delete: { delete(host) },
                        moveUp: { move(host, by: -1) },
                        moveDown: { move(host, by: 1) },
                        canMoveUp: canMove(host, by: -1),
                        canMoveDown: canMove(host, by: 1),
                        assignGroup: { assignGroup($0, to: host) }
                    )
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "No Host Selected",
                    systemImage: "sidebar.leading",
                    description: Text("Select a host from the left to view details and actions.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }

    private func layoutMode(for width: CGFloat) -> WindowLayoutMode {
        if width < 900 {
            return .stacked
        }

        if width < 1180 {
            return .compact
        }

        return .regular
    }

    /// 把“是否显示 Tailscale 弹窗”转换成一个 `Binding<Bool>`，
    /// 方便直接喂给 `.sheet(isPresented:)`。
    ///
    /// 这里真正的源数据不是 Bool，而是 `tailscaleStatusText`：
    /// - 有文本 => 说明弹窗需要打开；
    /// - 置空文本 => 说明弹窗应该关闭。
    private var isShowingTailscaleStatus: Binding<Bool> {
        Binding(
            get: { tailscaleStatusText != nil },
            set: { isPresented in
                if !isPresented {
                    tailscaleStatusText = nil
                }
            }
        )
    }

    /// 当前真正选中的主机。
    ///
    /// 这里做了几层兜底：
    /// 1. 优先按 `selectedHostID` 找；
    /// 2. 如果该主机因为搜索/筛选暂时不可见，则回退到过滤后的第一项；
    /// 3. 再不行就回退到完整列表第一项。
    ///
    /// 这样可以避免界面出现“左边没有选中项，右边也没有内容”的空洞状态。
    private var selectedHost: RemoteHost? {
        guard let selectedHostID else {
            return filteredHosts.first ?? hosts.first
        }

        return hosts.first(where: { $0.id == selectedHostID }) ?? filteredHosts.first ?? hosts.first
    }

    /// 把“打开当前主机”的动作包装成闭包，传给 Commands 系统。
    private var openSelectedHostAction: (() -> Void)? {
        guard let host = selectedHost else {
            return nil
        }

        return {
            openPreferred(for: host)
        }
    }

    /// 把“Ping 当前主机”的动作包装成闭包，传给 Commands 系统。
    private var pingSelectedHostAction: (() -> Void)? {
        guard let host = selectedHost else {
            return nil
        }

        return {
            Task {
                await ping(host)
            }
        }
    }

    private var onlineHostsCount: Int {
        hosts.filter { status(for: $0) == .online }.count
    }

    private var uncheckedHostsCount: Int {
        hosts.filter { status(for: $0) == .unknown }.count
    }

    private var hostCountsByGroup: [UUID: Int] {
        Dictionary(grouping: hosts.compactMap { host in
            host.groupID.map { ($0, host.id) }
        }, by: \.0).mapValues(\.count)
    }

    /// 左侧列表真正使用的数据源。
    ///
    /// 过滤顺序是：
    /// 1. 先按状态筛选；
    /// 2. 再按搜索关键字筛选。
    ///
    /// 这样写的好处是逻辑清晰，且 sidebar、selection、统计等地方都能复用同一份结果。
    private var filteredHosts: [RemoteHost] {
        let query = trimmedSearchText
        let statusFilteredHosts = hosts.filter { host in
            switch selectedFilter {
            case .all:
                true
            case .online:
                status(for: host) == .online
            case .offline:
                status(for: host) == .offline
            case .unchecked:
                status(for: host) == .unknown
            }
        }

        guard !query.isEmpty else {
            return statusFilteredHosts
        }

        let normalizedQuery = query.lowercased()

        return statusFilteredHosts.filter { host in
            host.name.lowercased().contains(normalizedQuery) ||
            host.username.lowercased().contains(normalizedQuery) ||
            host.address.lowercased().contains(normalizedQuery) ||
            host.effectiveRemoteDirectory.lowercased().contains(normalizedQuery)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 把扁平的主机数组整理成 sidebar 需要的 section 结构。
    ///
    /// 这里有一个特意保留的 UX 规则：
    /// 只要正在搜索，就不再显示“按分组切块”的结果，而是统一放进 `Results`。
    /// 这样搜索结果会更像“命中列表”，而不是“带分组噪音的树状导航”。
    private var sidebarSections: [SidebarSection] {
        if !trimmedSearchText.isEmpty {
            return [SidebarSection(id: "results", title: "Results", hosts: filteredHosts)]
        }

        var sections: [SidebarSection] = groups.compactMap { group in
            let sectionHosts = filteredHosts.filter { $0.groupID == group.id }
            guard !sectionHosts.isEmpty else {
                return nil
            }

            return SidebarSection(id: group.id.uuidString, title: group.name, hosts: sectionHosts)
        }

        let validGroupIDs = Set(groups.map(\.id))
        let ungroupedHosts = filteredHosts.filter { host in
            guard let groupID = host.groupID else {
                return true
            }

            return !validGroupIDs.contains(groupID)
        }
        if !ungroupedHosts.isEmpty {
            sections.append(SidebarSection(id: "ungrouped", title: "Ungrouped", hosts: ungroupedHosts))
        }

        return sections
    }

    @MainActor
    /// 从磁盘加载配置，并在首次启动时按设置决定是否立即做一次全量 ping。
    ///
    /// 数据链路是：
    /// `hosts.json` -> `HostStore.loadOrCreateConfiguration()` -> `hosts/groups` 状态 -> 子视图刷新。
    ///
    /// 失败时这里不会让页面完全空白，而是退回到内置默认主机并展示错误。
    /// 这样做的取舍是：优先保证应用还能继续演示和编辑，而不是把用户直接困在启动失败状态。
    private func loadHosts() {
        do {
            let configuration = try HostStore.loadOrCreateConfiguration()
            hosts = configuration.hosts
            groups = configuration.groups
            configPath = try HostStore.configFileURL.path
            syncSelection()
        } catch {
            hosts = HostStore.defaultHosts
            groups = []

            if let path = try? HostStore.configFileURL.path {
                configPath = path
            }

            syncSelection()
            showFeedback(.error, error.localizedDescription)
        }

        if !didRunInitialPing && !hosts.isEmpty {
            didRunInitialPing = true

            if runInitialPingOnLaunch {
                Task {
                    await pingAll()
                }
            }
        }
    }

    @MainActor
    /// 新增主机的最小闭环：
    /// 更新内存数组 -> 切换选中项 -> 持久化到磁盘。
    private func add(_ host: RemoteHost) {
        hosts.append(host)
        selectedHostID = host.id
        saveHosts()
    }

    @MainActor
    /// 编辑主机时保持原有位置不变，只替换数组中的对应元素。
    private func update(_ updatedHost: RemoteHost) {
        guard let index = hosts.firstIndex(where: { $0.id == updatedHost.id }) else {
            return
        }

        hosts[index] = updatedHost
        selectedHostID = updatedHost.id
        saveHosts()
    }

    @MainActor
    /// 复制主机不是简单复制 JSON，而是创建一个拥有新 UUID 的新模型，
    /// 然后插入到原主机后面，方便用户立即发现并继续编辑。
    private func duplicate(_ host: RemoteHost) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        let duplicateName = host.suggestedDuplicateName(takenNames: hosts.map(\.name))
        let duplicatedHost = host.duplicated(named: duplicateName)
        hosts.insert(duplicatedHost, at: index + 1)
        selectedHostID = duplicatedHost.id
        saveHosts()
        showFeedback(.success, "Duplicated \(host.name) as \(duplicateName).")
    }

    @MainActor
    /// 删除主机后，还要同步清理所有与该主机关联的派生状态，避免字典中残留脏数据。
    private func delete(_ host: RemoteHost) {
        guard let deletedIndex = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        hosts.removeAll { $0.id == host.id }
        statuses[host.id] = nil
        latencyMilliseconds[host.id] = nil
        lastCheckedAt[host.id] = nil
        copiedFeedback[host.id] = nil

        if selectedHostID == host.id {
            if hosts.indices.contains(deletedIndex) {
                selectedHostID = hosts[deletedIndex].id
            } else {
                selectedHostID = hosts.last?.id
            }
        }

        saveHosts()
    }

    @MainActor
    /// 同组内移动顺序时，只和“同组兄弟节点”交换位置，不影响其他分组的顺序。
    private func move(_ host: RemoteHost, by offset: Int) {
        guard let currentIndex = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        let siblingIndexes = hosts.indices.filter { hosts[$0].groupID == host.groupID }
        guard let siblingPosition = siblingIndexes.firstIndex(of: currentIndex) else {
            return
        }

        let destinationPosition = siblingPosition + offset
        guard siblingIndexes.indices.contains(destinationPosition) else {
            return
        }

        hosts.swapAt(currentIndex, siblingIndexes[destinationPosition])
        saveConfiguration()
    }

    @MainActor
    private func saveHosts() {
        saveConfiguration()
    }

    @MainActor
    /// 保存分组时会顺手修正无效的 `groupID` 引用，保证 host 不会指向不存在的分组。
    ///
    /// 这属于“边界一致性修复”：
    /// 分组列表和主机上的 `groupID` 是两份相关数据，如果只保存分组本身，
    /// 删除分组后就会留下悬空引用，所以这里必须把关联修正和保存动作绑定在一起。
    private func saveGroups(_ updatedGroups: [HostGroup]) {
        groups = updatedGroups
        let validGroupIDs = Set(updatedGroups.map(\.id))
        hosts = hosts.map { host in
            guard let groupID = host.groupID, !validGroupIDs.contains(groupID) else {
                return host
            }

            return host.withGroupID(nil)
        }
        saveConfiguration()
    }

    @MainActor
    /// 单个主机切换分组，本质上是不可变模型的“复制修改”。
    private func assignGroup(_ groupID: UUID?, to host: RemoteHost) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        hosts[index] = hosts[index].withGroupID(groupID)
        saveConfiguration()
    }

    @MainActor
    /// 所有“改完数据要落盘”的路径最终都会汇聚到这里。
    ///
    /// 这是主窗口最重要的持久化出口：
    /// - 先把 `hosts + groups` 重新组装成 `RemoteDockConfiguration`
    /// - 交给 `HostStore` 编码并写入 `hosts.json`
    /// - 成功后再同步选中态；失败则展示反馈条
    private func saveConfiguration() {
        do {
            try HostStore.save(RemoteDockConfiguration(hosts: hosts, groups: groups))
            configPath = try HostStore.configFileURL.path
            syncSelection()
        } catch {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    /// 通用复制动作：写剪贴板、更新按钮的“已复制”反馈、再在短延迟后自动复原标签。
    private func copy(_ text: String, label: String, for host: RemoteHost) {
        ClipboardService.copy(text)
        copiedFeedback[host.id] = label
        showFeedback(.success, copiedMessage(for: label, host: host))

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedFeedback[host.id] == label {
                copiedFeedback[host.id] = nil
            }
        }
    }

    @MainActor
    private func copyConfigPath() {
        guard !configPath.isEmpty else {
            return
        }

        ClipboardService.copy(configPath)
        didCopyConfigPath = true
        showFeedback(.success, "Config file path copied.")

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopyConfigPath = false
        }
    }

    @MainActor
    /// 导出整个配置文件当前的内存快照，而不是重新从磁盘读一遍。
    /// 这样可以确保用户刚修改但尚未来得及重新加载的数据也会被复制出去。
    private func copyConfiguration() {
        do {
            let configuration = RemoteDockConfiguration(hosts: hosts, groups: groups)
            ClipboardService.copy(try configuration.formattedJSON())
            didCopyConfig = true
            showFeedback(.success, "Full configuration copied.")

            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                didCopyConfig = false
            }
        } catch {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    private func copyHostConfiguration(_ host: RemoteHost) {
        do {
            ClipboardService.copy(try host.formattedJSON())
            copiedFeedback[host.id] = "HostConfig"
            showFeedback(.success, "Host configuration copied for \(host.name).")

            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if copiedFeedback[host.id] == "HostConfig" {
                    copiedFeedback[host.id] = nil
                }
            }
        } catch {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    /// 把页面层动作转发给终端服务；页面只负责展示错误，不关心 AppleScript 细节。
    ///
    /// 这里刻意没有把错误吞掉，也没有自己解释 Ghostty 自动化链路，
    /// 而是让 `TerminalService` 返回结构化错误，再统一交给页面反馈条展示。
    private func openSSHSession(for host: RemoteHost) {
        if let error = TerminalService.openSSHSession(for: host) {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    /// 统一的“按默认方式打开”分发器。
    /// `PreferredOpenMode` 只描述策略，真正执行由不同服务完成。
    ///
    /// 这里的关键设计点是把“选哪条打开链路”和“如何执行那条链路”拆开：
    /// - `effectiveOpenMode` 负责决策；
    /// - 各 Service 负责落地。
    /// 这样以后即使新增一种打开方式，也只需要扩展策略枚举和分发器。
    private func openPreferred(for host: RemoteHost) {
        switch effectiveOpenMode(for: host) {
        case .ghostty:
            openSSHSession(for: host)
        case .defaultTerminal:
            openDefaultTerminalSession(for: host)
        case .vscode:
            openVSCodeRemote(for: host)
        }
    }

    @MainActor
    private func openDefaultTerminalSession(for host: RemoteHost) {
        if let error = DefaultTerminalService.openSSHSession(for: host) {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    private func openVSCodeRemote(for host: RemoteHost) {
        if let error = VSCodeService.openRemoteFolder(for: host) {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    /// 只有明显是 Tailscale 地址的主机才允许查看本机 Tailscale 状态，
    /// 避免给普通 SSH 主机展示一个语义上无关的动作。
    private func showTailscaleStatus(for host: RemoteHost) {
        guard host.usesTailscale else {
            showFeedback(.error, "This host does not look like a Tailscale address.")
            return
        }

        switch TailscaleService.status() {
        case .success(let statusText):
            tailscaleStatusText = statusText
        case .failure(let error):
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
    /// 单主机 ping：先把状态切到 checking，再等待异步结果，最后回填状态、延迟和时间戳。
    private func ping(_ host: RemoteHost) async {
        statuses[host.id] = .checking
        let result = await PingService.checkResult(address: host.address)
        statuses[host.id] = result.isReachable ? .online : .offline
        latencyMilliseconds[host.id] = result.averageLatencyMilliseconds
        lastCheckedAt[host.id] = Date()
    }

    @MainActor
    /// 全量 ping 使用 `TaskGroup` 并发执行，每台主机一个子任务。
    ///
    /// 对不熟悉 Swift Concurrency 的读者，可以把它理解成：
    /// “批量发请求，然后谁先回来就先更新谁”，而不是串行一台一台等待。
    private func pingAll() async {
        guard !isPingingAll else {
            return
        }

        isPingingAll = true
        for host in hosts {
            statuses[host.id] = .checking
        }

        await withTaskGroup(of: (UUID, PingResult).self) { group in
            for host in hosts {
                group.addTask {
                    let result = await PingService.checkResult(address: host.address)
                    return (host.id, result)
                }
            }

            for await (hostID, result) in group {
                statuses[hostID] = result.isReachable ? .online : .offline
                latencyMilliseconds[hostID] = result.averageLatencyMilliseconds
                lastCheckedAt[hostID] = Date()
            }
        }

        isPingingAll = false
    }

    @MainActor
    /// 启动一个长期运行的后台循环，定期检查“哪些主机到了下一次自动 ping 的时间”。
    private func startAutoPingLoopIfNeeded() async {
        guard !didStartAutoPingLoop else {
            return
        }

        didStartAutoPingLoop = true

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: autoPingLoopSleepNanoseconds)
            await autoPingDueHosts()
        }
    }

    @MainActor
    /// 自动 ping 不会无脑扫描所有主机，而是只处理“到期”的那部分主机。
    ///
    /// 条件包括：
    /// - 当前不在 checking
    /// - 曾经至少被检查过一次
    /// - 自动 ping 功能没有被关闭
    /// - 距离上次检查的时间已超过配置间隔
    private func autoPingDueHosts() async {
        guard !hosts.isEmpty, !isPingingAll else {
            return
        }

        let now = Date()
        let dueHosts = hosts.filter { host in
            guard status(for: host) != .checking else {
                return false
            }

            guard let lastChecked = lastCheckedAt[host.id] else {
                return false
            }

            guard let interval = effectiveAutoPingInterval(for: host) else {
                return false
            }
            return now.timeIntervalSince(lastChecked) >= interval
        }

        guard !dueHosts.isEmpty else {
            return
        }

        await withTaskGroup(of: (UUID, PingResult).self) { group in
            for host in dueHosts {
                statuses[host.id] = .checking
                group.addTask {
                    let result = await PingService.checkResult(address: host.address)
                    return (host.id, result)
                }
            }

            for await (hostID, result) in group {
                statuses[hostID] = result.isReachable ? .online : .offline
                latencyMilliseconds[hostID] = result.averageLatencyMilliseconds
                lastCheckedAt[hostID] = Date()
            }
        }
    }

    private func status(for host: RemoteHost) -> HostStatus {
        statuses[host.id, default: .unknown]
    }

    /// 解析出全局默认的打开方式；若持久化值无效，则回退到默认值。
    private var resolvedDefaultOpenMode: PreferredOpenMode {
        PreferredOpenMode(rawValue: defaultOpenModeRawValue) ?? AppSettings.defaultOpenMode
    }

    private var resolvedDefaultAutoPingMode: AppSettings.AutoPingMode {
        AppSettings.effectiveAutoPingMode(rawValue: defaultAutoPingModeRawValue)
    }

    private var resolvedDefaultAutoPingIntervalValue: Int {
        AppSettings.normalizedAutoPingIntervalValue(defaultAutoPingIntervalValue)
    }

    /// 计算主机最终生效的打开方式。
    ///
    /// 优先级很简单但很重要：
    /// 1. 主机自己的偏好；
    /// 2. 全局默认值。
    ///
    /// 这种“局部覆盖全局”的模式和自动 Ping 设置保持一致，
    /// 读者理解这一处后，基本也能推导整个项目的设置覆盖哲学。
    private func effectiveOpenMode(for host: RemoteHost) -> PreferredOpenMode {
        host.preferredOpenModeOrNil ?? resolvedDefaultOpenMode
    }

    /// 计算一台主机真正生效的自动 ping 间隔。
    ///
    /// 优先级是：
    /// 1. 主机级禁用；
    /// 2. 主机级自定义间隔；
    /// 3. 全局设置；
    /// 4. 若全局是 manual，则返回 `nil` 表示不自动检查。
    private func effectiveAutoPingInterval(for host: RemoteHost) -> TimeInterval? {
        if host.preferredAutoPingDisabledOrNil {
            return nil
        }

        if let hostIntervalMinutes = host.preferredAutoPingIntervalMinutesOrNil {
            return TimeInterval(hostIntervalMinutes * 60)
        }

        switch resolvedDefaultAutoPingMode {
        case .seconds:
            return TimeInterval(resolvedDefaultAutoPingIntervalValue)
        case .minutes:
            return TimeInterval(resolvedDefaultAutoPingIntervalValue * 60)
        case .manual:
            return nil
        }
    }

    /// 与 `effectiveAutoPingInterval` 配套，用于给 UI 生成更友好的展示文本。
    ///
    /// 这里没有直接复用 `TimeInterval` 转文字，而是重新按“配置语义”生成文案：
    /// 比如主机级禁用要显示 `Never`，主机级覆盖要显示分钟值，
    /// 否则才回退到全局策略的说明文字。这样读者看到的是“为什么是这个结果”，不是裸秒数。
    private func effectiveAutoPingDescription(for host: RemoteHost) -> String {
        if host.preferredAutoPingDisabledOrNil {
            return "Never"
        }

        if let hostIntervalMinutes = host.preferredAutoPingIntervalMinutesOrNil {
            return "\(hostIntervalMinutes) min"
        }

        return AppSettings.heartbeatDescription(
            mode: resolvedDefaultAutoPingMode,
            value: resolvedDefaultAutoPingIntervalValue
        )
    }

    private var autoPingLoopSleepNanoseconds: UInt64 {
        switch resolvedDefaultAutoPingMode {
        case .seconds:
            5_000_000_000
        case .minutes, .manual:
            15_000_000_000
        }
    }

    /// 复制“主机信息”时使用的多行摘要文本，包含比 `RemoteHost.fullDetailsText` 更多的界面上下文，
    /// 例如当前分组名和最终生效的打开方式。
    private func fullDetailsText(for host: RemoteHost) -> String {
        [
            "Name: \(host.name)",
            "Group: \(groupName(for: host) ?? "Ungrouped")",
            "Username: \(host.username)",
            "Address: \(host.address)",
            "Port: \(host.port.map(String.init) ?? "Default")",
            "SSH Target: \(host.sshTarget)",
            "Preferred Open Mode: \(effectiveOpenMode(for: host).title)",
            "Auto Ping Interval: \(effectiveAutoPingDescription(for: host))",
            "Remote Directory: \(host.effectiveRemoteDirectory)",
            "Startup Command: \(host.preferredStartupCommand ?? "Default behavior")"
        ]
        .joined(separator: "\n")
    }

    private func canMove(_ host: RemoteHost, by offset: Int) -> Bool {
        guard let currentIndex = hosts.firstIndex(where: { $0.id == host.id }) else {
            return false
        }

        let siblingIndexes = hosts.indices.filter { hosts[$0].groupID == host.groupID }
        guard let siblingPosition = siblingIndexes.firstIndex(of: currentIndex) else {
            return false
        }

        return siblingIndexes.indices.contains(siblingPosition + offset)
    }

    /// 当搜索或筛选导致当前选中项不可见时，把选中项自动切换到仍然可见的第一条记录。
    ///
    /// 这是一条纯 UX 决策：选中态永远尽量指向“当前可操作对象”，
    /// 避免出现左边已经筛掉目标、右边却仍显示旧主机详情的上下文错位。
    private func syncSelection() {
        if hosts.isEmpty {
            selectedHostID = nil
            return
        }

        if let selectedHostID,
           filteredHosts.contains(where: { $0.id == selectedHostID }) {
            return
        }

        selectedHostID = filteredHosts.first?.id ?? hosts.first?.id
    }

    private func latencyText(for host: RemoteHost) -> String? {
        guard let value = latencyMilliseconds[host.id] else {
            return nil
        }

        return formattedLatency(value)
    }

    private func formattedLatency(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f ms", value)
        }

        return String(format: "%.1f ms", value)
    }

    private func groupName(for host: RemoteHost) -> String? {
        guard let groupID = host.groupID else {
            return nil
        }

        return groups.first(where: { $0.id == groupID })?.name
    }

    @MainActor
    /// 顶部反馈条统一从这里创建。
    /// 成功消息显示时间较短，错误消息显示更久，方便用户阅读失败原因。
    private func showFeedback(_ kind: FeedbackMessage.Kind, _ message: String) {
        let feedback = FeedbackMessage(kind: kind, message: message)
        feedbackMessage = feedback

        Task {
            try? await Task.sleep(nanoseconds: kind == .error ? 4_000_000_000 : 2_000_000_000)
            if feedbackMessage?.id == feedback.id {
                feedbackMessage = nil
            }
        }
    }

    private func copiedMessage(for label: String, host: RemoteHost) -> String {
        switch label {
        case "SSH":
            "SSH command copied for \(host.name)."
        case "IP":
            "Address copied for \(host.name)."
        case "Host":
            "Full host details copied for \(host.name)."
        case "HostConfig":
            "Host configuration copied for \(host.name)."
        default:
            "\(label) copied for \(host.name)."
        }
    }
}
