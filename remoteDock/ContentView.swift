//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

struct ContentView: View {
    @State private var hosts: [RemoteHost] = []
    @State private var selectedHostID: UUID?
    @State private var searchText: String = ""
    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var copiedFeedback: [UUID: String] = [:]
    @State private var errorMessage: String?
    @State private var configPath: String = ""
    @State private var didCopyConfigPath = false
    @State private var hostBeingEdited: RemoteHost?
    @State private var isAddingHost = false
    @State private var isPingingAll = false

    var body: some View {
        VStack(spacing: 14) {
            topBar

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
        .sheet(isPresented: $isAddingHost) {
            HostEditorView(title: "Add Host", host: nil) { host in
                add(host)
            }
        }
        .sheet(item: $hostBeingEdited) { host in
            HostEditorView(title: "Edit Host", host: host) { updatedHost in
                update(updatedHost)
            }
        }
        .alert("操作失败", isPresented: hasErrorMessage) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
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

                    Text("\(hosts.count) configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

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
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()

            if filteredHosts.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Hosts" : "No Results",
                    systemImage: searchText.isEmpty ? "server.rack" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? "Add your first host to get started."
                        : "Try a different name, address, username, or path."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedHostID) {
                    ForEach(filteredHosts) { host in
                        HostSidebarRow(
                            host: host,
                            status: status(for: host),
                            isSelected: selectedHostID == host.id
                        )
                        .tag(host.id)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        .listRowBackground(Color.clear)
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
                            status: status(for: host),
                            copiedLabel: copiedFeedback[host.id],
                            copySSHCommand: {
                                copy(host.sshCommand, label: "SSH", for: host)
                            },
                            copyIPAddress: {
                                copy(host.address, label: "IP", for: host)
                            },
                            openSSH: {
                                openSSHSession(for: host)
                            },
                            openVSCodeRemote: {
                                openVSCodeRemote(for: host)
                            },
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
                            canMoveUp: hostIndex(for: host) > 0,
                            canMoveDown: hostIndex(for: host) < hosts.count - 1
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

    private var hasErrorMessage: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
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

    private var onlineHostsCount: Int {
        hosts.filter { status(for: $0) == .online }.count
    }

    private var uncheckedHostsCount: Int {
        hosts.filter { status(for: $0) == .unknown }.count
    }

    private var filteredHosts: [RemoteHost] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return hosts
        }

        let normalizedQuery = query.lowercased()

        return hosts.filter { host in
            host.name.lowercased().contains(normalizedQuery) ||
            host.username.lowercased().contains(normalizedQuery) ||
            host.address.lowercased().contains(normalizedQuery) ||
            host.effectiveRemoteDirectory.lowercased().contains(normalizedQuery)
        }
    }

    @MainActor
    private func loadHosts() {
        do {
            hosts = try HostStore.loadOrCreateDefaults()
            configPath = try HostStore.configFileURL.path
            syncSelection()
        } catch {
            hosts = HostStore.defaultHosts

            if let path = try? HostStore.configFileURL.path {
                configPath = path
            }

            syncSelection()
            errorMessage = error.localizedDescription
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

        let newIndex = currentIndex + offset
        guard hosts.indices.contains(newIndex) else {
            return
        }

        hosts.swapAt(currentIndex, newIndex)
        saveHosts()
    }

    @MainActor
    private func saveHosts() {
        do {
            try HostStore.save(hosts)
            configPath = try HostStore.configFileURL.path
            syncSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func copy(_ text: String, label: String, for host: RemoteHost) {
        ClipboardService.copy(text)
        copiedFeedback[host.id] = label

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

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopyConfigPath = false
        }
    }

    @MainActor
    private func openSSHSession(for host: RemoteHost) {
        if let message = TerminalService.openSSHSession(for: host) {
            errorMessage = message
        }
    }

    @MainActor
    private func openVSCodeRemote(for host: RemoteHost) {
        if let message = VSCodeService.openRemoteFolder(for: host) {
            errorMessage = message
        }
    }

    @MainActor
    private func ping(_ host: RemoteHost) async {
        statuses[host.id] = .checking
        statuses[host.id] = await PingService.check(address: host.address) ? .online : .offline
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

        await withTaskGroup(of: (UUID, Bool).self) { group in
            for host in hosts {
                group.addTask {
                    let isOnline = await PingService.check(address: host.address)
                    return (host.id, isOnline)
                }
            }

            for await (hostID, isOnline) in group {
                statuses[hostID] = isOnline ? .online : .offline
            }
        }

        isPingingAll = false
    }

    private func status(for host: RemoteHost) -> HostStatus {
        statuses[host.id, default: .unknown]
    }

    private func hostIndex(for host: RemoteHost) -> Int {
        hosts.firstIndex(where: { $0.id == host.id }) ?? 0
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
                    detailTag(title: host.effectiveRemoteDirectory, systemImage: "folder")

                    if host.preferredStartupCommand != nil {
                        detailTag(title: "Custom startup", systemImage: "bolt")
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    detailTag(title: host.username, systemImage: "person")
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
                rightTitle: "Address",
                rightValue: host.address
            )

            detailGridRow(
                leftTitle: "Remote Directory",
                leftValue: host.effectiveRemoteDirectory,
                rightTitle: "VS Code Target",
                rightValue: host.vscodeRemoteDirectory
            )

            detailRow(title: "Startup Command", value: host.preferredStartupCommand ?? "Default behavior")
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
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
}

private struct HostSidebarRow: View {
    let host: RemoteHost
    let status: HostStatus
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(status.color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(host.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(host.displayAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if host.preferredStartupCommand != nil {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("This host runs a custom startup command after SSH login")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
