import Foundation

public struct RemoteHost: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let username: String
    public let address: String
    public let port: Int?
    public let remoteDirectory: String?
    public let startupCommand: String?
    public let preferredOpenMode: PreferredOpenMode?
    public let autoPingIntervalMinutes: Int?

    public static let defaultAutoPingIntervalMinutes = 5

    public init(
        id: UUID = UUID(),
        name: String,
        username: String,
        address: String,
        port: Int? = nil,
        remoteDirectory: String? = nil,
        startupCommand: String? = nil,
        preferredOpenMode: PreferredOpenMode? = nil,
        autoPingIntervalMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.address = address
        self.port = Self.normalizedPort(port)
        self.remoteDirectory = Self.normalizedRemoteDirectory(remoteDirectory)
        self.startupCommand = Self.normalizedStartupCommand(startupCommand)
        self.preferredOpenMode = preferredOpenMode
        self.autoPingIntervalMinutes = Self.normalizedAutoPingIntervalMinutes(autoPingIntervalMinutes)
    }

    public var sshCommand: String {
        if let port {
            return "ssh -p \(port) \(sshTarget)"
        }

        return "ssh \(sshTarget)"
    }

    public var displayAddress: String {
        if let port {
            return "\(sshTarget):\(port)"
        }

        return sshTarget
    }

    public var sshTarget: String {
        "\(username)@\(address)"
    }

    public var sshAuthority: String {
        if let port {
            return "\(sshTarget):\(port)"
        }

        return sshTarget
    }

    public var usesTailscale: Bool {
        Self.looksLikeTailscaleAddress(address)
    }

    public var fullDetailsText: String {
        [
            "Name: \(name)",
            "Username: \(username)",
            "Address: \(address)",
            "Port: \(port.map(String.init) ?? "Default")",
            "SSH Target: \(sshTarget)",
            "Preferred Open Mode: \(effectiveOpenMode.title)",
            "Auto Ping Interval: \(effectiveAutoPingIntervalMinutes) min",
            "Remote Directory: \(effectiveRemoteDirectory)",
            "Startup Command: \(preferredStartupCommand ?? "Default behavior")"
        ]
        .joined(separator: "\n")
    }

    public var preferredRemoteDirectory: String? {
        Self.normalizedRemoteDirectory(remoteDirectory)
    }

    public var preferredStartupCommand: String? {
        Self.normalizedStartupCommand(startupCommand)
    }

    public var preferredOpenModeOrNil: PreferredOpenMode? {
        preferredOpenMode
    }

    public var preferredAutoPingIntervalMinutesOrNil: Int? {
        autoPingIntervalMinutes
    }

    public var effectiveOpenMode: PreferredOpenMode {
        preferredOpenMode ?? .ghostty
    }

    public var effectiveAutoPingIntervalMinutes: Int {
        autoPingIntervalMinutes ?? Self.defaultAutoPingIntervalMinutes
    }

    public var effectiveRemoteDirectory: String {
        preferredRemoteDirectory ?? suggestedRemoteDirectory
    }

    public var vscodeRemoteDirectory: String {
        effectiveRemoteDirectory
    }

    public var isWindowsHost: Bool {
        Self.looksLikeWindowsPath(effectiveRemoteDirectory) || Self.looksLikeWindowsName(name)
    }

    public var suggestedRemoteDirectory: String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("windows") || lowercasedName.contains("win") {
            return "C:/Users/\(username)"
        }

        if lowercasedName.contains("mac") {
            return "/Users/\(username)"
        }

        return "/home/\(username)"
    }

    public var suggestedStartupCommand: String? {
        guard isWindowsHost else {
            return nil
        }

        return #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
    }

    public func withRemoteDirectory(_ remoteDirectory: String?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes
        )
    }

    public func withStartupCommand(_ startupCommand: String?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes
        )
    }

    public func withPreferredOpenMode(_ preferredOpenMode: PreferredOpenMode?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes
        )
    }

    public func withAutoPingIntervalMinutes(_ autoPingIntervalMinutes: Int?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes
        )
    }

    private static func normalizedPort(_ value: Int?) -> Int? {
        guard let value, (1 ... 65535).contains(value) else {
            return nil
        }

        return value
    }

    private static func normalizedAutoPingIntervalMinutes(_ value: Int?) -> Int? {
        guard let value, (1 ... 1440).contains(value) else {
            return nil
        }

        return value
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

    private static func looksLikeTailscaleAddress(_ value: String) -> Bool {
        let lowercasedValue = value.lowercased()

        if lowercasedValue.hasSuffix(".ts.net") {
            return true
        }

        if lowercasedValue.hasPrefix("fd7a:115c:a1e0:") {
            return true
        }

        let components = value.split(separator: ".")
        guard components.count == 4,
              let firstOctet = Int(components[0]),
              let secondOctet = Int(components[1]),
              (0 ... 255).contains(firstOctet),
              (0 ... 255).contains(secondOctet) else {
            return false
        }

        return firstOctet == 100 && (64 ... 127).contains(secondOctet)
    }
}
