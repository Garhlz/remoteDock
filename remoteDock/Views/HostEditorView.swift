//
//  HostEditorView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

struct HostEditorView: View {
    let title: String
    let originalHost: RemoteHost?
    let save: (RemoteHost) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var username: String
    @State private var address: String
    @State private var validationMessage: String?

    init(title: String, host: RemoteHost?, save: @escaping (RemoteHost) -> Void) {
        self.title = title
        self.originalHost = host
        self.save = save
        _name = State(initialValue: host?.name ?? "")
        _username = State(initialValue: host?.username ?? "")
        _address = State(initialValue: host?.address ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

            Form {
                TextField("Name", text: $name)
                TextField("Username", text: $username)
                TextField("Address", text: $address)
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

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
        .frame(width: 420)
    }

    private func saveHost() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

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

        let host = RemoteHost(
            id: originalHost?.id ?? UUID(),
            name: trimmedName,
            username: trimmedUsername,
            address: trimmedAddress
        )

        save(host)
        dismiss()
    }

    private func isValidAddress(_ value: String) -> Bool {
        !value.isEmpty && !value.contains(where: { $0.isWhitespace })
    }
}
