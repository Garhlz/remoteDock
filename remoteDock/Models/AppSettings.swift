import Foundation
import RemoteDockCore

enum AppSettings {
    enum OpenShortcut: String, CaseIterable, Identifiable {
        case commandShiftO
        case commandOptionO
        case commandControlO
        case none

        var id: String { rawValue }

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

    enum PingShortcut: String, CaseIterable, Identifiable {
        case commandShiftP
        case commandOptionP
        case commandControlP
        case none

        var id: String { rawValue }

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

    enum AutoPingMode: String, CaseIterable, Identifiable {
        case seconds
        case minutes
        case manual

        var id: String { rawValue }

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

    static let defaultOpenModeKey = "settings.defaultOpenMode"
    static let openShortcutKey = "settings.openShortcut"
    static let pingShortcutKey = "settings.pingShortcut"
    static let defaultAutoPingModeKey = "settings.defaultAutoPingMode"
    static let defaultAutoPingIntervalValueKey = "settings.defaultAutoPingIntervalValue"
    static let runInitialPingOnLaunchKey = "settings.runInitialPingOnLaunch"
    static let showMenuBarIconKey = "settings.showMenuBarIcon"
    static let sidebarControlsExpandedKey = "settings.sidebarControlsExpanded"

    static let defaultOpenMode = PreferredOpenMode.ghostty
    static let defaultOpenShortcut = OpenShortcut.commandShiftO
    static let defaultPingShortcut = PingShortcut.commandShiftP
    static let defaultAutoPingMode = AutoPingMode.minutes
    static let defaultAutoPingIntervalValue = RemoteHost.defaultAutoPingIntervalMinutes
    static let defaultRunInitialPingOnLaunch = true
    static let defaultShowMenuBarIcon = true

    static func normalizedAutoPingIntervalValue(_ value: Int) -> Int {
        min(max(value, 1), 3600)
    }

    static func effectiveAutoPingMode(rawValue: String) -> AutoPingMode {
        AutoPingMode(rawValue: rawValue) ?? defaultAutoPingMode
    }

    static func effectiveOpenShortcut(rawValue: String) -> OpenShortcut {
        OpenShortcut(rawValue: rawValue) ?? defaultOpenShortcut
    }

    static func effectivePingShortcut(rawValue: String) -> PingShortcut {
        PingShortcut(rawValue: rawValue) ?? defaultPingShortcut
    }

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
