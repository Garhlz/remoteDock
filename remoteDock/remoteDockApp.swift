//
//  remoteDockApp.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

@main
struct remoteDockApp: App {
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
