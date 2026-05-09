import Foundation
import RemoteDockCore

/// App 内部使用的设置键、默认值和设置值解析逻辑。
enum AppSettings {
    /// “打开主机”菜单动作支持的快捷键选项。
    enum OpenShortcut: String, CaseIterable, Identifiable {
        case commandShiftO
        case commandOptionO
        case commandControlO
        case none

        var id: String { rawValue }

        /// 用于设置界面展示的人类可读名称。
        /// 这里没有直接把组合键写死在视图里，而是统一由枚举负责描述。
        var title: String {
            switch self {
            case .commandShiftO:
                "Shift + Command + O"
            case .commandOptionO:
                "Option + Command + O"
            case .commandControlO:
                "Control + Command + O"
            case .none:
                "Disabled"
            }
        }
    }

    /// “Ping 主机”菜单动作支持的快捷键选项。
    enum PingShortcut: String, CaseIterable, Identifiable {
        case commandShiftP
        case commandOptionP
        case commandControlP
        case none

        var id: String { rawValue }

        /// 与 `OpenShortcut.title` 相同，用于把内部枚举值翻译成设置页友好的文案。
        var title: String {
            switch self {
            case .commandShiftP:
                "Shift + Command + P"
            case .commandOptionP:
                "Option + Command + P"
            case .commandControlP:
                "Control + Command + P"
            case .none:
                "Disabled"
            }
        }
    }

    /// 自动 Ping 的全局策略。
    ///
    /// - `seconds` / `minutes`：表示轮询式自动检测；
    /// - `manual`：只允许手动触发，不参与后台自动检查。
    enum AutoPingMode: String, CaseIterable, Identifiable {
        case seconds
        case minutes
        case manual

        var id: String { rawValue }

        /// 设置页和详情页里看到的模式名称都来自这里，避免视图层重复维护文案。
        var title: String {
            switch self {
            case .seconds:
                "Seconds"
            case .minutes:
                "Minutes"
            case .manual:
                "Manual Only"
            }
        }
    }

    /// 下面这些 key 都是 `UserDefaults` 中的稳定键名。
    /// SwiftUI 的 `@AppStorage` 会用它们来做读写绑定。
    static let defaultOpenModeKey = "settings.defaultOpenMode"
    static let openShortcutKey = "settings.openShortcut"
    static let pingShortcutKey = "settings.pingShortcut"
    static let defaultAutoPingModeKey = "settings.defaultAutoPingMode"
    static let defaultAutoPingIntervalValueKey = "settings.defaultAutoPingIntervalValue"
    static let runInitialPingOnLaunchKey = "settings.runInitialPingOnLaunch"
    static let showMenuBarIconKey = "settings.showMenuBarIcon"
    static let sidebarControlsExpandedKey = "settings.sidebarControlsExpanded"

    /// 下面这组常量描述“应用刚安装、或设置损坏回退时”的默认行为。
    static let defaultOpenMode = PreferredOpenMode.ghostty
    static let defaultOpenShortcut = OpenShortcut.commandShiftO
    static let defaultPingShortcut = PingShortcut.commandShiftP
    static let defaultAutoPingMode = AutoPingMode.minutes
    static let defaultAutoPingIntervalValue = RemoteHost.defaultAutoPingIntervalMinutes
    static let defaultRunInitialPingOnLaunch = true
    static let defaultShowMenuBarIcon = true

    /// 对用户输入的轮询间隔做兜底，避免出现 0、负数或过大的极端值。
    static func normalizedAutoPingIntervalValue(_ value: Int) -> Int {
        min(max(value, 1), 3600)
    }

    /// 把持久化的字符串恢复成枚举；如果遇到旧值或非法值，则回退到默认值。
    ///
    /// 这里选择“容错回退”而不是抛错，原因是设置属于辅助数据：
    /// 即使用户本地残留了历史值，应用也应该优先继续可用，而不是因为偏好项损坏影响主流程。
    static func effectiveAutoPingMode(rawValue: String) -> AutoPingMode {
        AutoPingMode(rawValue: rawValue) ?? defaultAutoPingMode
    }

    /// 与 `effectiveAutoPingMode` 同理，用于把“打开当前主机”的快捷键设置安全恢复成枚举值。
    ///
    /// 这类恢复函数把“UserDefaults 里的不可信字符串”隔离在这一层，
    /// 这样视图和 Commands 层就可以直接依赖稳定枚举，不必到处写兜底逻辑。
    static func effectiveOpenShortcut(rawValue: String) -> OpenShortcut {
        OpenShortcut(rawValue: rawValue) ?? defaultOpenShortcut
    }

    /// 与 `effectiveOpenShortcut` 对称，用于恢复 Ping 快捷键设置。
    static func effectivePingShortcut(rawValue: String) -> PingShortcut {
        PingShortcut(rawValue: rawValue) ?? defaultPingShortcut
    }

    /// 生成界面上展示用的人类可读文本，避免视图层重复写格式化逻辑。
    ///
    /// 之所以把展示文案也收口到这里，是因为“全局默认策略”和“详情页生效描述”
    /// 其实表达的是同一套业务语义，放在一处更不容易出现 UI 文案分叉。
    static func heartbeatDescription(mode: AutoPingMode, value: Int) -> String {
        switch mode {
        case .seconds:
            let normalizedValue = normalizedAutoPingIntervalValue(value)
            return "\(normalizedValue) sec"
        case .minutes:
            let normalizedValue = normalizedAutoPingIntervalValue(value)
            return "\(normalizedValue) min"
        case .manual:
            return "Manual only"
        }
    }
}
