//
//  HostEditorView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

struct HostEditorView: View {
    private enum OpenModeSelection: String, CaseIterable, Identifiable {
        case useDefault
        case ghostty
        case defaultTerminal
        case vscode

        var id: String { rawValue }
    }

    private enum AutoPingSelection: String, CaseIterable, Identifiable {
        case useGlobal
        case customMinutes
        case never

        var id: String { rawValue }
    }

    let title: String
    let originalHost: RemoteHost?
    let availableGroups: [HostGroup]
    let save: (RemoteHost) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingModeKey) private var defaultAutoPingModeRawValue = AppSettings.defaultAutoPingMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingIntervalValueKey) private var defaultAutoPingIntervalValue = AppSettings.defaultAutoPingIntervalValue
    @State private var name: String
    @State private var username: String
    @State private var address: String
    @State private var port: String
    @State private var selectedGroupID: UUID?
    @State private var autoPingSelection: AutoPingSelection
    @State private var autoPingIntervalMinutes: String
    @State private var remoteDirectory: String
    @State private var startupCommand: String
    @State private var openModeSelection: OpenModeSelection
    @State private var validationMessage: String?
    private let startupCommandPlaceholder: String

    init(title: String, host: RemoteHost?, availableGroups: [HostGroup], save: @escaping (RemoteHost) -> Void) {
        self.title = title
        self.originalHost = host
        self.availableGroups = availableGroups
        self.save = save
        self.startupCommandPlaceholder = host?.suggestedStartupCommand ?? #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
        _name = State(initialValue: host?.name ?? "")
        _username = State(initialValue: host?.username ?? "")
        _address = State(initialValue: host?.address ?? "")
        _port = State(initialValue: host?.port.map(String.init) ?? "")
        _selectedGroupID = State(initialValue: host?.groupID)
        _autoPingSelection = State(initialValue: Self.autoPingSelection(for: host))
        _autoPingIntervalMinutes = State(initialValue: host?.preferredAutoPingIntervalMinutesOrNil.map(String.init) ?? "")
        _remoteDirectory = State(initialValue: host?.remoteDirectory ?? "")
        _startupCommand = State(initialValue: host?.startupCommand ?? "")
        _openModeSelection = State(initialValue: Self.selection(for: host?.preferredOpenModeOrNil))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

            Form {
                Section("Host") {
                    TextField("Name", text: $name)
                    TextField("Username", text: $username)
                    TextField("Address", text: $address)
                    TextField("Port", text: $port, prompt: Text("22"))

                    LabeledContent("Group") {
                        Picker("Group", selection: $selectedGroupID) {
                            Text("Ungrouped").tag(UUID?.none)

                            ForEach(availableGroups) { group in
                                Text(group.name).tag(group.id as UUID?)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .trailing)
                    }
                }

                Section("Open") {
                    LabeledContent("Open Mode") {
                        Picker("Open Mode", selection: $openModeSelection) {
                            Text("Use Global Default").tag(OpenModeSelection.useDefault)

                            Divider()

                            ForEach(OpenModeSelection.allCases.filter { $0 != .useDefault }, id: \.self) { mode in
                                Text(title(for: mode)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .trailing)
                    }

                    LabeledContent("Auto Ping") {
                        Picker("Auto Ping", selection: $autoPingSelection) {
                            Text("Use Global").tag(AutoPingSelection.useGlobal)
                            Text("Custom Interval").tag(AutoPingSelection.customMinutes)
                            Text("Never").tag(AutoPingSelection.never)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .trailing)
                    }

                    if autoPingSelection == .customMinutes {
                        TextField(
                            "Auto Ping Interval (min)",
                            text: $autoPingIntervalMinutes,
                            prompt: Text(hostAutoPingPrompt)
                        )
                    }
                    TextField("Remote Directory", text: $remoteDirectory, prompt: Text("/home/elaine"))
                    TextField("Startup Command", text: $startupCommand, prompt: Text(startupCommandPlaceholder))
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Preferred Open Mode controls the primary action in the host detail view.")
                Text("Use Global Default currently resolves to \(resolvedDefaultOpenMode.title).")
                Text("Auto Ping controls how often this host is checked in the background. Use Global follows \(globalHeartbeatDescription), and Never disables background checks for this host.")
                Text("Remote Directory is used by VS Code Remote and can be left empty for now.")
                Text("Startup Command is optional. It runs after SSH login, and you can use {remoteDirectory} as a placeholder.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    saveHost()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 430)
    }

    private func saveHost() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAutoPingIntervalMinutes = autoPingIntervalMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRemoteDirectory = remoteDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStartupCommand = startupCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Name cannot be empty."
            return
        }

        guard !trimmedUsername.isEmpty else {
            validationMessage = "Username cannot be empty."
            return
        }

        guard isValidAddress(trimmedAddress) else {
            validationMessage = "Address cannot be empty or contain spaces."
            return
        }

        guard isValidRemoteDirectory(trimmedRemoteDirectory) else {
            validationMessage = "Remote directory cannot contain line breaks."
            return
        }

        guard isValidPort(trimmedPort) else {
            validationMessage = "Port must be empty or a number between 1 and 65535."
            return
        }

        guard isValidAutoPingIntervalMinutes(trimmedAutoPingIntervalMinutes) else {
            validationMessage = "Auto ping interval must be empty or a number between 1 and 1440."
            return
        }

        guard isValidStartupCommand(trimmedStartupCommand) else {
            validationMessage = "Startup command cannot contain line breaks."
            return
        }

        let host = RemoteHost(
            id: originalHost?.id ?? UUID(),
            name: trimmedName,
            username: trimmedUsername,
            address: trimmedAddress,
            port: parsedPort(from: trimmedPort),
            groupID: selectedGroupID,
            remoteDirectory: trimmedRemoteDirectory,
            startupCommand: trimmedStartupCommand,
            preferredOpenMode: preferredOpenMode(from: openModeSelection),
            autoPingIntervalMinutes: parsedAutoPingIntervalMinutes(from: trimmedAutoPingIntervalMinutes),
            autoPingDisabled: autoPingSelection == .never ? true : nil
        )

        save(host)
        dismiss()
    }

    private func isValidAddress(_ value: String) -> Bool {
        !value.isEmpty && !value.contains(where: { $0.isWhitespace })
    }

    private func isValidRemoteDirectory(_ value: String) -> Bool {
        !value.contains(where: \.isNewline)
    }

    private func isValidPort(_ value: String) -> Bool {
        value.isEmpty || parsedPort(from: value) != nil
    }

    private func parsedPort(from value: String) -> Int? {
        guard !value.isEmpty else {
            return nil
        }

        guard let port = Int(value), (1 ... 65535).contains(port) else {
            return nil
        }

        return port
    }

    private func isValidAutoPingIntervalMinutes(_ value: String) -> Bool {
        autoPingSelection != .customMinutes || parsedAutoPingIntervalMinutes(from: value) != nil
    }

    private func parsedAutoPingIntervalMinutes(from value: String) -> Int? {
        guard !value.isEmpty else {
            return nil
        }

        guard let minutes = Int(value), (1 ... 1440).contains(minutes) else {
            return nil
        }

        return minutes
    }

    private func isValidStartupCommand(_ value: String) -> Bool {
        !value.contains(where: \.isNewline)
    }

    private var resolvedDefaultOpenMode: PreferredOpenMode {
        PreferredOpenMode(rawValue: defaultOpenModeRawValue) ?? AppSettings.defaultOpenMode
    }

    private var resolvedDefaultAutoPingMode: AppSettings.AutoPingMode {
        AppSettings.effectiveAutoPingMode(rawValue: defaultAutoPingModeRawValue)
    }

    private var globalHeartbeatDescription: String {
        AppSettings.heartbeatDescription(
            mode: resolvedDefaultAutoPingMode,
            value: defaultAutoPingIntervalValue
        )
    }

    private var hostAutoPingPrompt: String {
        switch resolvedDefaultAutoPingMode {
        case .seconds:
            "Use global (\(globalHeartbeatDescription))"
        case .minutes:
            "Use global (\(globalHeartbeatDescription))"
        case .manual:
            "Manual only unless overridden"
        }
    }

    private static func autoPingSelection(for host: RemoteHost?) -> AutoPingSelection {
        if host?.preferredAutoPingDisabledOrNil == true {
            return .never
        }

        if host?.preferredAutoPingIntervalMinutesOrNil != nil {
            return .customMinutes
        }

        return .useGlobal
    }

    private func preferredOpenMode(from selection: OpenModeSelection) -> PreferredOpenMode? {
        switch selection {
        case .useDefault:
            nil
        case .ghostty:
            .ghostty
        case .defaultTerminal:
            .defaultTerminal
        case .vscode:
            .vscode
        }
    }

    private static func selection(for mode: PreferredOpenMode?) -> OpenModeSelection {
        switch mode {
        case nil:
            .useDefault
        case .ghostty:
            .ghostty
        case .defaultTerminal:
            .defaultTerminal
        case .vscode:
            .vscode
        }
    }

    private func title(for selection: OpenModeSelection) -> String {
        switch selection {
        case .useDefault:
            "Use Global Default"
        case .ghostty:
            PreferredOpenMode.ghostty.title
        case .defaultTerminal:
            PreferredOpenMode.defaultTerminal.title
        case .vscode:
            PreferredOpenMode.vscode.title
        }
    }
}
