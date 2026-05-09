import SwiftUI

/// 为当前选中主机提供全局菜单命令和快捷键入口。
///
/// 这层的关键点在于：它自己并不知道“当前选中了哪台主机”，
/// 而是通过 `@FocusedValue` 从当前活跃窗口读取动作闭包。
/// 这些闭包由 `ContentView` 在 `focusedSceneValue(...)` 中写入。
///
/// 可以把这条链路理解成：
/// `ContentView` 暴露动作 -> 当前场景获得焦点 -> 菜单命令读取动作 -> 用户点菜单或按快捷键时执行。
struct RemoteDockCommands: Commands {
    /// 快捷键配置和当前聚焦的动作一起决定了菜单项是否可用、是否带快捷键。
    @AppStorage(AppSettings.openShortcutKey) private var openShortcutRawValue = AppSettings.defaultOpenShortcut.rawValue
    @AppStorage(AppSettings.pingShortcutKey) private var pingShortcutRawValue = AppSettings.defaultPingShortcut.rawValue
    @FocusedValue(\.openSelectedHost) private var openSelectedHost
    @FocusedValue(\.pingSelectedHost) private var pingSelectedHost
    @FocusedValue(\.selectedHostName) private var selectedHostName

    var body: some Commands {
        /// `CommandMenu` 会把这里的内容挂到 macOS 顶部菜单栏中。
        CommandMenu("RemoteDock") {
            openButton
            pingButton
        }
    }

    /// 根据当前选中的主机名称动态生成菜单标题，让全局菜单更像“当前上下文动作”。
    private var openTitle: String {
        if let selectedHostName {
            return "Open \(selectedHostName)"
        }

        return "Open Selected Host"
    }

    private var pingTitle: String {
        /// 与 `openTitle` 对称，让菜单标题始终尽量带上当前上下文中的主机名。
        if let selectedHostName {
            return "Ping \(selectedHostName)"
        }

        return "Ping Selected Host"
    }

    @ViewBuilder
    private var openButton: some View {
        /// 从持久化设置里解析快捷键配置，再映射成 SwiftUI 的 `keyboardShortcut`。
        let shortcut = AppSettings.effectiveOpenShortcut(rawValue: openShortcutRawValue)

        switch shortcut {
        case .commandShiftO:
            Button(openTitle) { openSelectedHost?() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(openSelectedHost == nil)
        case .commandOptionO:
            Button(openTitle) { openSelectedHost?() }
                .keyboardShortcut("o", modifiers: [.command, .option])
                .disabled(openSelectedHost == nil)
        case .commandControlO:
            Button(openTitle) { openSelectedHost?() }
                .keyboardShortcut("o", modifiers: [.command, .control])
                .disabled(openSelectedHost == nil)
        case .none:
            Button(openTitle) { openSelectedHost?() }
                .disabled(openSelectedHost == nil)
        }
    }

    @ViewBuilder
    private var pingButton: some View {
        /// Ping 菜单与 Open 菜单采用同一套模式：先解析设置，再决定是否绑定快捷键。
        let shortcut = AppSettings.effectivePingShortcut(rawValue: pingShortcutRawValue)

        switch shortcut {
        case .commandShiftP:
            Button(pingTitle) { pingSelectedHost?() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(pingSelectedHost == nil)
        case .commandOptionP:
            Button(pingTitle) { pingSelectedHost?() }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(pingSelectedHost == nil)
        case .commandControlP:
            Button(pingTitle) { pingSelectedHost?() }
                .keyboardShortcut("p", modifiers: [.command, .control])
                .disabled(pingSelectedHost == nil)
        case .none:
            Button(pingTitle) { pingSelectedHost?() }
                .disabled(pingSelectedHost == nil)
        }
    }
}
