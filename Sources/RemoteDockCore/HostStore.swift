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
        let url = try configFileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            try save(defaultHosts)
            return defaultHosts
        }

        do {
            let data = try Data(contentsOf: url)
            let hosts = try JSONDecoder().decode([RemoteHost].self, from: data)
            let normalizedHosts = migrateDefaultsIfNeeded(in: hosts)

            if normalizedHosts != hosts {
                try save(normalizedHosts)
            }

            return normalizedHosts
        } catch let error as DecodingError {
            throw HostStoreError.decodeFailed(url, error)
        } catch {
            throw HostStoreError.readFailed(url, error)
        }
    }

    public static func save(_ hosts: [RemoteHost]) throws {
        let url = try configFileURL
        let directoryURL = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(hosts)
            try data.write(to: url, options: .atomic)
        } catch {
            throw HostStoreError.writeFailed(url, error)
        }
    }

    private static func migrateDefaultsIfNeeded(in hosts: [RemoteHost]) -> [RemoteHost] {
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
}
