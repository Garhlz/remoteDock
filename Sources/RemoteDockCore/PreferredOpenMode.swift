import Foundation

/// 主机的首选打开方式。
///
/// 这是一个纯“策略枚举”：
/// 它不负责真的去打开终端或 VS Code，
/// 只负责在模型和 UI 层表达“用户想用哪一种入口打开主机”。
public enum PreferredOpenMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case ghostty
    case defaultTerminal
    case vscode

    public var id: String { rawValue }

    /// 用于设置页、详情页等位置展示的人类可读标题。
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

    /// 用于按钮标题的动词短语版本。
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

    /// 对应的 SF Symbols 图标，供 SwiftUI 视图统一使用。
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
