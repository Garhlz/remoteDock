import Foundation
import Testing
@testable import RemoteDockCore

struct HostStoreTests {
    @Test
    func loadOrCreateDefaultsWritesDefaultHostsWhenFileDoesNotExist() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")

        let hosts = try HostStore.loadOrCreateDefaults(at: configURL)

        #expect(hosts == HostStore.defaultHosts)
        #expect(FileManager.default.fileExists(atPath: configURL.path))

        let savedData = try Data(contentsOf: configURL)
        let savedHosts = try JSONDecoder().decode([RemoteHost].self, from: savedData)
        #expect(savedHosts == HostStore.defaultHosts)
    }

    @Test
    func saveAndReloadRoundTripsHosts() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { removeItemIfExists(at: tempDirectory) }

        let configURL = tempDirectory.appendingPathComponent("hosts.json")
        let hosts = [
            RemoteHost(
                name: "Arch",
                username: "elaine",
                address: "100.117.140.113",
                port: 2222,
                remoteDirectory: "/srv/project",
                startupCommand: "exec zsh -l",
                preferredOpenMode: .vscode
            )
        ]

        try HostStore.save(hosts, to: configURL)
        let loadedHosts = try HostStore.loadOrCreateDefaults(at: configURL)

        #expect(loadedHosts == hosts)
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
        let persistedHosts = try JSONDecoder().decode([RemoteHost].self, from: persistedData)
        #expect(persistedHosts[0].preferredRemoteDirectory == "/home/elaine")
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

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeItemIfExists(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
