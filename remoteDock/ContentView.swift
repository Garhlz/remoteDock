//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

struct ContentView: View {
    private enum HostFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case online = "Online"
        case offline = "Offline"
        case unchecked = "Unchecked"

        var id: String { rawValue }
    }

    private struct FeedbackMessage: Identifiable, Equatable {
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

    private struct SidebarSection: Identifiable {
        let id: String
        let title: String
        let hosts: [RemoteHost]
    }

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
            topBar
            if let feedbackMessage {
                feedbackBanner(for: feedbackMessage)
            }

            HSplitView {
                sidebar
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 270)

                detailPane
                    .frame(minWidth: 520, idealWidth: 760, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            configPathFooter
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
            tailscaleStatusSheet
        }
        .focusedSceneValue(\.openSelectedHost, openSelectedHostAction)
        .focusedSceneValue(\.pingSelectedHost, pingSelectedHostAction)
        .focusedSceneValue(\.selectedHostName, selectedHost?.name)
    }

    private var topBar: some View {
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
                compactMetric(title: "Hosts", value: "\(hosts.count)")
                compactMetric(title: "Online", value: "\(onlineHostsCount)")
                compactMetric(title: "Unchecked", value: "\(uncheckedHostsCount)")
            }

            Button(action: {
                isAddingHost = true
            }) {
                Label("Add Host", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Button(action: {
                Task {
                    await pingAll()
                }
            }) {
                Label(isPingingAll ? "Checking" : "Ping All", systemImage: "network")
            }
            .buttonStyle(.borderedProminent)
            .disabled(hosts.isEmpty || isPingingAll)
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

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hosts")
                        .font(.headline)

                    Text("\(hosts.count) configured  •  \(groups.count) groups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isManagingGroups = true
                } label: {
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

            if isSidebarControlsExpanded {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search hosts", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
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
            } else if !searchText.isEmpty || selectedFilter != .all {
                HStack(spacing: 8) {
                    if !searchText.isEmpty {
                        collapsedControlTag(title: searchText, systemImage: "magnifyingglass")
                    }

                    if selectedFilter != .all {
                        collapsedControlTag(title: selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity)
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
                                    openModeSystemImage: effectiveOpenMode(for: host).systemImage,
                                    status: status(for: host),
                                    latencyText: latencyText(for: host),
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

    private var detailPane: some View {
        Group {
            if let host = selectedHost {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        detailHeader(for: host)

                            HostCard(
                            preferredOpenMode: effectiveOpenMode(for: host),
                            status: status(for: host),
                            copiedLabel: copiedFeedback[host.id],
                            openPreferred: {
                                openPreferred(for: host)
                            },
                            copySSHCommand: {
                                copy(host.sshCommand, label: "SSH", for: host)
                            },
                            copyIPAddress: {
                                copy(host.address, label: "IP", for: host)
                            },
                            copyHostDetails: {
                                copy(fullDetailsText(for: host), label: "Host", for: host)
                            },
                            openSSH: {
                                openSSHSession(for: host)
                            },
                            openDefaultTerminal: {
                                openDefaultTerminalSession(for: host)
                            },
                            openVSCodeRemote: {
                                openVSCodeRemote(for: host)
                            },
                            showTailscaleStatus: {
                                showTailscaleStatus(for: host)
                            },
                            showsTailscaleStatusAction: host.usesTailscale,
                            ping: {
                                Task {
                                    await ping(host)
                                }
                            },
                            edit: {
                                hostBeingEdited = host
                            },
                            delete: {
                                delete(host)
                            },
                            moveUp: {
                                move(host, by: -1)
                            },
                            moveDown: {
                                move(host, by: 1)
                            },
                            canMoveUp: canMove(host, by: -1),
                            canMoveDown: canMove(host, by: 1)
                        )

                        hostMetadata(for: host)
                    }
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

    private var configPathFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Config File", systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .help("RemoteDock host configuration file")

                Text(configPath.isEmpty ? "Config path unavailable" : configPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Button(action: copyConfigPath) {
                Label(didCopyConfigPath ? "Copied" : "Copy Path", systemImage: didCopyConfigPath ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(configPath.isEmpty)
            .help("Copy the config file path")

            Button(action: loadHosts) {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help("Reload hosts from disk")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
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
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var sidebarSections: [SidebarSection] {
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

    private func compactMetric(title: String, value: String) -> some View {
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

    private func collapsedControlTag(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }

    private func detailHeader(for host: RemoteHost) -> some View {
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

                Label(status(for: host).rawValue, systemImage: status(for: host).systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status(for: host).color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(status(for: host).color.opacity(0.12))
                    .clipShape(Capsule())
                    .help(statusTooltip(for: status(for: host)))
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    detailTag(title: host.username, systemImage: "person")
                    detailTag(title: effectiveOpenMode(for: host).title, systemImage: effectiveOpenMode(for: host).systemImage)
                    groupAssignmentMenu(for: host)
                    detailTag(title: host.effectiveRemoteDirectory, systemImage: "folder")

                    if host.preferredStartupCommand != nil {
                        detailTag(title: "Custom startup", systemImage: "bolt")
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    detailTag(title: host.username, systemImage: "person")
                    detailTag(title: effectiveOpenMode(for: host).title, systemImage: effectiveOpenMode(for: host).systemImage)
                    groupAssignmentMenu(for: host)
                    detailTag(title: host.effectiveRemoteDirectory, systemImage: "folder")

                    if host.preferredStartupCommand != nil {
                        detailTag(title: "Custom startup", systemImage: "bolt")
                    }
                }
            }
        }
    }

    private func hostMetadata(for host: RemoteHost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Details")
                .font(.headline)

            detailGridRow(
                leftTitle: "Username",
                leftValue: host.username,
                rightTitle: "Preferred Open",
                rightValue: effectiveOpenMode(for: host).title
            )

            detailGridRow(
                leftTitle: "Endpoint",
                leftValue: host.port.map { "\(host.address):\($0)" } ?? host.address,
                rightTitle: "Auto Ping",
                rightValue: effectiveAutoPingDescription(for: host)
            )

            detailGridRow(
                leftTitle: "Group",
                leftValue: groupName(for: host) ?? "Ungrouped",
                rightTitle: "Latency",
                rightValue: latencyText(for: host) ?? "Unavailable"
            )

            HStack(alignment: .top, spacing: 18) {
                detailCell(title: "Remote Directory", value: host.effectiveRemoteDirectory)
                lastCheckedDetailCell(for: host)
            }

            detailGridRow(
                leftTitle: "Current Status",
                leftValue: status(for: host).rawValue,
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

    private func lastCheckedDetailCell(for host: RemoteHost) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Checked")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let date = lastCheckedAt[host.id] {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, style: .relative)
                        .font(.system(.body, design: .monospaced))

                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .help(date.formatted(date: .complete, time: .standard))
            } else {
                Text("Not checked yet")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func groupAssignmentMenu(for host: RemoteHost) -> some View {
        Menu {
            Button(host.groupID == nil ? "Ungrouped" : "Move to Ungrouped") {
                assignGroup(nil, to: host)
            }

            if !groups.isEmpty {
                Divider()

                ForEach(groups) { group in
                    Button {
                        assignGroup(group.id, to: host)
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
            detailTag(title: groupName(for: host) ?? "Ungrouped", systemImage: "folder.badge.person.crop")
        }
        .menuStyle(.borderlessButton)
        .help("Change host group")
    }

    private func groupName(for host: RemoteHost) -> String? {
        guard let groupID = host.groupID else {
            return nil
        }

        return groups.first(where: { $0.id == groupID })?.name
    }

    private func statusTooltip(for status: HostStatus) -> String {
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
        default:
            "\(label) copied for \(host.name)."
        }
    }

    private func feedbackBanner(for feedback: FeedbackMessage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feedback.kind.systemImage)
                .font(.headline)
                .foregroundStyle(feedback.kind.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.kind.title)
                    .font(.subheadline.weight(.semibold))

                Text(feedback.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Button {
                feedbackMessage = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(feedback.kind.tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(feedback.kind.tint.opacity(0.28))
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.18), value: feedback.id)
    }

    private var tailscaleStatusSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Local Tailscale Status")
                    .font(.title2.bold())

                Spacer()

                Button("Done") {
                    tailscaleStatusText = nil
                }
            }

            ScrollView {
                Text(tailscaleStatusText ?? "")
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(14)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()

                Button("Copy") {
                    guard let tailscaleStatusText else {
                        return
                    }

                    ClipboardService.copy(tailscaleStatusText)
                    showFeedback(.success, "Local Tailscale status copied.")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
    }
}

private struct HostSidebarRow: View {
    let host: RemoteHost
    let openModeSystemImage: String
    let status: HostStatus
    let latencyText: String?
    let lastCheckedAt: Date?
    let isSelected: Bool

    var body: some View {
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
                        .foregroundStyle(isSelected ? .primary : .primary)
                        .lineLimit(1)
                }

                Text(host.displayAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.72) : Color.secondary)
                    .lineLimit(1)

                if let latencyText, status == .online {
                    Text(latencyText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.68) : status.color)
                        .lineLimit(1)
                }

                if let lastCheckedAt {
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
