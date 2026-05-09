//
//  HostEditorView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

struct HostEditorView: View {
    let title: String
    let originalHost: RemoteHost?
    let save: (RemoteHost) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var username: String
    @State private var address: String
    @State private var port: String
    @State private var autoPingIntervalMinutes: String
    @State private var remoteDirectory: String
    @State private var startupCommand: String
    @State private var preferredOpenMode: PreferredOpenMode
    @State private var validationMessage: String?
    private let startupCommandPlaceholder: String

    init(title: String, host: RemoteHost?, save: @escaping (RemoteHost) -> Void) {
        self.title = title
        self.originalHost = host
        self.save = save
        self.startupCommandPlaceholder = host?.suggestedStartupCommand ?? #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
        _name = State(initialValue: host?.name ?? "")
        _username = State(initialValue: host?.username ?? "")
        _address = State(initialValue: host?.address ?? "")
        _port = State(initialValue: host?.port.map(String.init) ?? "")
        _autoPingIntervalMinutes = State(initialValue: host?.preferredAutoPingIntervalMinutesOrNil.map(String.init) ?? "")
        _remoteDirectory = State(initialValue: host?.remoteDirectory ?? "")
        _startupCommand = State(initialValue: host?.startupCommand ?? "")
        _preferredOpenMode = State(initialValue: host?.effectiveOpenMode ?? .ghostty)
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
                }

                Section("Open") {
                    LabeledContent("Open Mode") {
                        Picker("Open Mode", selection: $preferredOpenMode) {
                            ForEach(PreferredOpenMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 170, alignment: .trailing)
                    }

                    TextField(
                        "Auto Ping Interval (min)",
                        text: $autoPingIntervalMinutes,
                        prompt: Text("\(RemoteHost.defaultAutoPingIntervalMinutes)")
                    )
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
                Text("Auto Ping Interval controls how often this host is checked in the background. Leave it empty to use the default.")
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
            remoteDirectory: trimmedRemoteDirectory,
            startupCommand: trimmedStartupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: parsedAutoPingIntervalMinutes(from: trimmedAutoPingIntervalMinutes)
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
        value.isEmpty || parsedAutoPingIntervalMinutes(from: value) != nil
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
}
