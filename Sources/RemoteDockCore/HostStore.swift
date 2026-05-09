import Foundation

/// 配置读写过程中可能出现的结构化错误。
public enum HostStoreError: LocalizedError {
    case applicationSupportUnavailable
    case readFailed(URL, Error)
    case writeFailed(URL, Error)
    case decodeFailed(URL, Error)

    /// 把底层文件系统 / 解码错误翻译成更适合直接展示给用户的消息。
    ///
    /// 这里区分 read / write / decode 的意义，不只是为了技术上分类，
    /// 更是为了让 UI 能给出“配置坏了”还是“磁盘写失败了”这类不同语义。
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

/// 主机配置文档的默认值、加载、保存与迁移入口。
///
/// 这是项目里“磁盘配置”和“内存模型”之间的桥梁：
/// - 负责确定配置文件放在哪里；
/// - 负责把 JSON 解码成 Swift 模型；
/// - 负责把 Swift 模型重新编码并写回磁盘；
/// - 负责兼容旧版本配置并在读取时做一次迁移修正。
public enum HostStore {
    /// 首次创建配置时写入的默认主机样例。
    /// 它既是初次体验入口，也能作为配置结构示例。
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

    /// 应用配置文件的标准位置：`~/Library/Application Support/RemoteDock/hosts.json`
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

    /// 只关心 host 列表时的便捷读取接口。
    /// 它会复用完整配置加载逻辑，再把 `hosts` 提取出来。
    public static func loadOrCreateDefaults() throws -> [RemoteHost] {
        try loadOrCreateConfiguration().hosts
    }

    /// 测试专用版本，允许在临时目录中验证“创建或读取默认配置”的行为。
    static func loadOrCreateDefaults(at url: URL) throws -> [RemoteHost] {
        try loadOrCreateConfiguration(at: url).hosts
    }

    /// 读取完整配置。
    /// 如果文件不存在，会先写入一个默认配置，再把它返回给调用方。
    public static func loadOrCreateConfiguration() throws -> RemoteDockConfiguration {
        try loadOrCreateConfiguration(at: configFileURL)
    }

    /// 内部实现同时兼容两种历史格式：
    /// 1. 新格式：`RemoteDockConfiguration`
    /// 2. 旧格式：直接存一个 `[RemoteHost]`
    ///
    /// 读取成功后还会做一次 migration，把缺失的默认值、无效分组引用等问题修正掉。
    ///
    /// 这里采用“读时迁移并写回”的策略，而不是单独提供升级命令，
    /// 是因为这个项目的配置规模很小，且用户通常只关心“旧文件还能不能直接继续用”。
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

    /// 当调用方只有 host 数组时，自动包装成完整配置文档再保存。
    public static func save(_ hosts: [RemoteHost]) throws {
        try save(RemoteDockConfiguration(hosts: hosts), to: configFileURL)
    }

    /// 与公开版本对应的测试辅助入口。
    static func save(_ hosts: [RemoteHost], to url: URL) throws {
        try save(RemoteDockConfiguration(hosts: hosts), to: url)
    }

    /// 写入完整配置文档的公开入口。
    public static func save(_ configuration: RemoteDockConfiguration) throws {
        try save(configuration, to: configFileURL)
    }

    /// 写入时会先确保目录存在，再用 pretty JSON 原子性落盘，尽量降低写坏文件的风险。
    ///
    /// 这里特意用 `.atomic`，是为了把“程序中断时留下半个 JSON 文件”的概率降到更低。
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

    /// 给旧数据补齐“后来才引入”的推导字段，例如远程目录和启动命令。
    ///
    /// 注意这里不是无条件覆盖，而是只在旧数据缺字段时补默认值。
    /// 也就是说：迁移只负责“补洞”，不负责重写用户已经明确配置过的内容。
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

    /// 对完整配置做结构修正：
    /// - 去掉重复分组 ID；
    /// - 清除 host 上指向不存在分组的 `groupID`；
    /// - 对每台主机补默认值。
    ///
    /// 把这一步放在 Store 层而不是视图层，原因是这些规则属于“配置有效性”，
    /// 它们应该在任何读取入口都成立，而不应该依赖某个页面是否恰好做了清理。
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

    /// 按 ID 去重，保留第一次出现的分组。
    private static func deduplicatedGroups(from groups: [HostGroup]) -> [HostGroup] {
        var seenIDs = Set<UUID>()

        return groups.filter { group in
            seenIDs.insert(group.id).inserted
        }
    }
}
