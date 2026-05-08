//
//  ContentView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

struct ContentView: View {
    private let hosts = [
        RemoteHost(name: "Arch T480s", username: "elaine", address: "100.117.140.113"),
        RemoteHost(name: "Windows Omen16", username: "elaine", address: "100.102.71.37")
    ]

    @State private var statuses: [UUID: HostStatus] = [:]
    @State private var copiedFeedback: [UUID: String] = [:]
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ForEach(hosts) { host in
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
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 620, height: 380)
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
                Task {
                    await pingAll()
                }
            }) {
                Label(isPingingAll ? "Checking" : "Ping All", systemImage: "network")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPingingAll)
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
        hosts.allSatisfy { status(for: $0) == .checking }
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
