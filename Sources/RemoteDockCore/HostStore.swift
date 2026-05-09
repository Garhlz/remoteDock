import Foundation

public enum HostStoreError: LocalizedError {
    case applicationSupportUnavailable
    case readFailed(URL, Error)
    case writeFailed(URL, Error)
    case decodeFailed(URL, Error)

    public var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            "无法找到 Application Support 目录。"
        case .readFailed(let url, let error):
            "读取主机配置失败：\(url.path)\n\(error.localizedDescription)"
        case .writeFailed(let url, let error):
            "保存主机配置失败：\(url.path)\n\(error.localizedDescription)"
        case .decodeFailed(let url, let error):
            "主机配置 JSON 格式无效：\(url.path)\n\(error.localizedDescription)"
        }
    }
}

public enum HostStore {
    public static let defaultHosts = [
        RemoteHost(
            name: "Arch T480s",
            username: "elaine",
            address: "100.117.140.113",
            remoteDirectory: "/home/elaine"
        ),
        RemoteHost(
            name: "Windows Omen16",
            username: "elaine",
            address: "100.102.71.37",
            remoteDirectory: "C:/Users/elaine",
            startupCommand: #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
        )
    ]

    public static var configFileURL: URL {
        get throws {
            guard let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw HostStoreError.applicationSupportUnavailable
            }

            return applicationSupportURL
                .appendingPathComponent("RemoteDock", isDirectory: true)
                .appendingPathComponent("hosts.json", isDirectory: false)
        }
    }

    public static func loadOrCreateDefaults() throws -> [RemoteHost] {
        try loadOrCreateConfiguration().hosts
    }

    static func loadOrCreateDefaults(at url: URL) throws -> [RemoteHost] {
        try loadOrCreateConfiguration(at: url).hosts
    }

    public static func loadOrCreateConfiguration() throws -> RemoteDockConfiguration {
        try loadOrCreateConfiguration(at: configFileURL)
    }

    static func loadOrCreateConfiguration(at url: URL) throws -> RemoteDockConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let defaultConfiguration = RemoteDockConfiguration(hosts: defaultHosts)
            try save(defaultConfiguration, to: url)
            return defaultConfiguration
        }

        do {
            let data = try Data(contentsOf: url)

            if let configuration = try? JSONDecoder().decode(RemoteDockConfiguration.self, from: data) {
                let normalizedConfiguration = migrateDefaultsIfNeeded(in: configuration)

                if normalizedConfiguration != configuration {
                    try save(normalizedConfiguration, to: url)
                }

                return normalizedConfiguration
            }

            let legacyHosts = try JSONDecoder().decode([RemoteHost].self, from: data)
            let normalizedConfiguration = migrateDefaultsIfNeeded(in: RemoteDockConfiguration(hosts: legacyHosts))
            try save(normalizedConfiguration, to: url)
            return normalizedConfiguration
        } catch let error as DecodingError {
            throw HostStoreError.decodeFailed(url, error)
        } catch {
            throw HostStoreError.readFailed(url, error)
        }
    }

    public static func save(_ hosts: [RemoteHost]) throws {
        try save(RemoteDockConfiguration(hosts: hosts), to: configFileURL)
    }

    static func save(_ hosts: [RemoteHost], to url: URL) throws {
        try save(RemoteDockConfiguration(hosts: hosts), to: url)
    }

    public static func save(_ configuration: RemoteDockConfiguration) throws {
        try save(configuration, to: configFileURL)
    }

    static func save(_ configuration: RemoteDockConfiguration, to url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: .atomic)
        } catch {
            throw HostStoreError.writeFailed(url, error)
        }
    }

    static func migrateDefaultsIfNeeded(in hosts: [RemoteHost]) -> [RemoteHost] {
        hosts.map { host in
            let hostWithDirectory = if host.preferredRemoteDirectory == nil {
                host.withRemoteDirectory(host.suggestedRemoteDirectory)
            } else {
                host
            }

            guard hostWithDirectory.preferredStartupCommand == nil,
                  let suggestedStartupCommand = hostWithDirectory.suggestedStartupCommand else {
                return hostWithDirectory
            }

            return hostWithDirectory.withStartupCommand(suggestedStartupCommand)
        }
    }

    static func migrateDefaultsIfNeeded(in configuration: RemoteDockConfiguration) -> RemoteDockConfiguration {
        let normalizedGroups = deduplicatedGroups(from: configuration.groups)
        let validGroupIDs = Set(normalizedGroups.map(\.id))
        let normalizedHosts = migrateDefaultsIfNeeded(in: configuration.hosts).map { host in
            guard let groupID = host.groupID, !validGroupIDs.contains(groupID) else {
                return host
            }

            return host.withGroupID(nil)
        }

        return RemoteDockConfiguration(hosts: normalizedHosts, groups: normalizedGroups)
    }

    private static func deduplicatedGroups(from groups: [HostGroup]) -> [HostGroup] {
        var seenIDs = Set<UUID>()

        return groups.filter { group in
            seenIDs.insert(group.id).inserted
        }
    }
}
