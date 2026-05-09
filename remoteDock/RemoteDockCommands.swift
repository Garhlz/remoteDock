import SwiftUI

struct RemoteDockCommands: Commands {
    @AppStorage(AppSettings.openShortcutKey) private var openShortcutRawValue = AppSettings.defaultOpenShortcut.rawValue
    @AppStorage(AppSettings.pingShortcutKey) private var pingShortcutRawValue = AppSettings.defaultPingShortcut.rawValue
    @FocusedValue(\.openSelectedHost) private var openSelectedHost
    @FocusedValue(\.pingSelectedHost) private var pingSelectedHost
    @FocusedValue(\.selectedHostName) private var selectedHostName

    var body: some Commands {
        CommandMenu("RemoteDock") {
            openButton
            pingButton
        }
    }

    private var openTitle: String {
        if let selectedHostName {
            return "Open \(selectedHostName)"
        }

        return "Open Selected Host"
    }

    private var pingTitle: String {
        if let selectedHostName {
            return "Ping \(selectedHostName)"
        }

        return "Ping Selected Host"
    }

    @ViewBuilder
    private var openButton: some View {
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
