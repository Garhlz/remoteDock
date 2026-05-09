//
//  remoteDockApp.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI

@main
struct remoteDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowSceneView()
        }
        .commands {
            RemoteDockCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MainWindowSceneView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView()
            .task {
                AppBridge.shared.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}
