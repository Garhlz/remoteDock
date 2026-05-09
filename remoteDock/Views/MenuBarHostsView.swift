import SwiftUI
import RemoteDockCore

struct MenuBarHostsView: View {
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue
    @Environment(\.openWindow) private var openWindow

    @State private var hosts: [RemoteHost] = []
    @State private var groups: [HostGroup] = []
    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var latencyMilliseconds: [UUID: Double] = [:]
    @State private var lastCheckedAt: [UUID: Date] = [:]
    @State private var errorMessage: String?
    @State private var isPingingAll = false

    var body: some View {
        Group {
            Button("Show Main Window") {
                showMainWindow()
            }

            Button(isPingingAll ? "Checking All Hosts..." : "Ping All Hosts") {
                pingAll()
            }
            .disabled(hosts.isEmpty || isPingingAll)

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if hosts.isEmpty {
                Text("No hosts configured")
                    .foregroundStyle(.secondary)
            } else {
                statusSummary

                ForEach(hostGroups) { group in
                    if !group.hosts.isEmpty {
                        Section(group.title) {
                            ForEach(group.hosts) { host in
                                hostMenu(for: host)
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Reload Hosts") {
                loadHosts()
            }

            Button("Quit RemoteDock") {
                NSApp.terminate(nil)
            }
        }
        .onAppear {
            loadHosts()
        }
    }

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

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = existingMainWindow() {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            return
        }

        openWindow(id: "main")
    }

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
        VStack(alignment: .leading, spacing: 4) {
            Text("\(hosts.count) hosts")
                .font(.subheadline.weight(.semibold))

            Text("Online \(onlineCount)  •  Offline \(offlineCount)  •  Unchecked \(uncheckedCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

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
                Spacer()
                Text(host.address)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func primaryActionTitle(for host: RemoteHost) -> String {
        effectiveOpenMode(for: host).actionTitle
    }

    private func effectiveOpenMode(for host: RemoteHost) -> PreferredOpenMode {
        host.preferredOpenModeOrNil ?? (PreferredOpenMode(rawValue: defaultOpenModeRawValue) ?? AppSettings.defaultOpenMode)
    }

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

        if value >= 100 {
            return String(format: "%.0f ms", value)
        }

        return String(format: "%.1f ms", value)
    }
}

private struct HostMenuSection: Identifiable {
    let title: String
    let hosts: [RemoteHost]

    var id: String { title }
}
