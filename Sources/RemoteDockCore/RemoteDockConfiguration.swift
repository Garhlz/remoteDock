import Foundation

public struct RemoteDockConfiguration: Codable, Sendable, Equatable {
    public let hosts: [RemoteHost]
    public let groups: [HostGroup]

    public init(hosts: [RemoteHost], groups: [HostGroup] = []) {
        self.hosts = hosts
        self.groups = groups
    }
}
