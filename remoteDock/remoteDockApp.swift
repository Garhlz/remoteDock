//
//  remoteDockApp.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

@main
/// RemoteDock 的应用入口，负责把整个应用声明成几个独立的 Scene。
///
/// 对不熟悉 SwiftUI 的读者来说，可以把 `App` 理解成桌面应用的总装配器：
/// 1. `WindowGroup` 定义主窗口；
/// 2. `Settings` 定义系统菜单里的设置页；
/// 3. `MenuBarExtra` 定义菜单栏图标展开后的内容。
///
/// SwiftUI 会根据这里声明的内容自动创建窗口和菜单，而不是像传统 GUI 那样手动 new 窗口。
struct remoteDockApp: App {
    /// `@AppStorage` 会把值直接绑定到 `UserDefaults`。
    ///
    /// 这意味着设置页里改动 `showMenuBarIcon` 后，这里会自动收到最新值，
    /// 不需要额外写“读取配置 -> 通知 UI 刷新”的胶水代码。
    @AppStorage(AppSettings.showMenuBarIconKey) private var showMenuBarIcon = AppSettings.defaultShowMenuBarIcon

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        .commands {
            RemoteDockCommands()
        }

        Settings {
            SettingsView()
        }

        /// 菜单栏入口始终存在，但内容会根据设置决定展示主机列表还是提示文案。
        MenuBarExtra("RemoteDock", systemImage: "server.rack") {
            if showMenuBarIcon {
                MenuBarHostsView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Menu bar actions are disabled in Settings.")
                        .foregroundStyle(.secondary)

                    Button("Open Settings") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                .padding(12)
                .frame(width: 240)
            }
        }
    }
}
