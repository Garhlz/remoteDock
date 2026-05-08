//
//  RemoteHost.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import Foundation

struct RemoteHost: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let name: String
    let username: String
    let address: String
    let remoteDirectory: String?
    let startupCommand: String?

    init(
        id: UUID = UUID(),
        name: String,
        username: String,
        address: String,
        remoteDirectory: String? = nil,
        startupCommand: String? = nil
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.address = address
        self.remoteDirectory = Self.normalizedRemoteDirectory(remoteDirectory)
        self.startupCommand = Self.normalizedStartupCommand(startupCommand)
    }

    var sshCommand: String {
        "ssh \(sshTarget)"
    }

    var displayAddress: String {
        sshTarget
    }

    var sshTarget: String {
        "\(username)@\(address)"
    }

    var preferredRemoteDirectory: String? {
        Self.normalizedRemoteDirectory(remoteDirectory)
    }

    var preferredStartupCommand: String? {
        Self.normalizedStartupCommand(startupCommand)
    }

    var effectiveRemoteDirectory: String {
        preferredRemoteDirectory ?? suggestedRemoteDirectory
    }

    var vscodeRemoteDirectory: String {
        effectiveRemoteDirectory
    }

    var isWindowsHost: Bool {
        Self.looksLikeWindowsPath(effectiveRemoteDirectory) || Self.looksLikeWindowsName(name)
    }

    var suggestedRemoteDirectory: String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("windows") || lowercasedName.contains("win") {
            return "C:/Users/\(username)"
        }

        if lowercasedName.contains("mac") {
            return "/Users/\(username)"
        }

        return "/home/\(username)"
    }

    var suggestedStartupCommand: String? {
        guard isWindowsHost else {
            return nil
        }

        return #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
    }

    func withRemoteDirectory(_ remoteDirectory: String?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand
        )
    }

    func withStartupCommand(_ startupCommand: String?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand
        )
    }

    private static func normalizedRemoteDirectory(_ value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    private static func normalizedStartupCommand(_ value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    private static func looksLikeWindowsPath(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z]:[/\\]"#, options: .regularExpression) != nil
    }

    private static func looksLikeWindowsName(_ value: String) -> Bool {
        let lowercasedValue = value.lowercased()
        return lowercasedValue.contains("windows") || lowercasedValue.contains("win")
    }
}
