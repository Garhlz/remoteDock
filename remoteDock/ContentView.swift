//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

enum HostFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case online = "Online"
    case offline = "Offline"
    case unchecked = "Unchecked"

    var id: String { rawValue }
}

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

struct SidebarSection: Identifiable {
    let id: String
    let title: String
    let hosts: [RemoteHost]
}

struct ContentView: View {
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
        VStack(spacing: 14) {
            DashboardHeaderView(
                hostCount: hosts.count,
                onlineCount: onlineHostsCount,
                uncheckedCount: uncheckedHostsCount,
                isPingingAll: isPingingAll,
                hasHosts: !hosts.isEmpty,
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

            HSplitView {
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
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 270)

                detailPane
                    .frame(minWidth: 520, idealWidth: 760, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ConfigPathFooterView(
                configPath: configPath,
                didCopyConfig: didCopyConfig,
                didCopyPath: didCopyConfigPath,
                copyConfig: copyConfiguration,
                copyPath: copyConfigPath,
                reload: loadHosts
            )
        }
        .padding(18)
        .frame(minWidth: 920, minHeight: 620)
        .task {
            loadHosts()
        }
        .task {
            await startAutoPingLoopIfNeeded()
        }
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
        .focusedSceneValue(\.openSelectedHost, openSelectedHostAction)
        .focusedSceneValue(\.pingSelectedHost, pingSelectedHostAction)
        .focusedSceneValue(\.selectedHostName, selectedHost?.name)
    }

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
                    .padding(22)
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

    private var selectedHost: RemoteHost? {
        guard let selectedHostID else {
            return filteredHosts.first ?? hosts.first
        }

        return hosts.first(where: { $0.id == selectedHostID }) ?? filteredHosts.first ?? hosts.first
    }

    private var openSelectedHostAction: (() -> Void)? {
        guard let host = selectedHost else {
            return nil
        }

        return {
            openPreferred(for: host)
        }
    }

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
    private func add(_ host: RemoteHost) {
        hosts.append(host)
        selectedHostID = host.id
        saveHosts()
    }

    @MainActor
    private func update(_ updatedHost: RemoteHost) {
        guard let index = hosts.firstIndex(where: { $0.id == updatedHost.id }) else {
            return
        }

        hosts[index] = updatedHost
        selectedHostID = updatedHost.id
        saveHosts()
    }

    @MainActor
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
    private func assignGroup(_ groupID: UUID?, to host: RemoteHost) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }) else {
            return
        }

        hosts[index] = hosts[index].withGroupID(groupID)
        saveConfiguration()
    }

    @MainActor
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
    private func openSSHSession(for host: RemoteHost) {
        if let error = TerminalService.openSSHSession(for: host) {
            showFeedback(.error, error.localizedDescription)
        }
    }

    @MainActor
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
    private func ping(_ host: RemoteHost) async {
        statuses[host.id] = .checking
        let result = await PingService.checkResult(address: host.address)
        statuses[host.id] = result.isReachable ? .online : .offline
        latencyMilliseconds[host.id] = result.averageLatencyMilliseconds
        lastCheckedAt[host.id] = Date()
    }

    @MainActor
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

    private var resolvedDefaultOpenMode: PreferredOpenMode {
        PreferredOpenMode(rawValue: defaultOpenModeRawValue) ?? AppSettings.defaultOpenMode
    }

    private var resolvedDefaultAutoPingMode: AppSettings.AutoPingMode {
        AppSettings.effectiveAutoPingMode(rawValue: defaultAutoPingModeRawValue)
    }

    private var resolvedDefaultAutoPingIntervalValue: Int {
        AppSettings.normalizedAutoPingIntervalValue(defaultAutoPingIntervalValue)
    }

    private func effectiveOpenMode(for host: RemoteHost) -> PreferredOpenMode {
        host.preferredOpenModeOrNil ?? resolvedDefaultOpenMode
    }

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
