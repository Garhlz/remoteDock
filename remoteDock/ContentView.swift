//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

struct ContentView: View {
    @State private var hosts: [RemoteHost] = []
    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var copiedFeedback: [UUID: String] = [:]
    @State private var errorMessage: String?
    @State private var configPath: String = ""
    @State private var didCopyConfigPath = false
    @State private var hostBeingEdited: RemoteHost?
    @State private var isAddingHost = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if hosts.isEmpty {
                ContentUnavailableView(
                    "No Hosts",
                    systemImage: "server.rack",
                    description: Text("RemoteDock could not load any hosts.")
                )
            } else {
                ForEach(hosts) { host in
                    let index = hosts.firstIndex(where: { $0.id == host.id }) ?? 0

                    HostCard(
                        host: host,
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
                        canMoveUp: index > 0,
                        canMoveDown: index < hosts.count - 1
                    )
                }
            }

            Spacer(minLength: 0)

            configPathFooter
        }
        .padding(24)
        .frame(width: 680, height: 440)
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RemoteDock")
                    .font(.largeTitle.bold())

                Text("Quick access to your SSH hosts")
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
    }

    private var configPathFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)

            Text(configPath.isEmpty ? "Config path unavailable" : configPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: copyConfigPath) {
                Label(didCopyConfigPath ? "Copied" : "Copy Path", systemImage: didCopyConfigPath ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(configPath.isEmpty)

            Button(action: loadHosts) {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
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

    private var isPingingAll: Bool {
        !hosts.isEmpty && hosts.allSatisfy { status(for: $0) == .checking }
    }

    @MainActor
    private func loadHosts() {
        do {
            hosts = try HostStore.loadOrCreateDefaults()
            configPath = try HostStore.configFileURL.path
        } catch {
            hosts = HostStore.defaultHosts

            if let path = try? HostStore.configFileURL.path {
                configPath = path
            }

            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func add(_ host: RemoteHost) {
        hosts.append(host)
        saveHosts()
    }

    @MainActor
    private func update(_ updatedHost: RemoteHost) {
        guard let index = hosts.firstIndex(where: { $0.id == updatedHost.id }) else {
            return
        }

        hosts[index] = updatedHost
        saveHosts()
    }

    @MainActor
    private func delete(_ host: RemoteHost) {
        hosts.removeAll { $0.id == host.id }
        statuses[host.id] = nil
        copiedFeedback[host.id] = nil
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
    private func ping(_ host: RemoteHost) async {
        statuses[host.id] = .checking
        statuses[host.id] = await PingService.check(address: host.address) ? .online : .offline
    }

    @MainActor
    private func pingAll() async {
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
    }

    private func status(for host: RemoteHost) -> HostStatus {
        statuses[host.id, default: .unknown]
    }
}
