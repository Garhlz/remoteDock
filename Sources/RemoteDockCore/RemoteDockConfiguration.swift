import Foundation

/// 完整配置文档模型，包含主机列表和分组列表。
///
/// 这是 `hosts.json` 在内存中的顶层表示。
/// 相比旧版本只保存 `[RemoteHost]`，
/// 现在它还能同时表达分组信息，因此更适合作为持久化文档格式。
public struct RemoteDockConfiguration: Codable, Sendable, Equatable {
    public let hosts: [RemoteHost]
    public let groups: [HostGroup]

    /// 默认允许不传 groups，兼容那些只关心 host 列表的调用场景。
    public init(hosts: [RemoteHost], groups: [HostGroup] = []) {
        self.hosts = hosts
        self.groups = groups
    }

    /// 以格式化 JSON 文本导出整个配置文档。
    public func formattedJSON() throws -> String {
        try JSONExportFormatter.formattedString(from: self)
    }
}
