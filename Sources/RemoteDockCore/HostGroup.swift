import Foundation

/// 主机分组模型，用于 sidebar 与菜单栏的分组展示。
public struct HostGroup: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = Self.normalizedName(name)
    }

    /// 返回一个仅名称不同的新分组值，保留原有标识符。
    public func withName(_ name: String) -> HostGroup {
        HostGroup(id: id, name: name)
    }

    private static func normalizedName(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? "Untitled Group" : trimmedValue
    }
}
