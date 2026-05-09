import SwiftUI
import RemoteDockCore

struct SettingsView: View {
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue
    @AppStorage(AppSettings.openShortcutKey) private var openShortcutRawValue = AppSettings.defaultOpenShortcut.rawValue
    @AppStorage(AppSettings.pingShortcutKey) private var pingShortcutRawValue = AppSettings.defaultPingShortcut.rawValue
    @AppStorage(AppSettings.defaultAutoPingModeKey) private var defaultAutoPingModeRawValue = AppSettings.defaultAutoPingMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingIntervalValueKey) private var defaultAutoPingIntervalValue = AppSettings.defaultAutoPingIntervalValue
    @AppStorage(AppSettings.runInitialPingOnLaunchKey) private var runInitialPingOnLaunch = AppSettings.defaultRunInitialPingOnLaunch
    @AppStorage(AppSettings.showMenuBarIconKey) private var showMenuBarIcon = AppSettings.defaultShowMenuBarIcon
    @AppStorage(AppSettings.sidebarControlsExpandedKey) private var sidebarControlsExpanded = false

    var body: some View {
        Form {
            Section("Connection Defaults") {
                Picker("Default Open Mode", selection: $defaultOpenModeRawValue) {
                    ForEach(PreferredOpenMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker("Background Heartbeat", selection: $defaultAutoPingModeRawValue) {
                    ForEach(AppSettings.AutoPingMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)

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

    private func settingsNote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var resolvedAutoPingMode: AppSettings.AutoPingMode {
        AppSettings.effectiveAutoPingMode(rawValue: defaultAutoPingModeRawValue)
    }

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
