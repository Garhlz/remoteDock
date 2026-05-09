import Foundation

public enum PreferredOpenMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case ghostty
    case defaultTerminal
    case vscode

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ghostty:
            "Ghostty"
        case .defaultTerminal:
            "Default Terminal"
        case .vscode:
            "VS Code"
        }
    }

    public var actionTitle: String {
        switch self {
        case .ghostty:
            "Open in Ghostty"
        case .defaultTerminal:
            "Open in Default Terminal"
        case .vscode:
            "Open in VS Code"
        }
    }

    public var systemImage: String {
        switch self {
        case .ghostty:
            "terminal"
        case .defaultTerminal:
            "rectangle.on.rectangle"
        case .vscode:
            "chevron.left.forwardslash.chevron.right"
        }
    }
}
