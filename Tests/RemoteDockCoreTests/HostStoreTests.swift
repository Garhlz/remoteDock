import Foundation
import Testing
@testable import RemoteDockCore

struct HostStoreTests {
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

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeItemIfExists(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
