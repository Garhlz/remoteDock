import Foundation

public struct HostGroup: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = Self.normalizedName(name)
    }

    public func withName(_ name: String) -> HostGroup {
        HostGroup(id: id, name: name)
    }

    private static func normalizedName(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? "Untitled Group" : trimmedValue
    }
}
