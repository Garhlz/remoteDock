import SwiftUI
import RemoteDockCore

struct HostsSidebarView: View {
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

    private var expandedControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search hosts", text: $searchText)
                    .textFieldStyle(.plain)

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

private struct SidebarTagView: View {
    let title: String
    let systemImage: String

    var body: some View {
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
                        .foregroundStyle(.primary)
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
