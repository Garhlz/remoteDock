import SwiftUI
import RemoteDockCore

/// 全局设置面板，集中管理默认打开方式、心跳策略和菜单栏选项。
///
/// 这里的每个字段几乎都直接绑定 `@AppStorage`，
/// 所以它既是“设置界面”，也是“UserDefaults 的可视化编辑器”。
/// 用户在这里改值后，主窗口和菜单命令会自动读到新值。
struct SettingsView: View {
    /// 设置页里的所有值都直接绑定到 `@AppStorage`，
    /// 因此这里几乎不需要额外的“保存”按钮或提交逻辑。
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue
    @AppStorage(AppSettings.openShortcutKey) private var openShortcutRawValue = AppSettings.defaultOpenShortcut.rawValue
    @AppStorage(AppSettings.pingShortcutKey) private var pingShortcutRawValue = AppSettings.defaultPingShortcut.rawValue
    @AppStorage(AppSettings.defaultAutoPingModeKey) private var defaultAutoPingModeRawValue = AppSettings.defaultAutoPingMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingIntervalValueKey) private var defaultAutoPingIntervalValue = AppSettings.defaultAutoPingIntervalValue
    @AppStorage(AppSettings.runInitialPingOnLaunchKey) private var runInitialPingOnLaunch = AppSettings.defaultRunInitialPingOnLaunch
    @AppStorage(AppSettings.showMenuBarIconKey) private var showMenuBarIcon = AppSettings.defaultShowMenuBarIcon
    @AppStorage(AppSettings.sidebarControlsExpandedKey) private var sidebarControlsExpanded = false

    var body: some View {
        /// `Form` 是 macOS/iOS 中常见的设置页容器，会自动提供表单式排版和分组视觉。
        Form {
            Section("Connection Defaults") {
                /// 全局默认打开方式会影响所有“没有主机级覆盖值”的主机。
                Picker("Default Open Mode", selection: $defaultOpenModeRawValue) {
                    ForEach(PreferredOpenMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)

                /// 这里定义的是“默认后台策略”，不是强制覆盖每台主机。
                Picker("Background Heartbeat", selection: $defaultAutoPingModeRawValue) {
                    ForEach(AppSettings.AutoPingMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)

                /// 只有自动模式不是 manual 时，才显示间隔设置。
                /// 这样界面上不会出现“显示了输入框但其实不会生效”的误导。
                if resolvedAutoPingMode != .manual {
                    Stepper(value: $defaultAutoPingIntervalValue, in: stepperRange) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Heartbeat Interval")
                            Text(AppSettings.heartbeatDescription(mode: resolvedAutoPingMode, value: defaultAutoPingIntervalValue))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle("Ping all hosts on launch", isOn: $runInitialPingOnLaunch)
            }

            Section("Keyboard Shortcuts") {
                /// 快捷键设置最终会被 `RemoteDockCommands` 读取并映射到菜单命令上。
                Picker("Open Selected Host", selection: $openShortcutRawValue) {
                    ForEach(AppSettings.OpenShortcut.allCases) { shortcut in
                        Text(shortcut.title).tag(shortcut.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker("Ping Selected Host", selection: $pingShortcutRawValue) {
                    ForEach(AppSettings.PingShortcut.allCases) { shortcut in
                        Text(shortcut.title).tag(shortcut.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Sidebar") {
                Toggle("Expand search and filter by default", isOn: $sidebarControlsExpanded)
            }

            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            }

            Section("Notes") {
                /// 这组说明文本用于把几个设置之间的覆盖关系讲清楚。
                settingsNote("Hosts can still override the default open mode individually.")
                settingsNote("Leaving a host's auto ping interval empty uses the global heartbeat policy here.")
                settingsNote("Manual Only disables background heartbeat unless a host has its own explicit interval override.")
                settingsNote("Shortcut changes apply to the app menu commands immediately.")
                settingsNote("The menu bar icon provides quick host actions without opening the main window.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }

    /// 用统一样式渲染设置页底部的说明文本，避免重复写字号和颜色。
    private func settingsNote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// 把持久化字符串解析成可用枚举，供 UI 条件判断复用。
    private var resolvedAutoPingMode: AppSettings.AutoPingMode {
        AppSettings.effectiveAutoPingMode(rawValue: defaultAutoPingModeRawValue)
    }

    /// `Stepper` 的可选范围会随着单位变化：
    /// 秒模式给较小范围，分钟模式给更大范围，manual 则退化成无意义的占位范围。
    private var stepperRange: ClosedRange<Int> {
        switch resolvedAutoPingMode {
        case .seconds:
            5 ... 300
        case .minutes:
            1 ... 1440
        case .manual:
            1 ... 1
        }
    }
}
