import Foundation
import Testing
@testable import RemoteDockCore

/// 覆盖配置读写、迁移和错误返回的测试集合。
///
/// 这些测试的重点不是 UI，而是验证配置文件生命周期：
/// - 第一次启动如何创建默认文件
/// - 老配置如何迁移到新结构
/// - 分组和主机引用如何保持一致
/// - 读写失败时是否返回可预期错误
struct HostStoreTests {
    /// 验证“文件不存在时自动创建默认配置”的冷启动路径。
    @Test
    func loadOrCreateDefaultsWritesDefaultHostsWhenFileDoesNotExist() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")

        let configuration = try HostStore.loadOrCreateConfiguration(at: configURL)

        #expect(configuration.hosts == HostStore.defaultHosts)
        #expect(configuration.groups.isEmpty)
        #expect(FileManager.default.fileExists(atPath: configURL.path))

        let savedData = try Data(contentsOf: configURL)
        let savedConfiguration = try JSONDecoder().decode(RemoteDockConfiguration.self, from: savedData)
        #expect(savedConfiguration.hosts == HostStore.defaultHosts)
        #expect(savedConfiguration.groups.isEmpty)
    }

    /// 验证新的配置文档格式能完整 round-trip，不丢 host 和 group 信息。
    @Test
    func saveAndReloadRoundTripsHosts() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let group = HostGroup(name: "Servers")
        let hosts = [
            RemoteHost(
                name: "Arch",
                username: "elaine",
                address: "100.117.140.113",
                port: 2222,
                groupID: group.id,
                remoteDirectory: "/srv/project",
                startupCommand: "exec zsh -l",
                preferredOpenMode: .vscode
            )
        ]
        let configuration = RemoteDockConfiguration(hosts: hosts, groups: [group])

        try HostStore.save(configuration, to: configURL)
        let loadedConfiguration = try HostStore.loadOrCreateConfiguration(at: configURL)

        #expect(loadedConfiguration == configuration)
    }

    /// 验证读取旧 host 数组格式时，会补齐后来新增的默认目录字段。
    @Test
    func loadOrCreateDefaultsMigratesMissingRemoteDirectory() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let oldHosts = [
            RemoteHost(
                name: "Arch T480s",
                username: "elaine",
                address: "100.117.140.113"
            )
        ]

        let data = try JSONEncoder().encode(oldHosts)
        try data.write(to: configURL)

        let migratedHosts = try HostStore.loadOrCreateDefaults(at: configURL)

        #expect(migratedHosts.count == 1)
        #expect(migratedHosts[0].preferredRemoteDirectory == "/home/elaine")

        let persistedData = try Data(contentsOf: configURL)
        let persistedConfiguration = try JSONDecoder().decode(RemoteDockConfiguration.self, from: persistedData)
        #expect(persistedConfiguration.hosts[0].preferredRemoteDirectory == "/home/elaine")
    }

    /// 验证 Windows 主机在迁移时会补出默认 startup command。
    @Test
    func loadOrCreateDefaultsMigratesWindowsStartupCommand() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let oldHosts = [
            RemoteHost(
                name: "Windows Omen16",
                username: "elaine",
                address: "100.102.71.37",
                remoteDirectory: "C:/Users/elaine"
            )
        ]

        let data = try JSONEncoder().encode(oldHosts)
        try data.write(to: configURL)

        let migratedHosts = try HostStore.loadOrCreateDefaults(at: configURL)

        #expect(migratedHosts.count == 1)
        #expect(migratedHosts[0].preferredStartupCommand == #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#)
    }

    /// 验证旧版 `[RemoteHost]` JSON 会被升级成新版 `RemoteDockConfiguration` 文档。
    @Test
    func loadOrCreateConfigurationMigratesLegacyHostsArrayToConfigurationDocument() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let oldHosts = [
            RemoteHost(
                name: "Arch T480s",
                username: "elaine",
                address: "100.117.140.113"
            )
        ]

        let data = try JSONEncoder().encode(oldHosts)
        try data.write(to: configURL)

        let configuration = try HostStore.loadOrCreateConfiguration(at: configURL)
        let persistedData = try Data(contentsOf: configURL)
        let persistedConfiguration = try JSONDecoder().decode(RemoteDockConfiguration.self, from: persistedData)

        #expect(configuration.groups.isEmpty)
        #expect(configuration.hosts.count == 1)
        #expect(persistedConfiguration == configuration)
    }

    /// 验证 host 上悬空的 `groupID` 会在读取时被清理掉。
    @Test
    func loadOrCreateConfigurationClearsDanglingGroupIDs() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let missingGroupID = UUID()
        let configuration = RemoteDockConfiguration(
            hosts: [
                RemoteHost(
                    name: "Arch",
                    username: "elaine",
                    address: "100.117.140.113",
                    groupID: missingGroupID
                )
            ],
            groups: []
        )

        let data = try JSONEncoder().encode(configuration)
        try data.write(to: configURL)

        let migratedConfiguration = try HostStore.loadOrCreateConfiguration(at: configURL)

        #expect(migratedConfiguration.hosts[0].groupID == nil)
    }

    /// 验证重复分组 ID 会在读取时被去重，避免出现不稳定结构。
    @Test
    func loadOrCreateConfigurationDeduplicatesGroupsByID() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let duplicatedID = UUID()
        let configuration = RemoteDockConfiguration(
            hosts: [
                RemoteHost(
                    name: "Arch",
                    username: "elaine",
                    address: "100.117.140.113",
                    groupID: duplicatedID
                )
            ],
            groups: [
                HostGroup(id: duplicatedID, name: "Servers"),
                HostGroup(id: duplicatedID, name: "Servers Duplicate")
            ]
        )

        let data = try JSONEncoder().encode(configuration)
        try data.write(to: configURL)

        let migratedConfiguration = try HostStore.loadOrCreateConfiguration(at: configURL)

        #expect(migratedConfiguration.groups.count == 1)
        #expect(migratedConfiguration.groups[0].id == duplicatedID)
        #expect(migratedConfiguration.groups[0].name == "Servers")
        #expect(migratedConfiguration.hosts[0].groupID == duplicatedID)
    }

    /// 验证非法 JSON 不会被误判成其他读写错误。
    @Test
    func loadOrCreateDefaultsReturnsDecodeFailureForInvalidJSON() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        try Data("not valid json".utf8).write(to: configURL)

        do {
            _ = try HostStore.loadOrCreateDefaults(at: configURL)
            Issue.record("Expected decodeFailed error")
        } catch let error as HostStoreError {
            guard case .decodeFailed(let url, _) = error else {
                Issue.record("Expected decodeFailed, got \(error)")
                return
            }

            #expect(url == configURL)
        } catch {
            Issue.record("Expected HostStoreError, got \(error)")
        }
    }

    /// 验证已经完整的新数据不会在迁移逻辑里被意外改写。
    @Test
    func migrateDefaultsIfNeededLeavesCompleteHostUnchanged() {
        let host = RemoteHost(
            name: "Arch",
            username: "elaine",
            address: "100.117.140.113",
            port: 2222,
            remoteDirectory: "/srv/project",
            startupCommand: "exec zsh -l"
        )

        let migratedHosts = HostStore.migrateDefaultsIfNeeded(in: [host])

        #expect(migratedHosts == [host])
    }

    /// 验证“复制完整配置 JSON”导出后仍能被重新解码。
    @Test
    func formattedConfigurationJSONRoundTripsHostsAndGroups() throws {
        let group = HostGroup(name: "Servers")
        let configuration = RemoteDockConfiguration(
            hosts: [
                RemoteHost(
                    name: "Arch",
                    username: "elaine",
                    address: "100.117.140.113",
                    groupID: group.id,
                    remoteDirectory: "/srv/project"
                )
            ],
            groups: [group]
        )

        let json = try configuration.formattedJSON()
        let decoded = try JSONDecoder().decode(RemoteDockConfiguration.self, from: Data(json.utf8))

        #expect(json.contains(#""groups""#))
        #expect(json.contains(#""hosts""#))
        #expect(decoded == configuration)
    }

    /// 验证仓库中的现代示例配置可以被当前文档模型直接读取。
    @Test
    func currentExampleConfigurationDecodesSuccessfully() throws {
        let data = try Data(contentsOf: exampleFileURL(named: "current-config.json"))

        let configuration = try JSONDecoder().decode(RemoteDockConfiguration.self, from: data)

        #expect(configuration.groups.count == 2)
        #expect(configuration.hosts.count == 2)
        #expect(configuration.groups[0].name == "Lab")
        #expect(configuration.groups[1].name == "Windows")
        #expect(configuration.hosts[0].groupID == configuration.groups[0].id)
        #expect(configuration.hosts[0].preferredOpenMode == .ghostty)
        #expect(configuration.hosts[1].groupID == configuration.groups[1].id)
        #expect(configuration.hosts[1].preferredOpenMode == .vscode)
        #expect(configuration.hosts[1].preferredAutoPingDisabledOrNil)
    }

    /// 验证仓库中的旧格式示例配置会在加载时自动迁移到新文档结构。
    @Test
    func legacyExampleConfigurationMigratesSuccessfully() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let legacyData = try Data(contentsOf: exampleFileURL(named: "legacy-hosts-array.json"))
        try legacyData.write(to: configURL)

        let configuration = try HostStore.loadOrCreateConfiguration(at: configURL)
        let persistedData = try Data(contentsOf: configURL)
        let persistedConfiguration = try JSONDecoder().decode(RemoteDockConfiguration.self, from: persistedData)

        #expect(configuration.groups.isEmpty)
        #expect(configuration.hosts.count == 2)
        #expect(configuration.hosts[0].preferredRemoteDirectory == "/home/elaine")
        #expect(configuration.hosts[0].preferredStartupCommand == nil)
        #expect(configuration.hosts[1].preferredRemoteDirectory == "C:/Users/elaine")
        #expect(configuration.hosts[1].preferredStartupCommand == #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#)
        #expect(persistedConfiguration == configuration)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func exampleFileURL(named name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Examples", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    private func removeItemIfExists(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
